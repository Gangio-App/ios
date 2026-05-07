//
//  MessageableChannel.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import SwiftUI
import Types
import SwipeActions

struct ChannelScrollController {
    var proxy: ScrollViewProxy?
    @Binding var highlighted: String?
    
    func scrollTo(message id: String) {
        withAnimation(.easeInOut) {
            proxy?.scrollTo(id)
            highlighted = id
        }
        
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            
            withAnimation(.easeInOut) {
                highlighted = nil
            }
        }
    }
    
    static var empty: ChannelScrollController {
        .init(proxy: nil, highlighted: .constant(nil))
    }
}

struct MessageGroup: Identifiable, Equatable {
    let id: String
    var messages: [String]
}

@MainActor
class MessageableChannelViewModel: ObservableObject {
    @ObservedObject var viewState: AppViewState
    @Published var channel: Channel
    @Published var server: Server?
    @Binding var messages: [String]
    
    @Published var groupedIds: [MessageGroup] = []
    @Published var highlighted: String? = nil
    @Published var currentlyEditing: Message? = nil
    @Published var replies: [Reply] = []
    @Published var isLoading: Bool = false
    @Published var lastError: String? = nil
    
    private var viewModelCache: [String: MessageContentsViewModel] = [:]
    
    init(viewState: AppViewState, channel: Channel, server: Server?, messages: Binding<[String]>) {
        self.viewState = viewState
        self.channel = channel
        self.server = server
        self._messages = messages
        
        updateGroups()
    }
    
    func getCachedViewModel(id: String, scrollProxy: ScrollViewProxy, replies: Binding<[Reply]>, editing: Binding<Message?>, highlighted: Binding<String?>) -> MessageContentsViewModel? {
        if let cached = viewModelCache[id] { return cached }
        guard viewState.messages[id] != nil else { return nil }
        
        let msg = Binding<Message>(
            get: { self.viewState.messages[id]! },
            set: { self.viewState.messages[id] = $0 }
        )
        
        let author = Binding<User>(
            get: { self.viewState.users[msg.wrappedValue.author] ?? User(id: String(repeating: "0", count: 26), username: "Unknown", discriminator: "0000") },
            set: { self.viewState.users[msg.wrappedValue.author] = $0 }
        )
        
        let member = Binding<Member?>(
            get: { 
                guard let sid = self.server?.id else { return nil }
                return self.viewState.members[sid]?[msg.wrappedValue.author]
            },
            set: { newValue in
                guard let sid = self.server?.id else { return }
                if self.viewState.members[sid] != nil {
                    self.viewState.members[sid]![msg.wrappedValue.author] = newValue
                }
            }
        )

        let newVM = MessageContentsViewModel(
            viewState: viewState,
            message: msg,
            author: author,
            member: member,
            server: Binding(get: { self.server }, set: { self.server = $0 }),
            channel: Binding(get: { self.channel }, set: { self.channel = $0 }),
            replies: replies,
            channelScrollPosition: ChannelScrollController(proxy: scrollProxy, highlighted: highlighted),
            editing: editing
        )
        viewModelCache[id] = newVM
        return newVM
    }
    
    func updateGroups() {
        let ids = viewState.channelMessages[channel.id] ?? []
        var seen = Set<String>()
        let uniqueIds = ids.filter { seen.insert($0).inserted }
        
        var groups: [MessageGroup] = []
        for id in uniqueIds {
            guard let msg = viewState.messages[id] else { continue }
            
            if let lastGroupIndex = groups.indices.last {
                let lastId = groups[lastGroupIndex].messages.last!
                if let lastMsg = viewState.messages[lastId] {
                    let sameAuthor = lastMsg.author == msg.author
                    let noReplies = (msg.replies?.count ?? 0) == 0
                    let closeTime = createdAt(id: lastMsg.id).distance(to: createdAt(id: msg.id)) < (5 * 60)
                    
                    if sameAuthor && noReplies && closeTime && !TEMP_IS_COMPACT_MODE.0 {
                        groups[lastGroupIndex].messages.append(id)
                        continue
                    }
                }
            }
            groups.append(MessageGroup(id: id, messages: [id]))
        }
        self.groupedIds = groups
    }

