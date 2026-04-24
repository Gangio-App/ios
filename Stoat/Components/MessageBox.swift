//
//  MessageBox.swift
//  Revolt
//
//  Created by Zomatree on 21/04/2023.
//

import Foundation
import SwiftUI
import PhotosUI
import Types

struct Reply: Identifiable, Equatable {
    var message: Message
    var mention: Bool = false
    
    var id: String { message.id }
}

struct ReplyView: View {
    @EnvironmentObject var viewState: ViewState
    
    @Binding var reply: Reply
    
    @Binding var replies: [Reply]
    
    var channel: Channel
    var server: Server?

    func remove() {
        withAnimation {
            replies.removeAll(where: { $0.id == reply.id })
        }
    }
    
    var body: some View {
        let user = viewState.users[reply.message.author]!
        let member = server.flatMap { viewState.members[$0.id]?[user.id] }

        HStack(alignment: .center, spacing: 8) {
            Button(action: remove) {
                Image(systemName: "xmark")
                    .resizable()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(viewState.theme.foreground3)
                    .bold()
            }
            
            Avatar(user: user, width: 16, height: 16)
            
            Text(reply.message.masquerade?.name ?? member?.nickname ?? user.display_name ?? user.username)
                .font(.caption)
                .fixedSize()
                .foregroundStyle(member?.displayColour(theme: viewState.theme, server: server!) ?? AnyShapeStyle(viewState.theme.foreground.color))
            
            if !(reply.message.attachments?.isEmpty ?? true) {
                Text(Image(systemName: "doc.text.fill"))
                    .font(.caption)
                    .foregroundStyle(viewState.theme.foreground2)
            }
            
            if let content = Binding($reply.message.content) {
                Contents(text: content, fontSize: 12)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()
            
            Button(action: { reply.mention.toggle() }) {
                if reply.mention {
                    Text("@ on")
                        .foregroundColor(.accentColor)
                } else {
                    Text("@ off")
                }
            }
        }
    }
}

struct MessageBox: View {
    enum AutocompleteType {
        case usersAndRoles
        case channel
        case emoji
    }
    
    enum UserOrRole: Identifiable {
        case user(UserMaybeMember)
        case role(String, Role)
        case everyone
        case online
        
        var id: String {
            switch self {
                case .user(let userMaybeMember):
                    return userMaybeMember.id
                case .role(let id, _):
                    return id
                case .everyone:
                    return "everyone"
                case .online:
                    return "online"
            }
        }
    }

    enum AutocompleteValues {
        case channels([Channel])
        case usersAndRoles([UserOrRole])
        case emojis([PickerEmoji])
        
        var isEmpty: Bool {
            switch self {
                case .channels(let array):
                    array.isEmpty
                case .usersAndRoles(let array):
                    array.isEmpty
                case .emojis(let array):
                    array.isEmpty
            }
        }
    }

    struct Photo: Identifiable, Hashable {
        let data: Data
#if os(macOS)
        let image: NSImage?
#else
        let image: UIImage?
#endif
        let id: UUID
        let filename: String
    }

    @EnvironmentObject var viewState: ViewState

    @Binding var channelReplies: [Reply]
    var focusState: FocusState<Bool>.Binding
    @Binding var showingSelectEmoji: Bool
    @Binding var editing: Message?

    @State var showingSelectFile = false
    @State var showingSelectPhoto = false

    @State var reshowKeyboard = false

    @State var content = ""

    @State var selectedPhotos: [Photo] = []
    @State var selectedPhotoItems: [PhotosPickerItem] = []
    @State var selectedEmoji: String = ""

    @State var autoCompleteType: AutocompleteType? = nil
    @State var autocompleteSearchValue: String = ""
    
    @State var currentPermissions: Permissions = .default

    let channel: Channel
    let server: Server?

