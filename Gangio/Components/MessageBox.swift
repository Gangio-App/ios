//
//  MessageBox.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
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
    @EnvironmentObject var viewState: AppViewState
    
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
            
            AppAvatar(user: user, width: 16, height: 16)
            
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

    @EnvironmentObject var viewState: AppViewState

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
    @State var autocompleteReplacements: [String: String] = [:]
    
    @State private var autocompleteResults: AutocompleteValues = .usersAndRoles([])
    @State private var searchTask: Task<Void, Never>? = nil

    let channel: Channel
    let server: Server?
    
    /// Live channel permissions for the current user. Computed every body
    /// re-evaluation so role/overwrite/timeout changes pushed over the
    /// websocket immediately lock or unlock the composer without waiting
    /// for a navigation cycle. Falls back to `.none` when no current user
    /// (i.e. logged-out preview state).
    private var currentPermissions: Permissions {
        viewState.channelPermissions(for: channel)
    }

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
        // Defensive permission check at the action site. The UI already
        // hides the composer when sendMessages is missing, but a stale view
        // (e.g. permissions revoked mid-keystroke) could otherwise still
        // fire this and trigger a 403 from the server.
        guard currentPermissions.contains(.sendMessages) else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        var c = content
        // Apply autocomplete replacements (e.g. @korybantes -> <@user_id>)
        for (display, replacement) in autocompleteReplacements {
            c = c.replacingOccurrences(of: display, with: replacement)
        }
        
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

    func updateAutocomplete() {
        searchTask?.cancel()
        
        let value = content
        guard let last = value.split(separator: " ", omittingEmptySubsequences: false).last,
              let pre = last.first,
              ["@", "#", ":"].contains(pre) else {
            autoCompleteType = nil
            return
        }
        
        let search = String(last.dropFirst())
        let type: AutocompleteType
        switch pre {
        case "@": type = .usersAndRoles
        case "#": type = .channel
        case ":": type = .emoji
        default: return
        }
        
        autoCompleteType = type
        autocompleteSearchValue = search
        
        searchTask = Task.detached(priority: .userInitiated) {
            let results = await self.computeAutocompleteValues(type: type, search: search)
            await MainActor.run {
                self.autocompleteResults = results
            }
        }
    }

    private func computeAutocompleteValues(type: AutocompleteType, search: String) async -> AutocompleteValues {
        let lowered = search.lowercased()
        
        switch type {
        case .usersAndRoles:
            var usersAndRoles: [UserOrRole] = []
            switch channel {
            case .saved_messages(_):
                usersAndRoles = [.user(UserMaybeMember(user: viewState.currentUser!, member: nil))]
            case .dm_channel(let dMChannel):
                usersAndRoles = dMChannel.recipients.compactMap { id in viewState.users[id].map { .user(UserMaybeMember(user: $0, member: nil)) } }
            case .group_dm_channel(let groupDMChannel):
                usersAndRoles = groupDMChannel.recipients.compactMap { id in viewState.users[id].map { .user(UserMaybeMember(user: $0, member: nil)) } }
            case .text_channel(_), .voice_channel(_):
                if let server = server, let memberDict = viewState.members[server.id] {
                    usersAndRoles = memberDict.values.compactMap { m -> UserOrRole? in
                        viewState.users[m.id.user].map { UserOrRole.user(UserMaybeMember(user: $0, member: m)) }
                    }
                    
                    if currentPermissions.contains(.mentionRoles), let roles = server.roles {
                        let roleItems = roles.map { (key: String, value: Role) in UserOrRole.role(key, value) }
                        usersAndRoles.append(contentsOf: roleItems)
                    }
                    if currentPermissions.contains(.mentionEveryone) {
                        usersAndRoles.append(contentsOf: [UserOrRole.everyone, UserOrRole.online])
                    }
                }
            }
            
            let filtered = usersAndRoles.filter { value in
                if lowered.isEmpty { return true }
                switch value {
                case .user(let u):
                    return (u.user.display_name?.lowercased().contains(lowered) ?? false) ||
                           (u.member?.nickname?.lowercased().contains(lowered) ?? false) ||
                           u.user.username.lowercased().contains(lowered)
                case .role(_, let r): return r.name.lowercased().contains(lowered)
                case .everyone: return "everyone".contains(lowered)
                case .online: return "online".contains(lowered)
                }
            }
            return .usersAndRoles(Array(filtered.prefix(15)))
            
        case .channel:
            let channels: [Channel] = server?.channels.compactMap { viewState.channels[$0] } ?? []
            let filtered = channels.filter { $0.getName(viewState).lowercased().contains(lowered) }
            return .channels(Array(filtered.prefix(10)))
            
        case .emoji:
            let allEmojis = loadEmojis(withState: viewState).values.flatMap { $0 }
            let filtered = allEmojis.filter { emoji in
                if lowered.isEmpty { return true }
                if let emojiId = emoji.emojiId, let e = viewState.emojis[emojiId] {
                    return e.name.lowercased().contains(lowered)
                }
                let baseStr = String(String.UnicodeScalarView(emoji.base.compactMap(Unicode.Scalar.init)))
                let alternates = emoji.alternates.map { String(String.UnicodeScalarView($0.compactMap(Unicode.Scalar.init))) }
                return baseStr.lowercased().contains(lowered) || alternates.contains { $0.lowercased().contains(lowered) }
            }
            return .emojis(Array(filtered.prefix(20)))
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

            // ── Autocomplete List (Vertical) ──────────────────────────────
            if autoCompleteType != nil && !autocompleteResults.isEmpty {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 1) {
                            switch autocompleteResults {
                            case .usersAndRoles(let items):
                                ForEach(items) { item in
                                    AutocompleteRow(icon: {
                                        switch item {
                                        case .user(let u): AppAvatar(user: u.user, member: u.member, width: 24, height: 24)
                                        case .role(_, _): Image(systemName: "number").foregroundStyle(.secondary)
                                        case .everyone, .online: Image(systemName: "at").foregroundStyle(.secondary)
                                        }
                                    }, label: {
                                        switch item {
                                        case .user(let u): Text(u.member?.nickname ?? u.user.display_name ?? u.user.username).bold()
                                        case .role(_, let r): Text(r.name).bold().foregroundStyle(r.colour.map { parseCSSColorToShapeStyle(currentTheme: viewState.theme, input: $0) } ?? AnyShapeStyle(viewState.theme.foreground))
                                        case .everyone: Text("everyone").bold()
                                        case .online: Text("online").bold()
                                        }
                                    }, sublabel: {
                                        if case .user(let u) = item { Text("@\(u.user.username)").font(.caption).foregroundStyle(.secondary) }
                                    }) {
                                        applyAutocomplete(item)
                                    }
                                }
                            case .channels(let channels):
                                ForEach(channels) { ch in
                                    AutocompleteRow(icon: { 
                                        ChannelIcon(channel: ch)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }, label: { 
                                        Text(ch.getName(viewState))
                                            .fontWeight(.semibold) 
                                    }) {
                                        applyAutocomplete(ch)
                                    }
                                }
                            case .emojis(let emojis):
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(emojis) { emoji in
                                            Button { applyAutocomplete(emoji) } label: {
                                                if let id = emoji.emojiId { LazyImage(source: .emoji(id), height: 28, width: 28, clipTo: Rectangle()) }
                                                else { Text(String(String.UnicodeScalarView(emoji.base.compactMap(Unicode.Scalar.init)))).font(.system(size: 24)) }
                                            }
                                            .frame(width: 44, height: 44)
                                            .background(viewState.theme.background2.color)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                    }
                                    .padding(12)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 280)
                }
                .background(.ultraThinMaterial)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))
                .overlay(
                    VStack {
                        Divider()
                        Spacer()
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // ── Discord-style input bar ───────────────────────────────────
            // Discord-style permission gate: if the user lacks Send Messages
            // in this channel, replace the entire composer with a locked
            // banner. We deliberately keep the layout slot occupied so the
            // chat area doesn't reflow when a moderator toggles permissions
            // live over the websocket.
            if !currentPermissions.contains(.sendMessages) {
                HStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("You do not have permission to send messages in this channel.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
            } else {
                HStack(alignment: .bottom, spacing: 10) {
                    // + Attach button
                    UploadButton(
                        showingSelectFile: $showingSelectFile,
                        showingSelectPhoto: $showingSelectPhoto,
                        selectedPhotoItems: $selectedPhotoItems,
                        selectedPhotos: $selectedPhotos
                    )
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(isDark ? Color(white: 0.18) : Color(white: 0.90)))
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                    .padding(.bottom, 3)
                    .disabled(!currentPermissions.contains(.uploadFiles))
                    .opacity(currentPermissions.contains(.uploadFiles) ? 1 : 0.4)

                    // Main input pill
                    HStack(alignment: .bottom, spacing: 8) {
                        TextField("", text: $content.animation(), axis: .vertical)
                            .focused(focusState)
                            .placeholder(when: content.isEmpty) {
                                Text("Message #\(channel.getName(viewState))")
                                    .foregroundStyle(.secondary.opacity(0.5))
                            }
                            .font(.system(size: 16))
                            .lineLimit(1...8)
                            .padding(.vertical, 10)
                            .padding(.leading, 14)
                            .onChange(of: content) { _, _ in updateAutocomplete() }

                        Button {
                            focusState.wrappedValue = false
                            showingSelectEmoji.toggle()
                        } label: {
                            Image(systemName: "face.smiling")
                                .font(.system(size: 20))
                                .foregroundStyle(.secondary.opacity(0.7))
                                .padding(.bottom, 10)
                                .padding(.trailing, 10)
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 22).fill(isDark ? Color(white: 0.12) : Color(white: 0.94)))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.secondary.opacity(0.1), lineWidth: 0.5))

                    // Send button
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .resizable()
                            .frame(width: 36, height: 36)
                            .foregroundStyle(content.isEmpty && selectedPhotos.isEmpty ? .secondary.opacity(0.3) : viewState.theme.accent.color)
                    }
                    .disabled(content.isEmpty && selectedPhotos.isEmpty)
                    .padding(.bottom, 4)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("InsertEmoji"))) { note in
            if let emoji = note.userInfo?["emoji"] as? PickerEmoji {
                let str: String
                if let id = emoji.emojiId { str = ":\(id): " }
                else { str = String(String.UnicodeScalarView(emoji.base.compactMap(Unicode.Scalar.init))) + " " }
                content += str
            }
        }
    }

    private func applyAutocomplete(_ value: Any) {
        withAnimation {
            if let item = value as? UserOrRole {
                let display: String
                let replace: String
                switch item {
                case .user(let u):
                    display = "@\(u.member?.nickname ?? u.user.display_name ?? u.user.username)"
                    replace = "<@\(u.id)>"
                case .role(let id, let r):
                    display = "@\(r.name)"
                    replace = "<%\(id)>"
                case .everyone: display = "@everyone"; replace = "@everyone"
                case .online: display = "@online"; replace = "@online"
                }
                autocompleteReplacements[display] = replace
                content = String(content.dropLast(autocompleteSearchValue.count + 1)) + "\(display) "
            } else if let ch = value as? Channel {
                let display = "#\(ch.getName(viewState))"
                autocompleteReplacements[display] = "<#\(ch.id)>"
                content = String(content.dropLast(autocompleteSearchValue.count + 1)) + "\(display) "
            } else if let emoji = value as? PickerEmoji {
                let str: String
                if let id = emoji.emojiId { str = ":\(id): " }
                else { str = String(String.UnicodeScalarView(emoji.base.compactMap(Unicode.Scalar.init))) + " " }
                content = String(content.dropLast(autocompleteSearchValue.count + 1)) + str
            }
            autoCompleteType = nil
        }
    }
}

struct AutocompleteRow<I: View, L: View, S: View>: View {
    let icon: I
    let label: L
    var sublabel: S? = nil
    let action: () -> Void
    
    init(@ViewBuilder icon: () -> I, @ViewBuilder label: () -> L, @ViewBuilder sublabel: () -> S, action: @escaping () -> Void) {
        self.icon = icon()
        self.label = label()
        self.sublabel = sublabel()
        self.action = action
    }
    
    init(@ViewBuilder icon: () -> I, @ViewBuilder label: () -> L, action: @escaping () -> Void) where S == EmptyView {
        self.icon = icon()
        self.label = label()
        self.sublabel = nil
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                icon.frame(width: 28, height: 28)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    label.font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                    if let sub = sublabel { 
                        sub.font(.system(size: 12))
                           .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct UploadButton: View {
    @EnvironmentObject var viewState: AppViewState

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
            .onChange(of: selectedPhotoItems) { _, after in
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
                                let fileName = item.itemIdentifier ?? "image-\(UUID().uuidString.prefix(8)).jpg"
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
    static var viewState: AppViewState = AppViewState.preview().applySystemScheme(theme: .dark)
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

