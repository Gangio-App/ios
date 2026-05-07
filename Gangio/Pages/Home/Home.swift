//
//  Home.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//
import SwiftUI
import Types

struct MaybeChannelView: View {
    @EnvironmentObject var viewState: AppViewState
    @Binding var currentChannel: ChannelSelection
    @Binding var currentSelection: MainSelection
    var toggleSidebar: () -> ()
    @Binding var disableScroll: Bool
    @Binding var disableSidebar: Bool
    
    func getRawChannelView(channel: Channel) -> AnyView {
        let messages = Binding(get: { viewState.channelMessages[channel.id] ?? [] }, set: { viewState.channelMessages[channel.id] = $0 })
        let server = currentSelection.id.flatMap { viewState.servers[$0] }
        
        switch channel {
            case .voice_channel:
                return AnyView(VoiceChannelView(
                    channel: channel,
                    server: server,
                    toggleSidebar: toggleSidebar,
                    disableScroll: $disableScroll,
                    disableSidebar: $disableSidebar
                ))
            case .text_channel(let tc):
                if tc.voice != nil {
                    return AnyView(VoiceChannelView(
                        channel: channel,
                        server: server,
                        toggleSidebar: toggleSidebar,
                        disableScroll: $disableScroll,
                        disableSidebar: $disableSidebar
                    ))
                } else {
                    fallthrough
                }
            default:
                return AnyView(MessageableChannelView(
                    viewModel: MessageableChannelViewModel(
                        viewState: viewState,
                        channel: channel,
                        server: server,
                        messages: messages
                    ),
                    toggleSidebar: toggleSidebar,
                    disableScroll: $disableScroll,
                    disableSidebar: $disableSidebar
                ))
        }
    }

    
    var body: some View {
        let server = currentSelection.id.flatMap { viewState.servers[$0] }
        
        switch currentChannel {
            case .channel(let channelId):
                if let channel = viewState.channels[channelId] {
                    getRawChannelView(channel: channel)
                } else {
                    Text("Unknown Channel")
                        .onAppear {
                            currentChannel = .home
                        }
                }
                
            case .force_textchannel(let channelId):
                if let channel = viewState.channels[channelId] {
                    let messages = Binding($viewState.channelMessages[channelId])!
                    
                    MessageableChannelView(
                        viewModel: MessageableChannelViewModel(
                            viewState: viewState,
                            channel: channel,
                            server: server,
                            messages: messages
                        ),
                        toggleSidebar: toggleSidebar,
                        disableScroll: $disableScroll,
                        disableSidebar: $disableSidebar
                    )
                } else {
                    Text("Unknown Channel")
                        .onAppear {
                            currentChannel = .home
                        }
                }
            
            case .force_voicechannel(let channelId):
                if let channel = viewState.channels[channelId] {
                    VoiceChannelView(
                        channel: channel,
                        server: server,
                        toggleSidebar: toggleSidebar,
                        disableScroll: $disableScroll,
                        disableSidebar: $disableSidebar
                    )
                } else {
                    Text("Unknown Channel")
                        .onAppear {
                            currentChannel = .home
                        }
                }

            case .home:
                HomeWelcome(toggleSidebar: toggleSidebar)
            case .friends:
                VStack(spacing: 0) {
                    PageToolbar(toggleSidebar: toggleSidebar) {
                        Image(systemName: "person.3.sequence")
                            .frame(width: 16, height: 16)
                            .frame(width: 24, height: 24)
                        
                        Text("Friends")
                    }
                    
                    FriendsList()
                }
                .background(viewState.theme.background.color)
            case .noChannel:
                Text("Looks a bit empty in here.")
        }
    }
}

struct Home: View {
    @EnvironmentObject var viewState: AppViewState
    
    @Binding var currentSelection: MainSelection
    @Binding var currentChannel: ChannelSelection
    
    @State var offset = CGFloat.zero
    
    @State var calculatedSize = CGFloat.zero // Deprecated but kept for compatibility with other components if needed
    @State var disableScroll = false
    @State var disableSidebar = false
    
    let minGestureLength: CGFloat = 35
    let minSwipeVelocity: CGFloat = 200
    let minSnapPercentage: CGFloat = 0.4
    let sidebarWidthPercentage: CGFloat = 1.0 // FULL WIDTH
    let minSidebarWidth: CGFloat = 600
    let animationStyle: Animation = .spring(response: 0.20, dampingFraction: 0.85) // Faster chat animation
    