    init(channel: Channel, server: Server?, channelReplies: Binding<[Reply]>, focusState f: FocusState<Bool>.Binding, showingSelectEmoji: Binding<Bool>, editing: Binding<Message?>) {
        self.channel = channel
        self.server = server
        _channelReplies = channelReplies
        focusState = f
        _showingSelectEmoji = showingSelectEmoji
        _editing = editing
        
        if let msg = editing.wrappedValue {
            content = msg.content ?? ""
        }
    }

    func sendMessage() {
        let c = content
        content = ""
        let replies = channelReplies
        channelReplies = []

        if let message = editing {
            Task {
                editing = nil

                await viewState.http.editMessage(channel: channel.id, message: message.id, edits: MessageEdit(content: c))
            }
            
        } else {
            let f = selectedPhotos.map({ ($0.data, $0.filename) })
            selectedPhotos = []
            
            Task {
                await viewState.queueMessage(channel: channel.id, replies: replies, content: c, attachments: f)
            }
        }
    }

    func getAutocompleteValues(fromType type: AutocompleteType) -> AutocompleteValues {
        switch type {
            case .usersAndRoles:
                var usersAndRoles: [UserOrRole]

                switch channel {
                    case .saved_messages(_):
                        usersAndRoles = [.user(UserMaybeMember(user: viewState.currentUser!, member: nil))]

                    case .dm_channel(let dMChannel):
                        usersAndRoles = dMChannel.recipients.map { .user(UserMaybeMember(user: viewState.users[$0]!, member: nil)) }

                    case .group_dm_channel(let groupDMChannel):
                        usersAndRoles = groupDMChannel.recipients.map { .user(UserMaybeMember(user: viewState.users[$0]!, member: nil)) }

                    case .text_channel(_), .voice_channel(_):
                        usersAndRoles = viewState.members[server!.id]!.values.compactMap { m in
                            viewState.users[m.id.user].map { .user(UserMaybeMember(user: $0, member: m)) }
                        }
                        
                        if currentPermissions.contains(.mentionRoles) {
                            if let roles = server?.roles {
                                usersAndRoles.append(contentsOf: roles.map { (key, value) in .role(key, value) })
                            }
                        }
                        
                        if currentPermissions.contains(.mentionEveryone) {
                            usersAndRoles.append(contentsOf: [.everyone, .online])
                        }
                }

                return AutocompleteValues.usersAndRoles(usersAndRoles.filter({ value in
                    let lowered = autocompleteSearchValue.lowercased()
                    switch value {
                        case .user(let user):
                            return user.user.display_name?.lowercased().starts(with: lowered)
                                ?? user.member?.nickname?.lowercased().starts(with: lowered)
                                ?? user.user.username.lowercased().starts(with: lowered)
                        case .role(_, let role):
                            return role.name.lowercased().starts(with: lowered)
                        case .everyone:
                            return "everyone".starts(with: lowered)
                        case .online:
                            return "online".starts(with: lowered)
                    }
                }))
            case .channel:
                let channels: [Channel]

                switch channel {
                    case .saved_messages(_), .dm_channel(_), .group_dm_channel(_):
                        channels = [channel]
                    case .text_channel(_), .voice_channel(_):
                        channels = server!.channels.compactMap({ viewState.channels[$0] })
                }

                return AutocompleteValues.channels(channels.filter { channel in
                    channel.getName(viewState).lowercased().starts(with: autocompleteSearchValue.lowercased())
                })
            case .emoji:
                return AutocompleteValues.emojis(loadEmojis(withState: viewState)
                    .values
                    .flatMap { $0 }
                    .filter { emoji in
                        let names: [String]
                        
                        if let emojiId = emoji.emojiId, let emoji = viewState.emojis[emojiId] {
                            names = [emoji.name]
                        } else {
                            var values = emoji.alternates
                            values.append(emoji.base)
                            names = values.map { String(String.UnicodeScalarView($0.compactMap(Unicode.Scalar.init))) }
                        }
                        
                        return names.contains(where: { $0.lowercased().starts(with: autocompleteSearchValue.lowercased()) })
                    })
        }
    }