    func loadMoreMessages(before: String? = nil) async -> FetchHistory? {
        guard !isLoading else { return nil }
        isLoading = true
        lastError = nil
        
        if isPreview { 
            isLoading = false
            return nil 
        }
        
        print("[Gangio] Fetching history for \(channel.id) before \(before ?? "now")")
        
        let resultResp = await viewState.http.fetchHistory(channel: channel.id, limit: 50, before: before)
        
        switch resultResp {
        case .success(let result):
            print("[Gangio] Successfully fetched \(result.messages.count) messages")
            
            for user in result.users { viewState.users[user.id] = user }
            if let members = result.members {
                for member in members { viewState.members[member.id.server, default: [:]][member.id.user] = member }
            }
            
            var ids: [String] = []
            for message in result.messages {
                viewState.messages[message.id] = message
                ids.append(message.id)
            }
            
            let existingIds = Set(viewState.channelMessages[channel.id] ?? [])
            let newUniqueIds = ids.reversed().filter { !existingIds.contains($0) }
            
            if result.messages.count < 50 {
                DispatchQueue.main.async {
                    self.viewState.atTopOfChannel.insert(self.channel.id)
                }
            }
            
            viewState.channelMessages[channel.id] = newUniqueIds + (viewState.channelMessages[channel.id] ?? [])
            updateGroups()
            isLoading = false
            return result
            
        case .failure(let error):
            print("[Gangio] ERROR fetching history: \(error)")
            lastError = "Failed to load messages"
            isLoading = false
            
            // Mark as top of channel to stop infinite loading loops on persistent error
            DispatchQueue.main.async {
                self.viewState.atTopOfChannel.insert(self.channel.id)
            }
            return nil
        }
    }
    
    func loadMoreMessagesIfNeeded(current: String?) async {
        let msgs = viewState.channelMessages[channel.id] ?? []
        guard let item = current, msgs.first == item else { return }
        await loadMoreMessages(before: item)
    }
}

struct MessageableChannelView: View {
    @EnvironmentObject var viewState: AppViewState
    @ObservedObject var viewModel: MessageableChannelViewModel
    
    
    
    @State var over18: Bool = false
    @State var showDetails: Bool = false
    @State var showingSelectEmoji = false
    @State var nearBottom: Bool = false
    @State private var isLoadingMore: Bool = false
    @State private var lastAckedMessageId: String? = nil
    
    var toggleSidebar: () -> ()
    
    @Binding var disableScroll: Bool
    @Binding var disableSidebar: Bool
    
    @FocusState var focused: Bool
    @Namespace var topID
    
