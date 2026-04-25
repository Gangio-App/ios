//
//  Home.swift
//  Gangio
//
//  Created by benyigit on 25/04/2026.
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
    let sidebarWidthPercentage: CGFloat = 0.85
    let minSidebarWidth: CGFloat = 600
    let animationStyle: Animation = .spring(response: 0.3, dampingFraction: 0.85)
    
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
                
                ZStack(alignment: .bottom) {
                    ZStack {
                        switch viewState.selectedTab {
                        case .servers:
                            // The original sidebar layout for server navigation
                            ZStack(alignment: .topLeading) {
                                HStack(spacing: 0) {
                                    ServerScrollView()
                                        .frame(width: 60)
                                    
                                    Group {
                                        switch currentSelection {
                                            case .server(_):
                                                ServerChannelScrollView(currentSelection: $currentSelection, currentChannel: $currentChannel, toggleSidebar: toggleSidebar)
                                            case .dms:
                                                DMScrollView(currentChannel: $currentChannel, toggleSidebar: toggleSidebar)
                                        }
                                    }
                                    .frame(width: sidebarWidth - 60) // Explicitly set width to prevent layout ambiguity
                                }
                                .frame(width: sidebarWidth, alignment: .leading)
                                .background(viewState.theme.background2.color)
                                .onAppear {
                                    calculatedSize = sidebarWidth
                                }
                                
                                ZStack {
                                    viewState.theme.messageBox
                                        .offset(x: offset)
                                        .ignoresSafeArea(.all)
                                    
                                    MaybeChannelView(currentChannel: $currentChannel, currentSelection: $currentSelection, toggleSidebar: toggleSidebar, disableScroll: $disableScroll, disableSidebar: $disableSidebar)
                                        .allowsHitTesting(offset == 0)
                                        .offset(x: offset)
                                        .shadow(color: .black.opacity(offset > 0 ? 0.3 : 0), radius: 10, x: -5, y: 0) // Aesthetic depth
                                        .onTapGesture {
                                            if offset != 0.0 {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                                    offset = .zero
                                                }
                                            }
                                        }
                                }
                                .simultaneousGesture(
                                    DragGesture(minimumDistance: minGestureLength)
                                        .onChanged({ g in
                                            // Only trigger if swipe is primarily horizontal
                                            guard abs(g.translation.width) > abs(g.translation.height) else { return }
                                            
                                            if g.translation.width >= minGestureLength {
                                                disableScroll = true
                                            }
                                            
                                            // Smooth direct tracking
                                            offset = min(max(g.translation.width, 0), sidebarWidth)
                                        })
                                        .onEnded({ v in
                                            disableScroll = false
                                            let velocity = v.predictedEndLocation.x - v.location.x
                                            
                                            // More natural snapping logic
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
                        
                    case .messages:
                        VStack(spacing: 0) {
                            PageToolbar(toggleSidebar: {}) {
                                Text("Messages").font(.headline)
                            }
                            DMScrollView(currentChannel: $currentChannel, toggleSidebar: {})
                        }
                        
                    case .notifications:
                        NotificationView()
                        
                    case .profile:
                        YouView(currentSelection: $currentSelection, currentChannel: $currentChannel)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    GlobalVoiceBanner(currentChannel: $currentChannel, offset: $offset)
                        .padding(.top, 4) // Top padding to avoid Dynamic Island (SafeArea handles the rest usually, but we can tweak if needed)
                }

                // Tab bar: only hide when inside an active chat channel AND sidebar is closed
                if !isChatOpen { BottomBar() }
                }
                .ignoresSafeArea(.keyboard)
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
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewState.selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        tabIcon(for: tab)
                            .font(.system(size: tab == viewState.selectedTab ? 24 : 20, weight: .bold))
                            .foregroundStyle(viewState.selectedTab == tab ? viewState.theme.accent.color : .gray.opacity(0.7))
                            .scaleEffect(tab == viewState.selectedTab ? 1.1 : 1.0)
                        
                        Text(tabName(for: tab))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(viewState.selectedTab == tab ? viewState.theme.accent.color : .gray.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 12)
        .padding(.bottom, 12) // Balanced padding
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6) // Restored marginal padding so rounded borders aren't clipped by Safe Area
    }
    
    @ViewBuilder
    func tabIcon(for tab: MainTab) -> some View {
        switch tab {
        case .servers:
            Image(systemName: "circle.grid.2x2.fill")
        case .messages:
            Image(systemName: "bubble.left.and.bubble.right.fill")
        case .notifications:
            Image(systemName: "bell.fill")
        case .profile:
            if let user = viewState.currentUser {
                AppAvatar(user: user, width: 24, height: 24)
            } else {
                Image(systemName: "person.fill")
            }
        }
    }
    
    func tabName(for tab: MainTab) -> String {
        switch tab {
        case .servers: return "Servers"
        case .messages: return "Messages"
        case .notifications: return "Notifications"
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
        colors: [Color(hex: "9D4EDD"), Color(hex: "C77DFF")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        let isDarkTheme = !Theme.isLightOrDark(viewState.theme.background)
        ZStack(alignment: .top) {
            backgroundColor.ignoresSafeArea()
            
            // Subtle gradient for background
            LinearGradient(colors: [backgroundColor, isDarkTheme ? Color.black.opacity(0.3) : .white.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    let user = viewState.currentUser!
                    
                    // Top Section: Banner + AppAvatar + Badges + Info
                    VStack(spacing: 0) {
                        // Banner Area with Settings Button
                        ZStack(alignment: .topTrailing) {
                            if let profile = viewState.profiles[user.id], let banner = profile.background {
                                LazyImage(source: .file(banner), height: 140, clipTo: Rectangle())
                            } else {
                                // Default clean gradient banner
                                bannerGradient
                                    .frame(height: 140)
                            }
                            
                            // Settings Button
                            Button {
                                viewState.path.append(NavigationDestination.settings)
                            } label: {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(isDarkTheme ? .white : .black.opacity(0.6))
                                    .padding(10)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                            .padding(.top, 16)
                            .padding(.trailing, 16)
                        }
                        
                        // AppAvatar and Badges
                        HStack(alignment: .bottom) {
                            AppAvatar(user: user, width: 76, height: 76, withPresence: true)
                                .offset(y: -24)
                                .padding(.leading, 20)
                            
                            Spacer()
                            
                            // Badges Capsule
                            if let badges = user.badges, badges > 0 {
                                HStack(spacing: 8) {
                                    UserBadgeView(badges: badges)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.2))
                                .clipShape(Capsule())
                                .offset(y: -12)
                                .padding(.trailing, 20)
                            }
                        }
                        
                        // Name and Status
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.username)
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .foregroundStyle(isDarkTheme ? .white : .black)
                            
                            Text(user.display_name ?? user.username)
                                .font(.system(size: 16))
                                .foregroundStyle(isDarkTheme ? .white.opacity(0.6) : .black.opacity(0.4))
                            
                            HStack(spacing: 8) {
                                if let status = user.status?.text {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(.purple)
                                    Text(status)
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundStyle(isDarkTheme ? .white.opacity(0.9) : .black.opacity(0.7))
                                    Spacer()
                                    Button {
                                        // Clear status logic?
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(isDarkTheme ? .white.opacity(0.3) : .black.opacity(0.3))
                                    }
                                } else {
                                    Text("No status set")
                                        .italic()
                                        .foregroundStyle(isDarkTheme ? .white.opacity(0.5) : .black.opacity(0.3))
                                }
                            }
                            .padding(.top, 16)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                        
                        // Action Buttons
                        HStack(spacing: 12) {
                            Button {
                                showStatusEditor = true
                            } label: {
                                Label("Edit Status", systemImage: "bubble.left.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.purple)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                            
                            Button {
                                viewState.path.append(NavigationDestination.profile_settings)
                            } label: {
                                Label("Edit Profile", systemImage: "pencil")
                                    .font(.system(size: 15, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.purple)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .background(cardBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .padding(.horizontal, 16)
                    
                    // About Me Section
                    VStack(alignment: .leading, spacing: 14) {
                        Text("About Me")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(isDarkTheme ? .white.opacity(0.5) : .black.opacity(0.5))
                        
                        if let profile = viewState.profiles[user.id], let bio = profile.content {
                            Text(bio)
                                .font(.system(size: 16))
                                .foregroundStyle(isDarkTheme ? .white.opacity(0.9) : .black.opacity(0.8))
                        } else {
                            Text("No bio yet.")
                                .italic()
                                .foregroundStyle(isDarkTheme ? .white.opacity(0.5) : .black.opacity(0.3))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Gangio Member Since")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text(getCreationDate(from: user.id))
                                .font(.system(size: 16))
                                .foregroundStyle(.primary)
                        }
                        .padding(.top, 10)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(cardBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal, 16)
                    
                    // Friends Section
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        withAnimation {
                            viewState.selectedTab = .servers
                            currentSelection = .dms
                            currentChannel = .friends
                        }
                    } label: {
                        HStack {
                            let realFriends = viewState.users.values.filter { $0.relationship == .Friend }
                            
                            Text("Your Friends")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            HStack(spacing: -14) {
                                ForEach(realFriends.prefix(5)) { friend in
                                    AppAvatar(user: friend, width: 34, height: 34)
                                        .overlay(Circle().stroke(cardBackgroundColor, lineWidth: 2))
                                }
                                
                                if realFriends.count > 5 {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 34, height: 34)
                                        .overlay(Circle().stroke(cardBackgroundColor, lineWidth: 2))
                                        .overlay(
                                            Text("+\(realFriends.count - 5)")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(.white)
                                        )
                                }
                            }
                            .padding(.trailing, 8)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.secondary.opacity(0.5))
                        }
                        .padding(24)
                        .background(cardBackgroundColor)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 120) // More space for bottom bar
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
        
        return items.sorted(by: { $0.date > $1.date })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            PageToolbar(toggleSidebar: {}) {
                HStack(spacing: 8) {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(.purple)
                    Text("Activity")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                }
            }
            .background(viewState.theme.background.color)
            
            if notifications.isEmpty {
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(.purple.opacity(0.1))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "bell.and.waves.left.and.right.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.purple.gradient)
                            .symbolEffect(.bounce, options: .repeating)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Quiet for now")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        
                        Text("Mentions, friend requests, and invites\nwill appear here.")
                            .font(.system(size: 15))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(viewState.theme.background.color)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) { // Divider style
                        ForEach(notifications) { item in
                            NotificationRow(item: item)
                                .background(viewState.theme.background2.color)
                        }
                    }
                }
                .background(viewState.theme.background3.color)
            }
        }
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
                Circle().fill(.gray.opacity(0.3)).frame(width: 44, height: 44)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.user?.username ?? "Unknown")
                        .font(.system(size: 16, weight: .bold))
                    
                    Spacer()
                    
                    Text(item.date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                switch item.type {
                case .friendRequest:
                    Text("sent you a friend request")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 8) {
                        Button {
                            Task { await viewState.http.acceptFriendRequest(user: item.user!.id) }
                        } label: {
                            Text("Accept")
                                .font(.caption.bold())
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Color.purple)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        
                        Button {
                            Task { await viewState.http.removeFriend(user: item.user!.id) }
                        } label: {
                            Text("Ignore")
                                .font(.caption.bold())
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.2))
                                .foregroundStyle(.primary)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 4)
                    
                case .mention:
                    Text("mentioned you: \(item.message ?? "")")
                        .font(.subheadline)
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                    
                case .serverInvite:
                    Text("invited you to a server")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(viewState.theme.background2.color)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
                                if let room = viewState.currentVoice {
                                    await room.disconnect()
                                    await MainActor.run {
                                        viewState.currentVoice = nil
                                        viewState.currentVoiceChannel = nil
                                    }
                                }
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