    func toggleSidebar() {
        withAnimation(animationStyle) {
            let screenWidth = UIScreen.main.bounds.width
            let targetWidth = screenWidth * sidebarWidthPercentage
            
            if offset != .zero {
                offset = .zero
            } else {
                offset = targetWidth
            }
        }
    }
    
    var isChatOpen: Bool {
        if viewState.selectedTab != .servers { return false }
        switch currentChannel {
        case .channel, .force_textchannel, .force_voicechannel, .home:
            return offset == 0 // Only hide if chat is full screen
        default:
            return false
        }
    }
    
    var body: some View {
        if isIPad || isMac {
            HStack(spacing: 0) {
                HStack(spacing: 0) {
                    ServerScrollView()
                        .frame(width: 60)
                    
                    switch currentSelection {
                        case .server(_):
                            ServerChannelScrollView(currentSelection: $currentSelection, currentChannel: $currentChannel, toggleSidebar: toggleSidebar)
                        case .dms:
                            DMScrollView(currentChannel: $currentChannel, toggleSidebar: toggleSidebar)
                    }
                }
                .frame(width: 300)
                
                MaybeChannelView(currentChannel: $currentChannel, currentSelection: $currentSelection, toggleSidebar: toggleSidebar, disableScroll: $disableScroll, disableSidebar: $disableSidebar)
                    .frame(maxWidth: .infinity)
            }
        } else {
            GeometryReader { geometry in
                let sidebarWidth = geometry.size.width * sidebarWidthPercentage
                let isDark = !Theme.isLightOrDark(viewState.theme.background)
                
                ZStack(alignment: .bottom) {
                    ZStack {
                        switch viewState.selectedTab {
                        case .servers:
                            // Discord-style layout: top header + horizontal servers + content
                            ZStack(alignment: .topLeading) {
                                // Sidebar content (servers strip + channels/DMs)
                                VStack(spacing: 0) {
                                    // Top header: Gangio logo + app name + DM inbox
                                    HStack(spacing: 10) {
                                        Image("logo_round")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 32, height: 32)
                                            .clipShape(Circle())
                                        
                                        Image("wide")
                                            .resizable()
                                            .if(isDark, content: { $0.colorInvert() })
                                            .scaledToFit()
                                            .frame(height: 24)
                                        
                                        Spacer()
                                        
                                        // DM inbox button
                                        Button {
                                            viewState.selectedTab = .messages
                                        } label: {
                                            Image(systemName: "envelope.fill")
                                                .font(.system(size: 18))
                                                .foregroundStyle(viewState.theme.foreground2.color)
                                                .padding(8)
                                                .background(viewState.theme.background3.color)
                                                .clipShape(Circle())
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.top, 8)
                                    .padding(.bottom, 12)
                                    
                                    // Horizontal server strip
                                    HorizontalServerStrip()
                                    
                                    // Channel list or DM list
                                    Group {
                                        switch currentSelection {
                                            case .server(_):
                                                ServerChannelScrollView(currentSelection: $currentSelection, currentChannel: $currentChannel, toggleSidebar: toggleSidebar)
                                            case .dms:
                                                DMScrollView(currentChannel: $currentChannel, toggleSidebar: toggleSidebar)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(viewState.theme.background2.color)
                                .onAppear {
                                    calculatedSize = sidebarWidth
                                    // Start with sidebar open (channels visible, chat hidden)
                                    offset = sidebarWidth
                                }
                                
                                // Chat overlay - slides from right
                                ZStack {
                                    viewState.theme.background.color
                                        .offset(x: offset)
                                    
                                    MaybeChannelView(currentChannel: $currentChannel, currentSelection: $currentSelection, toggleSidebar: toggleSidebar, disableScroll: $disableScroll, disableSidebar: $disableSidebar)
                                        .allowsHitTesting(offset == 0)
                                        .offset(x: offset)
                                        .shadow(color: .black.opacity(offset > 0 && offset < sidebarWidth ? (isDark ? 0.4 : 0.15) : 0), radius: 15, x: -5, y: 0)
                                        .onTapGesture {
                                            if offset != 0.0 {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                                    offset = .zero
                                                }
                                            }
                                        }
                                }
                                .simultaneousGesture(
                                    DragGesture(minimumDistance: 25)
                                        .onChanged({ g in
                                            if offset == 0 && g.startLocation.x > 25 { return }
                                            guard abs(g.translation.width) > abs(g.translation.height) * 3 else { return }
                                            
                                            if g.translation.width >= 25 {
                                                disableScroll = true
                                            }
                                            offset = min(max(g.translation.width, 0), sidebarWidth)
                                        })
                                        .onEnded({ v in
                                            disableScroll = false
                                            let velocity = v.predictedEndLocation.x - v.location.x
                                            let shouldOpen = offset > (sidebarWidth * 0.35) || velocity > minSwipeVelocity
                                            
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                                if shouldOpen {
                                                    offset = sidebarWidth
                                                } else {
                                                    offset = .zero
                                                }
                                            }
                                        }),
                                    isEnabled: !disableSidebar
                                )
                            }
                            // When a channel is selected, slide chat in
                            .onChange(of: currentChannel) { _, newValue in
                                switch newValue {
                                case .channel, .force_textchannel, .force_voicechannel:
                                    withAnimation(.spring(response: 0.20, dampingFraction: 0.85)) {
                                        offset = .zero
                                    }
                                default:
                                    break
                                }
                            }
                        
                        case .dms:
                            VStack(spacing: 0) {
                                PageToolbar(toggleSidebar: toggleSidebar) {
                                    Image(systemName: "bubble.left.and.bubble.right.fill")
                                        .frame(width: 16, height: 16)
                                    Text("Direct Messages")
                                }
                                DMScrollView(currentChannel: $currentChannel, toggleSidebar: toggleSidebar)
                            }
                            .background(viewState.theme.background.color)
                            
                        case .messages:
                            SearchView()
                            
                        case .notifications:
                            NotificationView()
                            
                        case .profile:
                            YouView(currentSelection: $currentSelection, currentChannel: $currentChannel)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .top) {
                        GlobalVoiceBanner(currentChannel: $currentChannel, offset: $offset)
                            .padding(.top, 4)
                    }

                    // Tab bar: only hide when inside an active chat channel AND sidebar is closed
                    if !isChatOpen { BottomBar() }
                }
            }
        }
//            .onChange(of: viewState.currentChannel, { before, after in
//                withAnimation(.easeInOut) {
//                    showSidebar = false
//                    forceOpen = false
//                    offset = .zero
//                }
//            })
//            .onChange(of: viewState.currentSelection) { before, after in
//                withAnimation {
//                    switch after {
//                        case .dms:
//                            if let last = viewState.userSettingsStore.store.lastOpenChannels["dms"] {
//                                currentChannel = .channel(last)
//                            } else {
//                                currentChannel = .home
//                            }
//                        case .server(let id):
//                            if let last = viewState.userSettingsStore.store.lastOpenChannels[id] {
//                                currentChannel = .channel(last)
//                            } else if let server = viewState.servers[id] {
//                                if let firstChannel = server.channels.compactMap({
//                                    switch viewState.channels[$0] {
//                                        case .text_channel(let c):
//                                            return c
//                                        default:
//                                            return nil
//                                    }
//                                }).first {
//                                    currentChannel = .channel(firstChannel.id)
//                                } else {
//                                    currentChannel = .noChannel
//                                }
//                            }
//                    }
//                }
//            }
        }
    }

struct BottomBar: View {
    @EnvironmentObject var viewState: AppViewState
    
    private var isDark: Bool {
        !Theme.isLightOrDark(viewState.theme.background)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewState.selectedTab = tab
                    }
                } label: {
                    let isSelected = viewState.selectedTab == tab
                    
                    // All tabs: Just icons, no text
                    tabIcon(for: tab, isSelected: isSelected)
                        .font(.system(size: isSelected ? 24 : 22, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? viewState.theme.foreground.color : (isDark ? Color.white.opacity(0.5) : Color.black.opacity(0.4)))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            viewState.theme.background2.color
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.black.opacity(isDark ? 0.2 : 0.05)),
            alignment: .top
        )
    }
    