    private var toolbarContent: some View {
        PageToolbar(toggleSidebar: toggleSidebar) {
            NavigationLink(value: NavigationDestination.channel_info(viewModel.channel.id)) {
                ChannelIcon(channel: viewModel.channel)
                Image(systemName: "chevron.right")
                    .frame(height: 4)
            }
        } trailing: {
            switch viewModel.channel {
                case .dm_channel, .group_dm_channel:
                    AnyView(Button {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        viewState.currentChannel = .force_voicechannel(viewModel.channel.id)
                    } label: {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Color.green)
                            .clipShape(Circle())
                    })
                default:
                    AnyView(EmptyView())
            }
        }
    }
    
    @ViewBuilder
    private var messagesContent: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ZStack(alignment: .bottomTrailing) {
                    ScrollView {
                        LazyVStack(spacing: max(CGFloat(viewState.messageSpacing), 8)) {
                            if viewState.atTopOfChannel.contains(viewModel.channel.id) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("#\(viewModel.channel.getName(viewState))")
                                        .font(.system(size: 32, weight: .bold))
                                    Text("This is the start of the #\(viewModel.channel.getName(viewState)) channel.")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 32)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                ProgressView().padding(.vertical, 20).id(topID)
                            }

                            ForEach(viewModel.groupedIds) { group in
                                let vms = group.messages.compactMap { id in getCachedViewModel(id: id, scrollProxy: proxy) }
                                if !vms.isEmpty {
                                    MessageGroupContainer(group: vms, selection: .constant([]), highlighted: $viewModel.highlighted)
                                }
                            }
                            
                            // Bottom anchor for reliable scrolling and visibility tracking
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                                .onAppear { nearBottom = true }
                                .onDisappear { nearBottom = false }
                        }
                        .padding(.bottom, 8)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .coordinateSpace(name: "scroll")
                    .onChange(of: viewState.channelMessages[viewModel.channel.id]) { _, _ in
                        viewModel.updateGroups()
                        if nearBottom {
                            withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                        }
                    }
                    .onAppear {
                        if (viewState.channelMessages[viewModel.channel.id] ?? []).isEmpty {
                            Task {
                                _ = await viewModel.loadMoreMessages()
                                DispatchQueue.main.async {
                                    proxy.scrollTo("bottom", anchor: .bottom)
                                }
                            }
                        } else {
                            viewModel.updateGroups()
                        }
                        
                        // Immediate scroll to bottom
                        proxy.scrollTo("bottom", anchor: .bottom)
                        
                        // Fallback delayed scroll to ensure layout is ready
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: viewModel.groupedIds) { _, _ in
                        if nearBottom || viewModel.messages.count < 20 {
                            withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                        // Follow chat when keyboard opens
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: focused) { _, isFocused in
                        if isFocused {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                            }
                        }
                    }

                    // Jump to bottom button
                    if !nearBottom {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { 
                                proxy.scrollTo("bottom", anchor: .bottom) 
                            }
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(viewState.theme.foreground.color)
                                .padding(12)
                                .background(Circle().fill(viewState.theme.background2.color).shadow(color: .black.opacity(0.2), radius: 8, y: 4))
                        }
                        .padding(16)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if let users = getCurrentlyTyping(), !users.isEmpty {
                        HStack(spacing: 8) {
                            TypingIndicator()
                                .frame(width: 24, height: 12)
                            Text(formatTypingIndicatorText(withUsers: users))
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.leading, 12)
                        .padding(.bottom, 4)
                    }
                }
            }
            
            MessageBox(
                channel: viewModel.channel,
                server: viewModel.server,
                channelReplies: $viewModel.replies,
                focusState: $focused,
                showingSelectEmoji: $showingSelectEmoji,
                editing: $viewModel.currentlyEditing
            )
        }
        .sheet(isPresented: $showingSelectEmoji) {
            EmojiPicker(background: AnyView(viewState.theme.background)) { emoji in
                showingSelectEmoji = false
                NotificationCenter.default.post(name: NSNotification.Name("InsertEmoji"), object: nil, userInfo: ["emoji": emoji])
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(viewState.theme.background)
        }
    }
    
    func getAuthor(message: Binding<Message>) -> Binding<User> {
        Binding($viewState.users[message.author.wrappedValue]) ?? .constant(User(id: String(repeating: "0", count: 26), username: "Unknown", discriminator: "0000"))
    }
    
    func getCachedViewModel(id: String, scrollProxy: ScrollViewProxy) -> MessageContentsViewModel? {
        viewModel.getCachedViewModel(
            id: id,
            scrollProxy: scrollProxy,
            replies: $viewModel.replies,
            editing: $viewModel.currentlyEditing,
            highlighted: $viewModel.highlighted
        )
    }
    
    func getMember(message: Message) -> Binding<Member?> {
        if let server = viewModel.server {
            return Binding($viewState.members[server.id])?[message.author] ?? .constant(nil)
        }
        return .constant(nil)
    }
    
    func getCurrentlyTyping() -> [(User, Member?)]? {
        viewState.currentlyTyping[viewModel.channel.id]?.compactMap({ user_id in
            guard let user = viewState.users[user_id] else { return nil }
            var member: Member?
            if let server = viewModel.server {
                member = viewState.members[server.id]?[user_id]
            }
            return (user, member)
        })
    }
    
    func formatTypingIndicatorText(withUsers users: [(User, Member?)]) -> String {
        let base = ListFormatter.localizedString(byJoining: users.map({ (user, member) in member?.nickname ?? user.display_name ?? user.username }))
        let ending = users.count == 1 ? "is typing" : "are typing"
        return "\(base) \(ending)..."
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbarContent
            messagesContent
        }
        .frame(maxWidth: .infinity)
        .background(viewState.theme.background)
    }
}

struct TypingIndicator: View {
    @State private var phase: CGFloat = 0
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { i in
                Circle().fill(.secondary).frame(width: 4, height: 4)
                    .offset(y: phase == CGFloat(i) ? -3 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4).repeatForever()) {
                phase = 2
            }
        }
    }
}