    var body: some View {
        let isDark = !Theme.isLightOrDark(viewState.theme.background)

        VStack(alignment: .leading, spacing: 0) {

            // ── Reply banners ─────────────────────────────────────────────
            if !channelReplies.isEmpty {
                VStack(spacing: 0) {
                    ForEach($channelReplies) { reply in
                        ReplyView(reply: reply, replies: $channelReplies, channel: channel, server: server)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                    }
                }
                .background(isDark ? Color(white: 0.13) : Color(white: 0.93))
                .animation(.default, value: channelReplies)
            }

            // ── Edit banner ───────────────────────────────────────────────
            if editing != nil {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .foregroundStyle(viewState.theme.accent.color)
                    Text("Editing message")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(viewState.theme.foreground2.color)
                    Spacer()
                    Button { editing = nil; content = "" } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(isDark ? Color(white: 0.12) : Color(white: 0.94))
            }

            // ── Photo preview strip ───────────────────────────────────────
            if selectedPhotos.count > 0 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach($selectedPhotos, id: \.self) { file in
                            let file = file.wrappedValue
                            ZStack(alignment: .topTrailing) {
                                if let image = file.image {
#if os(iOS)
                                    Image(uiImage: image)
                                        .resizable().scaledToFill()
                                        .frame(width: 72, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
#endif
                                }
                                Button { selectedPhotos.removeAll(where: { $0.id == file.id }) } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white)
                                        .background(Circle().fill(.black.opacity(0.5)))
                                        .frame(width: 18, height: 18)
                                }
                                .offset(x: 4, y: -4)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(isDark ? Color(white: 0.11) : Color(white: 0.95))
            }

            // ── Autocomplete strip ────────────────────────────────────────
            if let type = autoCompleteType {
                let values = getAutocompleteValues(fromType: type)
                if !values.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 6) {
                            switch values {
                            case .usersAndRoles(let usersOrRoles):
                                ForEach(usersOrRoles) { userOrRole in
                                    Button {
                                        let value: String
                                        switch userOrRole {
                                        case .user(let user): value = "<@\(user.id)>"
                                        case .role(let id, _): value = "<%\(id)>"
                                        case .everyone: value = "@everyone"
                                        case .online: value = "@online"
                                        }
                                        withAnimation {
                                            content = String(content.dropLast(autocompleteSearchValue.count + 1)) + "\(value) "
                                            autoCompleteType = nil
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            switch userOrRole {
                                            case .user(let user):
                                                Avatar(user: user.user, member: user.member, width: 20, height: 20)
                                                Text(user.member?.nickname ?? user.user.display_name ?? user.user.username)
                                            case .role(_, let role):
                                                Text("@\(role.name)").foregroundStyle(role.colour.map { parseCSSColorToShapeStyle(currentTheme: viewState.theme, input: $0) } ?? AnyShapeStyle(viewState.theme.foreground))
                                            case .everyone: Text("@everyone")
                                            case .online: Text("@online")
                                            }
                                        }
                                        .font(.system(size: 13))
                                        .padding(.horizontal, 8).padding(.vertical, 5)
                                    }
                                    .background(viewState.theme.background2.color)
                                    .clipShape(Capsule())
                                }
                            case .channels(let channels):
                                ForEach(channels) { ch in
                                    Button {
                                        withAnimation {
                                            content = String(content.dropLast(autocompleteSearchValue.count + 1)) + "<#\(ch.id)> "
                                            autoCompleteType = nil
                                        }
                                    } label: {
                                        ChannelIcon(channel: ch)
                                            .font(.system(size: 13))
                                            .padding(.horizontal, 8).padding(.vertical, 5)
                                    }
                                    .background(viewState.theme.background2.color)
                                    .clipShape(Capsule())
                                }
                            case .emojis(let emojis):
                                ForEach(emojis) { emoji in
                                    Button {
                                        let str: String
                                        if let emojiId = emoji.emojiId { str = ":\(emojiId): " }
                                        else { str = String(String.UnicodeScalarView(emoji.base.compactMap(Unicode.Scalar.init))) }
                                        withAnimation {
                                            content = String(content.dropLast(autocompleteSearchValue.count + 1)) + str
                                            autoCompleteType = nil
                                        }
                                    } label: {
                                        if let id = emoji.emojiId {
                                            LazyImage(source: .emoji(id), height: 20, width: 20, clipTo: Rectangle())
                                        } else {
                                            Text(String(String.UnicodeScalarView(emoji.base.compactMap(Unicode.Scalar.init)))).font(.system(size: 18))
                                        }
                                    }
                                    .frame(width: 36, height: 36)
                                    .background(viewState.theme.background2.color)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .background(isDark ? Color(white: 0.12) : Color(white: 0.94))
                }
            }

            // ── Discord-style input bar ───────────────────────────────────
            HStack(alignment: .center, spacing: 12) {

                // + Attach button (left)
                UploadButton(
                    showingSelectFile: $showingSelectFile,
                    showingSelectPhoto: $showingSelectPhoto,
                    selectedPhotoItems: $selectedPhotoItems,
                    selectedPhotos: $selectedPhotos
                )
                .frame(width: 36, height: 36)
                .background(isDark ? Color(white: 0.22) : Color(white: 0.88))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

                // Text field pill
                HStack(alignment: .center, spacing: 8) {
                    TextField("", text: $content.animation(), axis: .vertical)
                        .focused(focusState)
                        .placeholder(when: content.isEmpty) {
                            Text("Message #\(channel.getName(viewState))")
                                .foregroundStyle(.secondary.opacity(0.6))
                                .lineLimit(1)
                        }
                        .font(.system(size: 16))
                        .foregroundStyle(isDark ? .white : .black)
                        .lineLimit(1...6)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(Color.clear)
                        .onChange(of: content) { _, value in
                            withAnimation {
                                if let last = value.split(separator: " ").last {
                                    let pre = last.first
                                    autocompleteSearchValue = String(last[last.index(last.startIndex, offsetBy: 1)...])
                                    switch pre {
                                    case "@": autoCompleteType = .usersAndRoles
                                    case "#": autoCompleteType = .channel
                                    case ":": autoCompleteType = .emoji
                                    default: autoCompleteType = nil
                                    }
                                } else { autoCompleteType = nil }
                            }
                        }
                        .onChange(of: focusState.wrappedValue) { _, v in
                            if v, showingSelectEmoji { withAnimation { showingSelectEmoji = false } }
                        }
                        .onChange(of: showingSelectEmoji) { b, a in
                            if b, !a { withAnimation { focusState.wrappedValue = true } }
                        }
                        .onChange(of: editing) { _, a in
                            if let a {
                                selectedPhotos = []; selectedPhotoItems = []; autoCompleteType = nil; autocompleteSearchValue = ""; content = a.content ?? ""
                            } else { channelReplies = []; content = "" }
                        }
                        .sheet(isPresented: $showingSelectEmoji) {
                            EmojiPicker(background: AnyView(viewState.theme.background)) { emoji in
                                if let id = emoji.emojiId { content.append(":\(id):") }
                                else { content.append(String(String.UnicodeScalarView(emoji.base.compactMap(Unicode.Scalar.init)))) }
                                showingSelectEmoji = false
                            }
                            .padding([.top, .horizontal])
                            .background(viewState.theme.background.ignoresSafeArea(.all))
                            .presentationDetents([.large])
                        }

                    // Emoji button (inside pill, right side)
                    Button {
                        withAnimation {
                            focusState.wrappedValue = false
                            showingSelectEmoji.toggle()
                        }
                    } label: {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                }
                .background(isDark ? Color(white: 0.15) : Color(white: 0.91))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)

                // Send button (right, Discord blue circle)
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(content.isEmpty && selectedPhotos.isEmpty ? Color.gray.opacity(0.4) : viewState.theme.accent.color)
                        .clipShape(Circle())
                        .shadow(color: content.isEmpty && selectedPhotos.isEmpty ? .clear : viewState.theme.accent.color.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .disabled(content.isEmpty && selectedPhotos.isEmpty)
                .animation(.easeInOut(duration: 0.2), value: content.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isDark ? Color(white: 0.08) : Color(white: 0.97))
            .background(.ultraThinMaterial, in: Rectangle())
        }
        .onAppear {
            let member = server.flatMap { viewState.members[$0.id]?[viewState.currentUser!.id] }
            currentPermissions = resolveChannelPermissions(from: viewState.currentUser!, targettingUser: viewState.currentUser!, targettingMember: member, channel: channel, server: server)
        }
    }

}

struct UploadButton: View {
    @EnvironmentObject var viewState: ViewState

    @Binding var showingSelectFile: Bool
    @Binding var showingSelectPhoto: Bool
    @Binding var selectedPhotoItems: [PhotosPickerItem]
    @Binding var selectedPhotos: [MessageBox.Photo]

    func onFileCompletion(res: Result<URL, Error>) {
        if case .success(let url) = res, url.startAccessingSecurityScopedResource() {
            let data = try? Data(contentsOf: url)
            url.stopAccessingSecurityScopedResource()
            
            guard let data = data else { return }

#if os(macOS)
            let image = NSImage(data: data)
#else
            let image = UIImage(data: data)
#endif

            selectedPhotos.append(.init(data: data, image: image, id: UUID(), filename: url.lastPathComponent))
        }
    }

    var body: some View {
        Image(systemName: "plus")
            .resizable()
            .foregroundStyle(viewState.theme.foreground3.color)
            .frame(width: 18, height: 18)
            .frame(width: 36, height: 36)

            .photosPicker(isPresented: $showingSelectPhoto, selection: $selectedPhotoItems)
            .photosPickerStyle(.presentation)

            .fileImporter(isPresented: $showingSelectFile, allowedContentTypes: [.item], onCompletion: onFileCompletion)

            .onTapGesture {
                showingSelectPhoto = true
            }
            .contextMenu {
                Button(action: {
                    showingSelectFile = true
                }) {
                    Text("Select File")
                }
                Button(action: {
                    showingSelectPhoto = true
                }) {
                    Text("Select Photo")
                }
            }
            .onChange(of: selectedPhotoItems) { before, after in
                if after.isEmpty { return }
                Task {
                    for item in after {
                        if let data = try? await item.loadTransferable(type: Data.self) {
#if os(macOS)
                            let img = NSImage(data: data)
#else
                            let img = UIImage(data: data)
#endif

                            if let img = img {
                                let fileType = item.supportedContentTypes[0].preferredFilenameExtension!
                                let fileName = (item.itemIdentifier ?? "Image") + ".\(fileType)"
                                selectedPhotos.append(.init(data: data, image: img, id: UUID(), filename: fileName))
                            }
                        }
                    }
                    selectedPhotoItems.removeAll()
                }
            }
    }
}

struct MessageBox_Previews: PreviewProvider {
    static var viewState: ViewState = ViewState.preview().applySystemScheme(theme: .dark)
    @State static var replies: [Reply] = []
    @State static var showingSelectEmoji = false
    @FocusState static var focused: Bool

    static var previews: some View {
        let channel = viewState.channels["0"]!
        let server = viewState.servers["0"]!

        MessageBox(channel: channel, server: server, channelReplies: $replies, focusState: $focused, showingSelectEmoji: $showingSelectEmoji, editing: .constant(nil))
            .applyPreviewModifiers(withState: viewState)
    }
}