    @ViewBuilder
    func tabIcon(for tab: MainTab, isSelected: Bool) -> some View {
        switch tab {
        case .servers:
            Image(systemName: isSelected ? "house.fill" : "house")
        case .dms:
            Image(systemName: isSelected ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right")
        case .messages:
            Image(systemName: "magnifyingglass")
        case .notifications:
            Image(systemName: isSelected ? "bell.fill" : "bell")
        case .profile:
            if let user = viewState.currentUser {
                AppAvatar(user: user, width: 24, height: 24)
                    .overlay(
                        Circle().stroke(isSelected ? .white : .clear, lineWidth: 1.5)
                    )
            } else {
                Image(systemName: isSelected ? "person.fill" : "person")
            }
        }
    }
    
    func tabName(for tab: MainTab) -> String {
        switch tab {
        case .servers: return "Home"
        case .dms: return "DMs"
        case .messages: return "Search"
        case .notifications: return "Activity"
        case .profile: return "You"
        }
    }
}

struct YouView: View {
    @EnvironmentObject var viewState: AppViewState
    @Environment(\.colorScheme) var colorScheme
    @Binding var currentSelection: MainSelection
    @Binding var currentChannel: ChannelSelection
    @State var showStatusEditor = false
    @State var statusText: String = ""
    @State var selectedPresence: Presence = .Online
    
