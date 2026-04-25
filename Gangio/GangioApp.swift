import SwiftUI
import Sentry
import Types

let DEFAULT_API_URL: String = "https://gangio.pro/api"

@main
struct GangioApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    
    @Environment(\.locale) var systemLocale: Locale
    @StateObject var state = AppViewState.shared ?? AppViewState()

    init() {
        if !isPreview {
            SentrySDK.start { options in
                options.dsn = "https://4049414032e74d9098a44e67779aa648@sentry.gangio.chat/7"
                options.tracesSampleRate = 1.0
                options.profilesSampleRate = 1.0
                options.attachViewHierarchy = true
                options.enableAppLaunchProfiling = true
//                options.enableMetrics = true
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ApplicationSwitcher()
                .environmentObject(state)
                .tint(state.theme.accent.color)
                .background(state.theme.background.color)
                .foregroundStyle(state.theme.foreground.color)
                .environment(\.locale, state.currentLocale ?? systemLocale)
                .preferredColorScheme(state.theme.shouldFollowiOSTheme ? nil : (Theme.isLightOrDark(state.theme.background) ? .light : .dark))
                .onOpenURL { url in
                    print(url)
                    let components = NSURLComponents(string: url.absoluteString)
                    switch url.scheme {
                        case "http", "https":
                                switch url.pathComponents[safe: 1] {
                                    case "app", "login":
                                        state.currentSelection = .dms
                                        state.currentChannel = .home
                                    default:
                                        ()
                                }
                        case "gangiochat":
                            var queryItems: [String: String] = [:]

                            for item in components?.queryItems ?? [] {
                                queryItems[item.name] = item.value?.removingPercentEncoding
                            }
                            switch url.host() {
                                case "users":
                                    if let id = queryItems["user"] {
                                        state.openUserSheet(withId: id, server: queryItems["server"])
                                    }
                                case "channels":
                                    if let id = queryItems["channel"] {
                                        if let channel = state.channels[id] {
                                            if let server = channel.server {
                                                state.currentSelection = .server(server)
                                            } else {
                                                state.currentSelection = .dms
                                            }

                                            state.currentChannel = .channel(id)
                                        }
                                    }
                                default:
                                    ()
                            }
                        default:
                            ()
                    }
                }
        }
    }
}