struct MessageWrapper<C: View>: View {
    @EnvironmentObject var viewState: AppViewState
    @Environment(\.channelMessageSelection) @Binding var selection
    
    @ObservedObject var viewModel: MessageContentsViewModel
    @Binding var highlighted: String?
    
    @ViewBuilder var inner: () -> C
    
    @State var showMemberSheet: Bool = false
    @State var showReportSheet: Bool = false
    @State var showReactSheet: Bool = false
    @State var showReactionsSheet: Bool = false
    
    private var canManageMessages: Bool {
        let member = viewModel.server.flatMap {
            viewState.members[$0.id]?[viewState.currentUser!.id]
        }
        let permissions = resolveChannelPermissions(from: viewState.currentUser!, targettingUser: viewState.currentUser!, targettingMember: member, channel: viewModel.channel, server: viewModel.server)
        return permissions.contains(.manageMessages)
    }
    
    private var isMessageAuthor: Bool {
        viewModel.message.author == viewState.currentUser?.id
    }
    
    private var canDeleteMessage: Bool {
        return isMessageAuthor || canManageMessages
    }
    
    func toggle() {
        if selection.contains(viewModel.message.id) {
            selection.remove(viewModel.message.id)
        } else {
            selection.insert(viewModel.message.id)
        }
    }
    
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            if !selection.isEmpty {
                let contains = selection.contains(viewModel.message.id)
                Image(systemName: contains ? "checkmark.circle.fill" : "circle")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(contains ? viewState.theme.foreground : viewState.theme.background2, viewState.theme.accent)
                    .padding(.leading, 12)
                    .padding(.trailing, 12)
            }
            inner()
            Spacer()
        }
        .sheet(isPresented: $showReportSheet) {
            ReportMessageSheetView(showSheet: $showReportSheet, messageView: viewModel)
                .presentationBackground(viewState.theme.background)
        }
        .sheet(isPresented: $showReactSheet) {
            EmojiPicker(background: AnyView(viewState.theme.background)) { emoji in
                Task {
                    showReactSheet = false
                    _ = await viewState.http.reactMessage(channel: viewModel.message.channel, message: viewModel.message.id, emoji: emoji.id)
                }
            }
            .padding([.top, .horizontal])
            .background(viewState.theme.background.ignoresSafeArea(.all))
            .presentationDetents([.large])
            .presentationBackground(viewState.theme.background)
        }
        .sheet(isPresented: $showReactionsSheet) {
            MessageReactionsSheet(viewModel: viewModel)
        }
        .background((viewModel.message.mentions?.firstIndex(of: viewState.currentUser!.id) != nil || highlighted == viewModel.message.id
                     ? viewState.theme.mention
                     : viewState.theme.background).animation(.default))
        .contextMenu {
            if isMessageAuthor {
                Button {
                    Task {
                        var replies: [Reply] = []
                        for reply in viewModel.message.replies ?? [] {
                            var message: Message? = viewState.messages[reply]
                            if message == nil {
                                message = try? await viewState.http.fetchMessage(channel: viewModel.channel.id, message: reply).get()
                            }
                            if let message {
                                replies.append(Reply(message: message, mention: viewModel.message.mentions?.contains(message.author) ?? false))
                            }
                        }
                        viewModel.channelReplies = replies
                        viewModel.editing = viewModel.message
                    }
                } label: {
                    Label("Edit Message", systemImage: "pencil")
                }
            }
            
            Button(action: viewModel.reply, label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left.fill")
            })
            
            Button {
                showReactSheet = true
            } label: {
                Label("React", systemImage: "face.smiling.inverse")
            }
            
            if !(viewModel.message.reactions?.isEmpty ?? true) {
                Button {
                    showReactionsSheet = true
                } label: {
                    Label("Reactions", systemImage: "face.smiling.inverse")
                }
            }
            
            if canManageMessages {
                if !(viewModel.message.pinned ?? false) {
                    Button {
                        Task { await viewModel.pin() }
                    } label: {
                        Label("Pin Message", systemImage: "pin.fill")
                    }
                } else {
                    Button {
                        Task { await viewModel.unpin() }
                    } label: {
                        Label("Unpin Message", systemImage: "pin.slash.fill")
                    }
                }
            }
            
            Button {
                copyText(text: viewModel.message.content ?? "")
            } label: {
                Label("Copy text", systemImage: "doc.on.clipboard")
            }
            
            Button {
                if let server = viewModel.server {
                    copyUrl(url: URL(string: "https://gangio.pro/server/\(server.id)/channel/\(viewModel.channel.id)/\(viewModel.message.id)")!)
                } else {
                    copyUrl(url: URL(string: "https://gangio.pro/channel/\(viewModel.channel.id)/\(viewModel.message.id)")!)
                }
            } label: {
                Label("Copy Message Link", systemImage: "link")
            }
            
            Button {
                copyText(text: viewModel.message.id)
            } label: {
                Label("Copy Message ID", systemImage: "doc.on.clipboard")
            }
            
            Button {
                toggle()
            } label: {
                Label("Select Message", systemImage: "checkmark.circle.fill")
            }
            
            if canDeleteMessage {
                Button(role: .destructive, action: {
                    Task { await viewModel.delete() }
                }, label: {
                    Label("Delete Message", systemImage: "trash")
                })
            }
            
            if !isMessageAuthor {
                Button(role: .destructive, action: { showReportSheet.toggle() }, label: {
                    Label("Report Message", systemImage: "exclamationmark.triangle")
                })
            }
        }
        .gesture(TapGesture().onEnded(toggle), isEnabled: !selection.isEmpty)
        .offset(x: dragOffset)
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    // Extremely strict check: horizontal must be 4x vertical AND vertical movement must be tiny
                    if abs(value.translation.width) > abs(value.translation.height) * 4 && abs(value.translation.height) < 15 {
                        if value.translation.width < 0 {
                            dragOffset = max(value.translation.width, -60)
                        }
                    }
                }
                .onEnded { value in
                    if dragOffset < -40 {
                        viewModel.reply()
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dragOffset = 0
                    }
                }
        )
    }
}