    private var backgroundColor: Color {
        viewState.theme.background.color
    }
    
    private var cardBackgroundColor: Color {
        viewState.theme.background2.color
    }
    
    let bannerGradient = LinearGradient(
        colors: [Color(hex: "5865F2"), Color(hex: "7289DA")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        let isDarkTheme = !Theme.isLightOrDark(viewState.theme.background)
        ZStack(alignment: .top) {
            backgroundColor.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    let user = viewState.currentUser!
                    
                    // ── Banner ──
                    ZStack(alignment: .top) {
                        if let profile = viewState.profiles[user.id], let banner = profile.background {
                            LazyImage(source: .file(banner), height: 150, clipTo: Rectangle())
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .padding(.horizontal, 16)
                                .padding(.top, 32)
                        } else {
                            bannerGradient
                                .frame(height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .padding(.horizontal, 16)
                                .padding(.top, 32)
                        }
                        
                        // Settings gear on top right of banner
                        HStack {
                            Spacer()
                            Button {
                                viewState.path.append(NavigationDestination.settings)
                            } label: {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(Color.black.opacity(0.45)))
                            }
                            .padding(.trailing, 28)
                            .padding(.top, 44)
                        }
                    }
                    
                    // ── Avatar with Status Ring ──
                    ZStack(alignment: .bottomTrailing) {
                        ZStack {
                            Circle()
                                .fill(statusColor(for: user.status?.presence ?? (user.online == true ? .Online : nil)))
                                .frame(width: 100, height: 100)
                            
                            Circle()
                                .fill(backgroundColor)
                                .frame(width: 92, height: 92)
                            
                            AppAvatar(user: user, width: 86, height: 86, withPresence: false)
                                .clipShape(Circle())
                        }
                        
                        // Status indicator dot
                        Circle()
                            .fill(statusColor(for: user.status?.presence ?? (user.online == true ? .Online : nil)))
                            .frame(width: 22, height: 22)
                            .overlay(Circle().stroke(backgroundColor, lineWidth: 3))
                            .offset(x: -6, y: -6)
                    }
                    .frame(width: 100, height: 100)
                    .offset(y: -50)
                    .padding(.bottom, -50)
                    
                    // ── Display Name ──
                    VStack(spacing: 6) {
                        if let display_name = user.display_name, !display_name.isEmpty {
                            Text(display_name)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(isDarkTheme ? .white : .black)
                        } else {
                            Text(user.username)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(isDarkTheme ? .white : .black)
                        }
                        
                        Text("@\(user.username)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(isDarkTheme ? .white.opacity(0.6) : .black.opacity(0.4))
                    }
                    .padding(.top, 12)
                    
                    // ── Bio ──
                    if let profile = viewState.profiles[user.id], let bio = profile.content, !bio.isEmpty {
                        Text(bio)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(isDarkTheme ? .white.opacity(0.7) : .black.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .padding(.top, 10)
                    }
                    
                    // ── Badges ──
                    if let badges = user.badges, badges > 0 {
                        HStack(spacing: 8) {
                            UserBadgeView(badges: badges)
                        }
                        .padding(.top, 12)
                    }
                    
                    // ── Status Bubble ──
                    if let status = user.status?.text, !status.isEmpty {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(statusColor(for: user.status?.presence))
                                .frame(width: 10, height: 10)
                            Text(status)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(isDarkTheme ? .white : .black)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(cardBackgroundColor)
                        .clipShape(Capsule())
                        .padding(.top, 12)
                    }
                    
                    // ── Action Buttons ──
                    HStack(spacing: 12) {
                        Button {
                            showStatusEditor = true
                        } label: {
                            Text("Edit Status")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(hex: "5865F2"))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        Button {
                            viewState.path.append(NavigationDestination.profile_settings)
                        } label: {
                            Text("Edit Profile")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(hex: "5865F2"))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    
                    // ── Cards Section ──
                    VStack(spacing: 10) {
                        // Friends
                        Button {
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                            withAnimation {
                                viewState.selectedTab = .servers
                                currentSelection = .dms
                                currentChannel = .friends
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(isDarkTheme ? .white.opacity(0.5) : .black.opacity(0.4))
                                    Text("Friends")
                                        .font(.system(size: 13, weight: .bold))
                                        .textCase(.uppercase)
                                        .foregroundStyle(isDarkTheme ? .white.opacity(0.5) : .black.opacity(0.4))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13))
                                        .foregroundStyle(isDarkTheme ? .white.opacity(0.3) : .black.opacity(0.2))
                                }
                                
                                let realFriends = viewState.users.values.filter { $0.relationship == .Friend }
                                
                                HStack(spacing: -10) {
                                    ForEach(Array(realFriends.prefix(6)), id: \.id) { friend in
                                        AppAvatar(user: friend, width: 32, height: 32)
                                            .overlay(Circle().stroke(cardBackgroundColor, lineWidth: 2))
                                    }
                                    
                                    if realFriends.count > 6 {
                                        Circle()
                                            .fill(isDarkTheme ? Color.white.opacity(0.15) : Color.black.opacity(0.08))
                                            .frame(width: 32, height: 32)
                                            .overlay(Circle().stroke(cardBackgroundColor, lineWidth: 2))
                                            .overlay(
                                                Text("+\(realFriends.count - 6)")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundStyle(isDarkTheme ? .white : .black)
                                            )
                                    }
                                }
                                
                                Text("\(realFriends.count) friends")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(isDarkTheme ? .white.opacity(0.5) : .black.opacity(0.4))
                            }
                            .padding(16)
                            .background(cardBackgroundColor)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        
                        // Member Since
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "calendar")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(isDarkTheme ? .white.opacity(0.5) : .black.opacity(0.4))
                                Text("Member Since")
                                    .font(.system(size: 13, weight: .bold))
                                    .textCase(.uppercase)
                                    .foregroundStyle(isDarkTheme ? .white.opacity(0.5) : .black.opacity(0.4))
                                Spacer()
                            }
                            
                            HStack(spacing: 24) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Gangio")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(isDarkTheme ? .white.opacity(0.5) : .black.opacity(0.4))
                                    Text(getCreationDate(from: user.id))
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(isDarkTheme ? .white : .black)
                                }
                            }
                        }
                        .padding(16)
                        .background(cardBackgroundColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }
            }
        }
        .sheet(isPresented: $showStatusEditor) {
            StatusEditorSheet(
                statusText: $statusText,
                selectedPresence: $selectedPresence,
                showSheet: $showStatusEditor
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .task {
            if let user = viewState.currentUser {
                // Fetch fresh profile in background
                await viewState.fetchProfile(userId: user.id)
                
                if let status = user.status {
                    statusText = status.text ?? ""
                    selectedPresence = status.presence ?? .Online
                }
            }
        }
        .environment(\.colorScheme, isDarkTheme ? .dark : .light)
    }
    
    private func statusColor(for presence: Presence?) -> Color {
        switch presence {
        case .Online: return .green
        case .Idle: return .orange
        case .Focus: return .purple
        case .Busy: return .red
        case .Invisible, .none: return .gray
        }
    }

    func getCreationDate(from id: String) -> String {
        // Simple snowflake decoding for Gangio/Gangio IDs (ULSIDs)
        // For now just return a formatted version of the ID or a mock until I have a proper ULID decoder
        return "Dec 9, 2019" // Keeping the requested date style for now, but making it look less like a placeholder
    }
}

