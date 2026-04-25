//
//  Settings.swift
//  Gangio
//
//  Created by Angelo on 18/10/2023.
//

import Foundation
import SwiftUI
import Types
import Alamofire
import AVKit

enum CurrentSettingsPage: Hashable {
    case profile
    case sessions
    case appearance
    case language
    case about
}

struct LazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    var body: Content {
        build()
    }
}

struct Settings: View {
    @EnvironmentObject var viewState: AppViewState
    @Environment(\.colorScheme) var colorScheme

    @State var presentLogoutDialog = false
    @State var isLoggingOut = false
    @State var showStatusEditor = false
    @State var statusText: String = ""
    @State var selectedPresence: Presence = .Online
    @State var profile: Types.Profile? = nil

    private var backgroundColor: Color {
        viewState.theme.background.color
    }
    
    private var cardBackgroundColor: Color {
        viewState.theme.background2.color
    }

    var body: some View {
        let isDark = !Theme.isLightOrDark(viewState.theme.background)

        ScrollView {
            VStack(spacing: 20) {

                    // ── Profile Card ──────────────────────────────────────────
                    if let user = viewState.currentUser {
                        NavigationLink(destination: LazyView(ProfileSettings())) {
                            HStack(spacing: 14) {
                                AppAvatar(user: user, width: 54, height: 54, withPresence: true)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(user.display_name ?? user.username)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(isDark ? .white : .black)

                                    Text(user.status?.text?.isEmpty == false
                                         ? user.status!.text!
                                         : "\(user.username)#\(user.discriminator)")
                                        .font(.system(size: 13))
                                        .foregroundStyle(isDark ? .white.opacity(0.55) : .black.opacity(0.45))
                                        .lineLimit(1)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary.opacity(0.5))
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(cardBackgroundColor)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }

                    // ── Account ───────────────────────────────────────────────
                    settingsGroup(isDark: isDark, header: "Account", items: [
                        AnyView(NavigationLink(destination: LazyView(UserSettings())) {
                            settingsRowContent(icon: "person.badge.key.fill", label: "My Account", color: .blue, isDark: isDark)
                        }),
                        AnyView(NavigationLink(destination: LazyView(ProfileSettings())) {
                            settingsRowContent(icon: "paintpalette.fill", label: "Edit Profile", color: .green, isDark: isDark)
                        }),
                        AnyView(NavigationLink(destination: LazyView(SessionsSettings())) {
                            settingsRowContent(icon: "lock.shield.fill", label: "Sessions", color: .purple, isDark: isDark)
                        }),
                    ])

                    // ── Preferences ───────────────────────────────────────────
                    settingsGroup(isDark: isDark, header: "Preferences", items: [
                        AnyView(NavigationLink(destination: LazyView(AppearanceSettings())) {
                            settingsRowContent(icon: "sparkles", label: "Appearance", color: .orange, isDark: isDark)
                        }),
                        AnyView(NavigationLink(destination: LazyView(NotificationSettings())) {
                            settingsRowContent(icon: "bell.badge.fill", label: "Notifications", color: .red, isDark: isDark)
                        }),
                        AnyView(NavigationLink(destination: LazyView(LanguageSettings())) {
                            settingsRowContent(icon: "character.bubble.fill", label: "Language", color: .teal, isDark: isDark)
                        }),
                        AnyView(NavigationLink(destination: LazyView(AudioSettingsView())) {
                            settingsRowContent(icon: "speaker.wave.3.fill", label: "Voice & Audio", color: .purple, isDark: isDark)
                        }),
                    ])

                    // ── Advanced ──────────────────────────────────────────────
                    settingsGroup(isDark: isDark, header: "Advanced", items: [
                        AnyView(NavigationLink(destination: LazyView(BotSettings())) {
                            settingsRowContent(icon: "cpu.fill", label: "Bots", color: .indigo, isDark: isDark)
                        }),
                        AnyView(NavigationLink(destination: LazyView(ExperimentsSettings())) {
                            settingsRowContent(icon: "testtube.2", label: "Experiments", color: .mint, isDark: isDark)
                        }),
                    ])

                    // ── Support ───────────────────────────────────────────────
                    settingsGroup(isDark: isDark, header: "Support", items: [
                        AnyView(NavigationLink(destination: LazyView(About())) {
                            settingsRowContent(icon: "info.circle.fill", label: "About Gangio", color: .gray, isDark: isDark)
                        }),
                    ])

                    // ── Log Out ───────────────────────────────────────────────
                    Button(action: { presentLogoutDialog = true }) {
                        HStack {
                            Spacer()
                            if isLoggingOut {
                                ProgressView()
                            } else {
                                Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.red)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 15)
                        .background(cardBackgroundColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(isLoggingOut)
                    .padding(.horizontal, 16)

                    // Footer
                    Text("Gangio iOS • Premium Edition")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .padding(.bottom, 32)
                }
            }
            .background(backgroundColor.ignoresSafeArea())
            .environment(\.colorScheme, isDark ? .dark : .light)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                if let status = viewState.currentUser?.status {
                    statusText = status.text ?? ""
                    selectedPresence = status.presence ?? .Online
                }
            }
            .alert("Log Out", isPresented: $presentLogoutDialog) {
                Button("Cancel", role: .cancel) {}
                Button("Log Out", role: .destructive) {
                    isLoggingOut = true
                    Task {
                        let _ = await viewState.signOut()
                        await MainActor.run { isLoggingOut = false }
                    }
                }
            } message: {
                Text("Are you sure you want to log out?")
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
                if let userId = viewState.currentUser?.id {
                    profile = try? await viewState.http.fetchProfile(user: userId).get()
                }
            }
        }

    func presenceColor(_ presence: Presence) -> Color {
        switch presence {
        case .Online: return .green
        case .Idle: return .yellow
        case .Focus: return .blue
        case .Busy: return .red
        case .Invisible: return .gray
        @unknown default: return .gray
        }
    }

    // MARK: - Card group builder
    @ViewBuilder
    func settingsGroup(isDark: Bool, header: String, items: [AnyView]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(header.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    item
                    if index < items.count - 1 {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .background(cardBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    func settingsRowContent(icon: String, label: String, color: Color, isDark: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 7))

            Text(label)
                .font(.system(size: 16))
                .foregroundStyle(isDark ? .white : .black)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// MARK: - Audio Settings View
public struct AudioSettingsView: View {
    @EnvironmentObject var viewState: AppViewState
    @Environment(\.colorScheme) var colorScheme
    
    @State private var availableInputs: [AVAudioSessionPortDescription] = []
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Section: Volume
                SettingsSectionView(title: "Audio Levels") {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Master Volume")
                                    .font(.system(size: 16, weight: .medium))
                                Spacer()
                                Text("\(Int(viewState.masterVolume * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                            
                            Slider(value: $viewState.masterVolume, in: 0...1)
                                .tint(viewState.theme.accent.color)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                
                // Section: Sound Effects
                SettingsSectionView(title: "Sound Effects") {
                    VStack(spacing: 0) {
                        soundToggle(
                            title: "Message Sent",
                            subtitle: "Play a sound when you send a message",
                            icon: "paperplane.fill",
                            color: .blue,
                            isOn: $viewState.messageSentSoundEnabled
                        )
                        
                        Divider().padding(.leading, 56)
                        
                        soundToggle(
                            title: "Message Received",
                            subtitle: "Play a sound when you receive a message",
                            icon: "bubble.left.fill",
                            color: .green,
                            isOn: $viewState.messageReceivedSoundEnabled
                        )
                    }
                }
                
                // Section: Voice Input
                SettingsSectionView(title: "Voice Input") {
                    VStack(alignment: .leading, spacing: 0) {
                        if availableInputs.isEmpty {
                            Text("No input devices found")
                                .font(.caption)
                                .foregroundStyle(.gray)
                                .padding(16)
                        } else {
                            ForEach(availableInputs, id: \.uid) { port in
                                Button {
                                    viewState.preferredInputDeviceId = port.uid
                                    try? AVAudioSession.sharedInstance().setPreferredInput(port)
                                } label: {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.purple.opacity(0.1))
                                                .frame(width: 32, height: 32)
                                            Image(systemName: "mic.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(.purple)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(port.portName)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                                            Text(port.portType.rawValue)
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                        }
                                        
                                        Spacer()
                                        
                                        if viewState.preferredInputDeviceId == port.uid || (viewState.preferredInputDeviceId == nil && port == AVAudioSession.sharedInstance().preferredInput) {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(viewState.theme.accent.color)
                                                .font(.system(size: 14, weight: .bold))
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                
                                if port != availableInputs.last {
                                    Divider().padding(.leading, 56)
                                }
                            }
                        }
                    }
                }
                
                // Section: Voice Output
                SettingsSectionView(title: "Voice Output") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Output routing is managed by the system. Use the button below to change the current output device.")
                            .font(.caption)
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 16)
                        
                        Button {
                            // On iOS, we show the AVRoutePicker or similar
                        } label: {
                            HStack {
                                settingsIcon("speaker.wave.2.fill", color: .gray)
                                Text("System Audio Routing")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.gray)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(viewState.theme.background.color)
        .navigationTitle("Voice & Audio")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshDevices()
        }
    }
    
    func refreshDevices() {
        let session = AVAudioSession.sharedInstance()
        availableInputs = session.availableInputs ?? []
    }
    
    @ViewBuilder
    func soundToggle(title: String, subtitle: String, icon: String, color: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            settingsIcon(icon, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                Text(LocalizedStringKey(subtitle))
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(viewState.theme.accent.color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    func settingsIcon(_ name: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color.opacity(0.15))
                .frame(width: 32, height: 32)
            Image(systemName: name)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)
        }
    }
}

// MARK: - Status Editor Sheet
struct StatusEditorSheet: View {
    @EnvironmentObject var viewState: AppViewState
    @Environment(\.colorScheme) var colorScheme
    @Binding var statusText: String
    @Binding var selectedPresence: Presence
    @Binding var showSheet: Bool
    @State var isSaving = false

    let presenceOptions: [(Presence, String, Color, String)] = [
        (.Online, "Online", .green, "circle.fill"),
        (.Idle, "Idle", .yellow, "moon.fill"),
        (.Focus, "Focus", .blue, "eye.fill"),
        (.Busy, "Do Not Disturb", .red, "minus.circle.fill"),
        (.Invisible, "Invisible", .gray, "eye.slash.fill"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Status Presence Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PRESENCE")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)
                        
                        VStack(spacing: 0) {
                            ForEach(Array(presenceOptions.enumerated()), id: \.element.0) { index, option in
                                Button(action: { selectedPresence = option.0 }) {
                                    HStack(spacing: 14) {
                                        Image(systemName: option.3)
                                            .foregroundColor(option.2)
                                            .frame(width: 20)
                                        Text(option.1)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if selectedPresence == option.0 {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.purple)
                                                .font(.system(size: 14, weight: .bold))
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(colorScheme == .dark ? Color(white: 0.1) : .white)
                                }
                                
                                if index != presenceOptions.count - 1 {
                                    Divider().padding(.leading, 50)
                                }
                            }
                        }
                        .background(colorScheme == .dark ? Color(white: 0.1) : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)
                    }

                    // Status Message Text Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("STATUS MESSAGE")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)
                        
                        HStack {
                            TextField("What's on your mind?", text: $statusText)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(colorScheme == .dark ? Color(white: 0.1) : .white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(.horizontal, 16)
                    }

                    // Save Button
                    Button(action: saveStatus) {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text("Save Status")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)
                        .opacity(isSaving ? 0.7 : 1)
                    }
                    .disabled(isSaving)
                }
                .padding(.vertical, 24)
            }
            .background(colorScheme == .dark ? Color.black : Color(white: 0.95))
            .scrollContentBackground(.hidden)
            .navigationTitle("Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showSheet = false }
                        .foregroundStyle(.purple)
                }
            }
        }
    }

    func saveStatus() {
        isSaving = true
        Task {
            let statusPayload: [String: Any] = [
                "status": [
                    "text": statusText.isEmpty ? nil : statusText,
                    "presence": selectedPresence.rawValue
                ] as [String : Any?]
            ]

            // Use raw request since the payload is complex
            if let jsonData = try? JSONSerialization.data(withJSONObject: statusPayload) {
                var headers = Alamofire.HTTPHeaders()
                if let token = viewState.http.token {
                    headers.add(name: "x-session-token", value: token)
                }
                headers.add(name: "Content-Type", value: "application/json")

                let _ = await viewState.http.session.request(
                    "\(viewState.http.baseURL)/users/@me",
                    method: .patch,
                    headers: headers
                ) { $0.httpBody = jsonData }
                .serializingString()
                .response

                await viewState.userSettingsStore.fetchFromApi()
            }
            
            await MainActor.run {
                isSaving = false
                showSheet = false
            }
        }
    }
}



// MARK: - Settings Row
struct SettingsRow<Destination: View>: View {
    @Environment(\.colorScheme) var colorScheme
    let icon: String
    let iconColor: Color
    let title: String
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(iconColor.gradient.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(iconColor)
                        .shadow(color: iconColor.opacity(0.3), radius: 4)
                }

                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : .black.opacity(0.8))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gray.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}


#Preview {
    Settings()
        .applyPreviewModifiers(withState: AppViewState.preview())
}