struct MessageGroupContainer: View {
    @EnvironmentObject var viewState: AppViewState
    let group: [MessageContentsViewModel]
    @Binding var selection: Set<String>
    @Binding var highlighted: String?
    
    var body: some View {
        let first = group.first!
        let rest = group.dropFirst()
        
        VStack(alignment: .leading, spacing: 0) {
            if first.message.id == viewState.unreads[first.channel.id]?.last_id,
               first.message.id != viewState.channelMessages[first.channel.id]?.last {
                HStack(spacing: 0) {
                    Text("NEW")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .background(RoundedRectangle(cornerRadius: 100).foregroundStyle(viewState.theme.accent))
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(viewState.theme.accent)
                }
            }
            
            MessageWrapper(viewModel: first, highlighted: $highlighted) {
                MessageView(viewModel: first, isStatic: false)
                    .padding(.top, 6)
                    .padding(.leading, selection.isEmpty ? 12 : 0)
                    .padding(.bottom, rest.isEmpty ? 6 : 2)
                    .padding(.trailing, selection.isEmpty ? 12 : 4)
            }
            .environment(\.channelMessageSelection, $selection)
            
            ForEach(rest) { message in
                MessageWrapper(viewModel: message, highlighted: $highlighted) {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Group {
                            if message.message.edited != nil {
                                Text("(edited)")
                                    .font(.caption)
                                    .foregroundStyle(viewState.theme.foreground3)
                                    .multilineTextAlignment(.center)
                            } else {
                                Spacer()
                            }
                        }
                        .frame(width: 60)
                        MessageContentsView(viewModel: message)
                    }
                    .padding(.trailing, selection.isEmpty ? 12 : 4)
                }
            }
            .environment(\.channelMessageSelection, $selection)
        }
    }
}

#Preview {
    @Previewable @StateObject var viewState = AppViewState.preview()
    let messages = Binding($viewState.channelMessages["0"])!
    return MessageableChannelView(viewModel: .init(viewState: viewState, channel: viewState.channels["0"]!, server: viewState.servers[""], messages: messages), toggleSidebar: {}, disableScroll: .constant(false), disableSidebar: .constant(false))
        .applyPreviewModifiers(withState: viewState)
}