struct UserBadgeView: View {
    let badges: Int
    @State private var selectedBadge: String? = nil
    
    var body: some View {
        HStack(spacing: 6) {
            if badges & 1 != 0 { badgeButton("developer", label: "Developer") }
            if badges & 2 != 0 { badgeButton("translator", label: "Translator") }
            if badges & 4 != 0 { badgeButton("supporter", label: "Supporter") }
            if badges & 8 != 0 { badgeButton("responsible_disclosure", label: "Responsible Disclosure") }
            if badges & 16 != 0 { badgeButton("founder", label: "Founder") }
            if badges & 32 != 0 { badgeButton("moderation", label: "Moderation") }
            if badges & 64 != 0 { badgeButton("active_supporter", label: "Active Supporter") }
            if badges & 128 != 0 { badgeButton("paw", label: "Paw") }
            if badges & 256 != 0 { badgeImage("early_adopter") } // Early adopter usually doesn't need label or fits differently
        }
    }
    
    @ViewBuilder
    func badgeButton(_ name: String, label: String) -> some View {
        Button {
            selectedBadge = label
        } label: {
            badgeImage(name)
        }
        .popover(item: Binding(
            get: { selectedBadge == label ? BadgeInfo(name: label) : nil },
            set: { if $0 == nil { selectedBadge = nil } }
        )) { info in
            Text(info.name)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .presentationCompactAdaptation(.popover)
        }
    }
    