struct ApplicationSwitcher: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var viewState: AppViewState
    @State var wasSignedOut = false
    @State var banner: WsState? = nil
    /// Track whether initial connection has completed (don't show banner on first connect)
    @State var hasInitiallyConnected = false
    
    var body: some View {
        if viewState.state != .signedOut && !viewState.isOnboarding {
            InnerApp()
                .transition(.slide)
                .task {
                    await viewState.backgroundWsTask()
                    // Don't reset state to connecting if we already have cached data showing
                    if viewState.state != .signedOut && !viewState.forceMainScreen {
                        withAnimation {
                            viewState.state = .connecting
                        }
                    }
                }
                .overlay(alignment: .top) {
                    if let banner = banner {
                        connectionBanner(banner)
                            .padding(.top, 54)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .zIndex(100)
                            .animation(.spring(response: 0.45, dampingFraction: 0.75), value: banner)
                    }
                }
                .onChange(of: colorScheme) { before, after in
                    // automatically switch the color scheme if the user pressed "auto" in the preferences menu
                    if viewState.theme.shouldFollowiOSTheme {
                        withAnimation {
                            _ = viewState.applySystemScheme(theme: after, followSystem: true)
                        }
                    }
                }
                .onChange(of: viewState.ws?.currentState, { before, after in
                    if case .connected = after {
                        if hasInitiallyConnected {
                            // Only show "Connected" banner on REconnection, not initial
                            banner = .connected
                            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                                withAnimation {
                                    banner = nil
                                }
                            }
                        } else {
                            // First connection — just silently dismiss any banner
                            hasInitiallyConnected = true
                            withAnimation {
                                banner = nil
                            }
                        }
                    } else if before != nil && hasInitiallyConnected {
                        // Only show reconnecting/disconnected after initial connection
                        banner = after
                    }
                })
        } else {
            Welcome(wasSignedOut: $wasSignedOut)
                .transition(.slideNext)
                .onAppear {
                    if viewState.state == .signedOut && viewState.sessionToken != nil { // signging out
                        viewState.sessionToken = nil
                        viewState.destroyCache()
                        withAnimation {
                            wasSignedOut = true
                        }
                    }
                }
        }
    }

    @ViewBuilder
    func connectionBanner(_ state: WsState) -> some View {
        let config: (icon: String, label: String, color: Color, spinning: Bool) = {
            switch state {
            case .disconnected: return ("wifi.slash", "No connection — tap to retry", Color.red, false)
            case .connecting:   return ("arrow.clockwise", "Reconnecting…", Color.orange, true)
            case .connected:    return ("checkmark.circle.fill", "Back online", Color.green, false)
            }
        }()

        Button {
            if case .disconnected = state { viewState.ws?.forceConnect() }
        } label: {
            HStack(spacing: 10) {
                if config.spinning {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: config.icon)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(config.label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(config.color)
                    .shadow(color: config.color.opacity(0.45), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
        .allowsHitTesting(state == .disconnected)
    }
}

struct InnerApp: View {
    @EnvironmentObject var viewState: AppViewState

    var body: some View {
        NavigationStack(path: $viewState.path) {
            if viewState.forceMainScreen {
                MainApp()
            } else {
                switch viewState.state {
                    case .signedOut:
                        Text("Signed out... How did you get here?")
                    case .connecting:
                        VStack {
                            Text("Connecting...")
#if DEBUG
                            Button {
                                viewState.destroyCache()
                                viewState.sessionToken = nil
                                viewState.state = .signedOut
                            } label: {
                                Text("Developer: Nuke everything and force welcome screen")
                            }
#endif
                        }
                    case .connected:
                        MainApp()
                }
            }
        }
        .overlay(alignment: .top) {
            if let voiceId = viewState.currentVoiceChannel, let channel = viewState.channels[voiceId], viewState.currentVoice != nil {
                Button {
                    viewState.path = NavigationPath()
                    if let server = channel.server {
                        viewState.currentSelection = .server(server)
                    } else {
                        viewState.currentSelection = .dms
                    }
                    viewState.currentChannel = .channel(voiceId)
                } label: {
                    HStack {
                        Image(systemName: "phone.fill")
                        Text("Connected to \(channel.getName(viewState))")
                            .font(.system(size: 14, weight: .bold))
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.green))
                    .foregroundColor(.white)
                    .shadow(radius: 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 48)
            }
        }
    }
}

struct MainApp: View {
    @EnvironmentObject var viewState: AppViewState
    #if !DEBUG
    @State var alphaAlert = true
    #else
    @State var alphaAlert = false
    #endif

    var currentServer: Server? {
        if let id = viewState.currentSelection.id {
            return viewState.servers[id]
        }
        return nil
    }
    
    var currentChannel: Channel? {
        if let id = viewState.currentChannel.id {
            return viewState.channels[id]
        }
        return nil
    }
    
    var body: some View {
        Home(
            currentSelection: $viewState.currentSelection,
            currentChannel: $viewState.currentChannel
        )
        .alert("Warning", isPresented: $alphaAlert, actions: {}, message: {
            Text("This app is in very early alpha and is expected to be unfinished and crash in lots of places, if you wish for a stable experience please use the web app for the time being.")
        })
        .navigationDestination(for: NavigationDestination.self) { dest in
            switch dest {
                case .channel_info(let id):
                    let channel = Binding($viewState.channels[id])!
                    ChannelInfo(channel: channel)
                case .channel_settings(let id):
                    let channel = Binding($viewState.channels[id])!
                    let server = channel.wrappedValue.server.map { $viewState.servers[$0] } ?? .constant(nil)
                    
                    ChannelSettings(server: server, channel: channel)
                case .discover:
                    Discovery()
                case .server_settings(let id):
                    let server = Binding($viewState.servers[id])!
                    ServerSettings(server: server)
                case .settings:
                    Settings()
                case .add_friend:
                    AddFriend()
                case .create_group(let initial_users):
                    CreateGroup(selectedUsers: Set(initial_users.compactMap { viewState.users[$0] }))
                case .create_server:
                    CreateServer()
                case .channel_search(let id):
                    let channel = Binding($viewState.channels[id])!
                    ChannelSearch(channel: channel)
                case .invite(let code):
                    ViewInvite(code: code)
                case .channel_pins(let id):
                    let channel = Binding($viewState.channels[id])!
                    ChannelPins(channel: channel)
                case .profile_settings:
                    ProfileSettings()
                case .status_settings:
                    Settings() // For now, status editor is a sheet in Settings, so going to settings is the closest path.
                    // Or I could make a dedicated StatusScreen.

            }
        }
        .environment(\.currentServer, currentServer)
        .environment(\.currentChannel, currentChannel)
        .sheet(item: $viewState.currentUserSheet) { (v) in
            UserSheet(user: v.user, member: v.member)
        }
    }
}

// replace with settings eventually
let TEMP_IS_COMPACT_MODE: (Bool, Bool) = (false, true)

#if targetEnvironment(macCatalyst)
let isIPad = UIDevice.current.userInterfaceIdiom == .pad
let isIPhone = UIDevice.current.userInterfaceIdiom == .phone
let isMac = true
#elseif os(iOS)
let isIPad = UIDevice.current.userInterfaceIdiom == .pad
let isIPhone = UIDevice.current.userInterfaceIdiom == .phone
let isMac = false
#else
let isIPad = false
let isIPhone = false
let isMac = true
#endif


var isPreview: Bool {
#if DEBUG
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
#else
    false
#endif
}

func copyText(text: String) {
#if os(macOS)
    NSPasteboard.general.setString(text, forType: .string)
#else
    UIPasteboard.general.string = text
#endif
    }

func copyUrl(url: URL) {
#if os(macOS)
    NSPasteboard.general.setString(url.absoluteString, forType: .URL)
#else
    UIPasteboard.general.url = url
#endif
}

