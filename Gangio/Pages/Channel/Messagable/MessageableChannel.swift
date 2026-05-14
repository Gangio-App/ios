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
    private var lastGroupedSnapshot: [String] = []
    
    init(viewState: AppViewState, channel: Channel, server: Server?, messages: Binding<[String]>) {
        self.viewState = viewState
        self.channel = channel
        self.server = server
        self._messages = messages
        
        updateGroups()
    }
    
    func getCachedViewModel(id: String, scrollProxy: ScrollViewProxy, replies: Binding<[Reply]>, editing: Binding<Message?>, highlighted: Binding<String?>) -> MessageContentsViewModel? {
        // Drop cache for messages that were removed from viewState (e.g. after
        // delete) so we never hand back a stale view model.
        if viewState.messages[id] == nil {
            viewModelCache.removeValue(forKey: id)
            return nil
        }
        if let cached = viewModelCache[id] { return cached }
        
        // VM holds only ids + channel-level bindings. Live message/author/member
        // are resolved by the views directly from viewState so SwiftUI's
        // dependency tracking re-renders on any change.
        let newVM = MessageContentsViewModel(
            viewState: viewState,
            messageId: id,
            channelId: channel.id,
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
        
        // Skip recomputation if message ID list is unchanged - avoids unnecessary re-renders
        if uniqueIds == lastGroupedSnapshot && !groupedIds.isEmpty {
            return
        }
        lastGroupedSnapshot = uniqueIds
        
        // Prune cache for removed messages
        let validIds = Set(uniqueIds)
        viewModelCache = viewModelCache.filter { validIds.contains($0.key) }
        
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
            
            // If the server returned fewer than the requested page size, we've
            // reached the start of the channel. This applies to BOTH the
            // initial load (before == nil) and pagination (before != nil) —
            // otherwise small/empty channels keep the top spinner spinning.
            if result.messages.count < 50 {
                DispatchQueue.main.async {
                    self.viewState.atTopOfChannel.insert(self.channel.id)
                }
            }
            
            // If `before` was given, prepend (older messages). Otherwise, merge with existing (latest).
            if before != nil {
                viewState.channelMessages[channel.id] = newUniqueIds + (viewState.channelMessages[channel.id] ?? [])
            } else {
                // Merge new latest messages, keeping order: existing + new (deduplicated)
                let existing = viewState.channelMessages[channel.id] ?? []
                let combined = existing + newUniqueIds
                // Sort by message ID (ULID is time-sortable)
                viewState.channelMessages[channel.id] = combined.sorted()
            }
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
    // StateObject (rather than ObservedObject) so the VM survives body
    // re-evaluations of the parent view. Combined with `.id(channel.id)` in
    // the parent it gets recreated only when the user actually switches
    // channels — not every time `viewState` publishes an unrelated change.
    // This is what makes the very first `loadMoreMessages` from `onAppear`
    // visible immediately, instead of needing the user to navigate away and
    // back to force a fresh VM.
    @StateObject var viewModel: MessageableChannelViewModel
    
    
    
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
                            // Discord-style: welcome header is ALWAYS the first item
                            // in the scroll, regardless of whether older messages
                            // are still being paginated. Pagination is driven by
                            // message-id `onAppear` triggers, not a top spinner.
                            ChannelWelcomeHeader(channel: viewModel.channel)
                                .padding(.horizontal, 16)
                                .padding(.top, 24)
                                .padding(.bottom, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(topID)
                            
                            // Subtle pagination loader, only while older messages
                            // are still loading. Sits between the welcome header
                            // and the messages so it never pushes the header.
                            if !viewState.atTopOfChannel.contains(viewModel.channel.id) && viewModel.isLoading {
                                ProgressView()
                                    .padding(.vertical, 8)
                            }
                            
                            ForEach(Array(viewModel.groupedIds.enumerated()), id: \.element.id) { idx, group in
                                let vms = group.messages.compactMap { id in getCachedViewModel(id: id, scrollProxy: proxy) }
                                if !vms.isEmpty {
                                    // Day divider: show when this group's date differs from the previous one
                                    if shouldShowDateDivider(at: idx) {
                                        DateDivider(date: createdAt(id: group.id))
                                            .padding(.vertical, 8)
                                    }
                                    MessageGroupContainer(group: vms, selection: .constant([]), highlighted: $viewModel.highlighted)
                                        .id(group.id)
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
                        // Force-assume we're at bottom on initial appearance so any
                        // groupedIds change while loading scrolls down to latest.
                        nearBottom = true
                        
                        let cached = viewState.channelMessages[viewModel.channel.id] ?? []
                        if cached.isEmpty {
                            Task {
                                _ = await viewModel.loadMoreMessages()
                                await MainActor.run {
                                    handleInitialScroll(proxy: proxy)
                                }
                            }
                        } else {
                            viewModel.updateGroups()
                            // Always refresh to get latest messages on channel open
                            Task {
                                _ = await viewModel.loadMoreMessages()
                                await MainActor.run {
                                    // Always scroll to bottom after refresh on channel open,
                                    // regardless of where the cached scroll ended up.
                                    handleInitialScroll(proxy: proxy)
                                    // Second tick to guarantee layout completion
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        handleInitialScroll(proxy: proxy)
                                    }
                                }
                            }
                        }
                        
                        // Immediate scroll to bottom
                        handleInitialScroll(proxy: proxy)
                        
                        // Fallback delayed scroll to ensure layout is ready
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                handleInitialScroll(proxy: proxy)
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
    
    /// Returns true if a date divider should appear above the group at `idx`.
    func shouldShowDateDivider(at idx: Int) -> Bool {
        guard idx < viewModel.groupedIds.count else { return false }
        let currentGroup = viewModel.groupedIds[idx]
        let currentDate = createdAt(id: currentGroup.id)
        let calendar = Calendar.current
        
        if idx == 0 {
            return true  // Always show divider for the first group
        }
        
        let prevGroup = viewModel.groupedIds[idx - 1]
        let prevDate = createdAt(id: prevGroup.id)
        return !calendar.isDate(currentDate, inSameDayAs: prevDate)
    }
    
    /// Handle initial scroll - either to a pending search target or to the bottom
    func handleInitialScroll(proxy: ScrollViewProxy) {
        if let target = viewState.pendingScrollToMessage,
           let msgs = viewState.channelMessages[viewModel.channel.id],
           msgs.contains(target) {
            withAnimation(.easeInOut) {
                proxy.scrollTo(target, anchor: .center)
            }
            viewModel.highlighted = target
            // Clear pending after a short delay to allow render
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                viewState.pendingScrollToMessage = nil
            }
            // Clear highlight after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if viewModel.highlighted == target {
                    viewModel.highlighted = nil
                }
            }
        } else {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
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

    /// Whether the current user is allowed to read message history here.
    /// Used as the deep-link / cached-channel safety net: even if a stale
    /// `lastOpenChannel` or a search hit lands the user on a channel they
    /// can no longer access, we render a Discord-style "no access" screen
    /// instead of silently fetching messages they shouldn't see.
    private var canReadHistory: Bool {
        viewState.channelPermissions(for: viewModel.channel)
            .contains(.readMessageHistory)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            toolbarContent
            if canReadHistory {
                messagesContent
            } else {
                noAccessContent
            }
        }
        .frame(maxWidth: .infinity)
        .background(viewState.theme.background)
    }
    
    @ViewBuilder
    private var noAccessContent: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "lock.shield")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No access")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(viewState.theme.foreground.color)
            Text("You don't have permission to view this channel.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    
    private var liveMessage: Message {
        viewState.messages[viewModel.messageId]
            ?? Message(id: viewModel.messageId, content: nil, author: "", channel: viewModel.channelId)
    }
    
    private var canManageMessages: Bool {
        let member = viewModel.server.flatMap {
            viewState.members[$0.id]?[viewState.currentUser!.id]
        }
        let permissions = resolveChannelPermissions(from: viewState.currentUser!, targettingUser: viewState.currentUser!, targettingMember: member, channel: viewModel.channel, server: viewModel.server)
        return permissions.contains(.manageMessages)
    }
    
    private var isMessageAuthor: Bool {
        liveMessage.author == viewState.currentUser?.id
    }
    
    private var canDeleteMessage: Bool {
        return isMessageAuthor || canManageMessages
    }
    
    func toggle() {
        let id = viewModel.messageId
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }
    
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        // Resolve once per render so SwiftUI tracks viewState.messages.
        let message = liveMessage
        let messageId = viewModel.messageId
        
        HStack(alignment: .center, spacing: 0) {
            if !selection.isEmpty {
                let contains = selection.contains(messageId)
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
                    _ = await viewState.http.reactMessage(channel: viewModel.channelId, message: messageId, emoji: emoji.id)
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
        .background((message.mentions?.firstIndex(of: viewState.currentUser!.id) != nil || highlighted == messageId
                     ? viewState.theme.mention
                     : viewState.theme.background).animation(.default))
        .contextMenu {
            if isMessageAuthor {
                Button {
                    Task {
                        var replies: [Reply] = []
                        for reply in message.replies ?? [] {
                            var msg: Message? = viewState.messages[reply]
                            if msg == nil {
                                msg = try? await viewState.http.fetchMessage(channel: viewModel.channel.id, message: reply).get()
                            }
                            if let msg {
                                replies.append(Reply(message: msg, mention: message.mentions?.contains(msg.author) ?? false))
                            }
                        }
                        viewModel.channelReplies = replies
                        viewModel.editing = message
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
            
            if !(message.reactions?.isEmpty ?? true) {
                Button {
                    showReactionsSheet = true
                } label: {
                    Label("Reactions", systemImage: "face.smiling.inverse")
                }
            }
            
            if canManageMessages {
                if !(message.pinned ?? false) {
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
                copyText(text: message.content ?? "")
            } label: {
                Label("Copy text", systemImage: "doc.on.clipboard")
            }
            
            Button {
                if let server = viewModel.server {
                    copyUrl(url: URL(string: "https://gangio.pro/server/\(server.id)/channel/\(viewModel.channel.id)/\(messageId)")!)
                } else {
                    copyUrl(url: URL(string: "https://gangio.pro/channel/\(viewModel.channel.id)/\(messageId)")!)
                }
            } label: {
                Label("Copy Message Link", systemImage: "link")
            }
            
            Button {
                copyText(text: messageId)
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
            DragGesture(minimumDistance: 30)
                .onChanged { value in
                    // Strict check: horizontal must be 6x vertical AND vertical movement must be tiny
                    if abs(value.translation.width) > abs(value.translation.height) * 6 && abs(value.translation.height) < 10 {
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
        // Guard against an empty group; the parent already filters but keep
        // this safe since `group.first!` would crash an entire channel.
        if let first = group.first {
            let rest = group.dropFirst()
            
            VStack(alignment: .leading, spacing: 0) {
                if first.messageId == viewState.unreads[first.channelId]?.last_id,
                   first.messageId != viewState.channelMessages[first.channelId]?.last {
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
                    let liveMsg = viewState.messages[message.messageId]
                    MessageWrapper(viewModel: message, highlighted: $highlighted) {
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Group {
                                if liveMsg?.edited != nil {
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
}

/// Discord-style welcome header shown at the very top of a channel once the
/// user has scrolled (or paginated) past the first message.
struct ChannelWelcomeHeader: View {
    @EnvironmentObject var viewState: AppViewState
    let channel: Channel
    
    private var isTextChannel: Bool {
        if case .text_channel = channel { return true }
        return false
    }
    
    private var iconSystemName: String {
        switch channel {
        case .text_channel: return "number"
        case .voice_channel: return "speaker.wave.2.fill"
        case .dm_channel, .group_dm_channel: return "at"
        case .saved_messages: return "bookmark.fill"
        }
    }
    
    var body: some View {
        let name = channel.getName(viewState)
        VStack(alignment: .leading, spacing: 10) {
            // Big circular channel icon
            ZStack {
                Circle()
                    .fill(viewState.theme.background2.color)
                    .frame(width: 72, height: 72)
                Image(systemName: iconSystemName)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(viewState.theme.foreground.color)
            }
            .padding(.bottom, 4)
            
            // Title
            Text(verbatim: isTextChannel ? "Welcome to #\(name)!" : "Welcome to \(name)!")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(viewState.theme.foreground.color)
            
            // Subtitle
            Text(isTextChannel
                 ? "This is the start of the #\(name) channel."
                 : "This is the start of \(name).")
                .font(.system(size: 15))
                .foregroundStyle(viewState.theme.foreground2.color)
            
            // Description if present (text channels only)
            if case .text_channel(let tc) = channel,
               let description = tc.description,
               !description.isEmpty {
                Text(verbatim: description)
                    .font(.system(size: 14))
                    .foregroundStyle(viewState.theme.foreground2.color.opacity(0.85))
                    .padding(.top, 2)
            }
        }
    }
}

#Preview {
    @Previewable @StateObject var viewState = AppViewState.preview()
    let messages = Binding($viewState.channelMessages["0"])!
    return MessageableChannelView(viewModel: .init(viewState: viewState, channel: viewState.channels["0"]!, server: viewState.servers[""], messages: messages), toggleSidebar: {}, disableScroll: .constant(false), disableSidebar: .constant(false))
        .applyPreviewModifiers(withState: viewState)
}