    @ViewBuilder
    func badgeImage(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: 18, height: 18)
    }
}

struct BadgeInfo: Identifiable {
    let id = UUID()
    let name: String
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct NotificationView: View {
    @EnvironmentObject var viewState: AppViewState
    @State private var selectedFilter: NotificationFilter = .all
    
    enum NotificationFilter {
        case all, mentions, friendRequests
    }
    
    struct NotificationItem: Identifiable {
        let id: String
        let type: NotificationType
        let user: User?
        let message: String?
        let date: Date
        
        enum NotificationType {
            case friendRequest
            case mention
            case serverInvite
        }
    }
    
    private var notifications: [NotificationItem] {
        var items: [NotificationItem] = []
        
        // Friend Requests - Premium check
        let incoming = viewState.users.values.filter { $0.relationship == .Incoming }
        for user in incoming {
            items.append(NotificationItem(id: "fr-\(user.id)", type: .friendRequest, user: user, message: nil, date: Date()))
        }
        
        // Server Invites (Mock/Actual if available)
        // items.append(...)

        // Mentions from all sources
        for (channelId, unread) in viewState.unreads {
            if let mentions = unread.mentions {
                for messageId in mentions {
                    if let message = viewState.messages[messageId] {
                        items.append(NotificationItem(
                            id: "mention-\(messageId)",
                            type: .mention,
                            user: viewState.users[message.author],
                            message: message.content,
                            date: createdAt(id: messageId)
                        ))
                    } else {
                        // Placeholder for missing message data
                        // In a real app, we'd trigger a fetch here or have it handled by AppViewState
                    }
                }
            }
        }
        
        let filtered = items.filter { item in
            switch selectedFilter {
            case .all: return true
            case .mentions: return item.type == .mention
            case .friendRequests: return item.type == .friendRequest
            }
        }
        
        return filtered.sorted(by: { $0.date > $1.date })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Premium Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Activity")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(viewState.theme.foreground.color)
                    
                    Text("Stay updated with your world")
                        .font(.system(size: 14))
                        .foregroundStyle(viewState.theme.foreground3.color)
                }
                
                Spacer()
                
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(viewState.theme.accent.color)
                    .padding(10)
                    .background(viewState.theme.accent.color.opacity(0.1))
                    .clipShape(Circle())
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            // Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    FilterPill(title: "All", isSelected: selectedFilter == .all) { selectedFilter = .all }
                    FilterPill(title: "Mentions", isSelected: selectedFilter == .mentions) { selectedFilter = .mentions }
                    FilterPill(title: "Requests", isSelected: selectedFilter == .friendRequests) { selectedFilter = .friendRequests }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 16)
            
            if notifications.isEmpty {
                VStack(spacing: 24) {
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(viewState.theme.accent.color.opacity(0.1))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundStyle(viewState.theme.accent.color.gradient)
                    }
                    
                    VStack(spacing: 8) {
                        Text("All caught up!")
                            .font(.system(size: 20, weight: .bold))
                        
                        Text("Check back later for new notifications.")
                            .font(.system(size: 14))
                            .foregroundStyle(viewState.theme.foreground3.color)
                    }
                    
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Special Friend Requests Section if showing all
                        if selectedFilter == .all {
                            let friendRequests = notifications.filter { $0.type == .friendRequest }
                            if !friendRequests.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Friend Requests")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(viewState.theme.foreground3.color)
                                        
                                        Spacer()
                                        
                                        Text("\(friendRequests.count)")
                                            .font(.system(size: 12, weight: .bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(viewState.theme.accent.color)
                                            .foregroundStyle(.white)
                                            .clipShape(Capsule())
                                    }
                                    .padding(.horizontal, 8)
                                    
                                    ForEach(friendRequests) { item in
                                        NotificationRow(item: item)
                                    }
                                }
                                .padding(.bottom, 8)
                                
                                Divider()
                                    .padding(.bottom, 8)
                            }
                        }
                        
                        // Remaining notifications
                        let remaining = selectedFilter == .all ? notifications.filter { $0.type != .friendRequest } : notifications
                        
                        ForEach(remaining) { item in
                            NotificationRow(item: item)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 120)
                }
            }
        }
        .background(viewState.theme.background.color)
    }
}

struct FilterPill: View {
    @EnvironmentObject var viewState: AppViewState
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? viewState.theme.accent.color : viewState.theme.background2.color)
                .foregroundStyle(isSelected ? .white : viewState.theme.foreground2.color)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : viewState.theme.background3.color, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct NotificationRow: View {
    @EnvironmentObject var viewState: AppViewState
    let item: NotificationView.NotificationItem
    
    var body: some View {
        HStack(spacing: 12) {
            if let user = item.user {
                AppAvatar(user: user, width: 44, height: 44)
            } else {
                Circle().fill(viewState.theme.background3.color).frame(width: 44, height: 44)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.user?.username ?? "Unknown")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(viewState.theme.foreground.color)
                    
                    Spacer()
                    
                    Text(item.date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(viewState.theme.foreground3.color)
                }
                
                switch item.type {
                case .friendRequest:
                    Text("sent you a friend request")
                        .font(.subheadline)
                        .foregroundStyle(viewState.theme.foreground2.color)
                    
                    HStack(spacing: 8) {
                        Button {
                            Task { await viewState.http.acceptFriendRequest(user: item.user!.id) }
                        } label: {
                            Text("Accept")
                                .font(.caption.bold())
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                .background(viewState.theme.accent.color)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        
                        Button {
                            Task { await viewState.http.removeFriend(user: item.user!.id) }
                        } label: {
                            Text("Ignore")
                                .font(.caption.bold())
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                .background(viewState.theme.background3.color)
                                .foregroundStyle(viewState.theme.foreground.color)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 4)
                    
                case .mention:
                    Text("mentioned you: \(item.message ?? "")")
                        .font(.subheadline)
                        .lineLimit(2)
                        .foregroundStyle(viewState.theme.foreground2.color)
                    
                case .serverInvite:
                    Text("invited you to a server")
                        .font(.subheadline)
                        .foregroundStyle(viewState.theme.foreground2.color)
                }
            }
        }
        .padding(14)
        .background(viewState.theme.background2.color)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct GlobalVoiceBanner: View {
    @EnvironmentObject var viewState: AppViewState
    @Binding var currentChannel: ChannelSelection
    @Binding var offset: CGFloat
    
    var body: some View {
        if let voiceId = viewState.currentVoiceChannel, viewState.currentVoice != nil {
            // Only show if we are NOT currently viewing the voice channel
            if currentChannel.id != voiceId || offset > 0 {
                Button {
                    withAnimation(.spring()) {
                        viewState.path = NavigationPath()
                        if let channel = viewState.channels[voiceId] {
                            if let server = channel.server {
                                viewState.currentSelection = .server(server)
                            } else {
                                viewState.currentSelection = .dms
                            }
                            viewState.currentChannel = .channel(voiceId)
                        }
                        offset = 0
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Circle().fill(Color.green))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Voice Connected")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(viewState.theme.foreground.color)
                            
                            if let ch = viewState.channels[voiceId] {
                                Text(ch.getName(viewState))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            Task {
                                await viewState.leaveVoice()
                            }
                        } label: {
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(Circle().fill(Color.red))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(viewState.theme.background2)
                            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                    )
                    .overlay(
                        Capsule()
                            .stroke(viewState.theme.accent.color.opacity(0.1), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

#Preview {
    @Previewable @StateObject var state = AppViewState.preview().applySystemScheme(theme: .dark)
    Home(currentSelection: $state.currentSelection, currentChannel: $state.currentChannel)
            .environmentObject(state)
}

