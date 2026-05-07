//
//  Settings.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
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
            VStack(spacing: 28) {
                // Settings Header with Wide Logo
                VStack(spacing: 4) {
                    Image("wide")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 38)
                        .foregroundStyle(viewState.theme.foreground.color)
                    
                    Text("SETTINGS")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(viewState.theme.accent.color)
                        .tracking(3)
                }
                .padding(.top, 24)
                .padding(.bottom, 12)

                // Profile Header Card
                if let user = viewState.currentUser {
                    VStack(spacing: 0) {
                        NavigationLink(value: NavigationDestination.profile_settings) {
                            HStack(spacing: 16) {
                                AppAvatar(user: user, width: 64, height: 64, withPresence: true)
                                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.display_name ?? user.username)
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(viewState.theme.foreground.color)

                                    Text(user.status?.text?.isEmpty == false
                                         ? user.status!.text!
                                         : "@\(user.username)")
                                        .font(.system(size: 14))
                                        .foregroundStyle(viewState.theme.foreground3.color)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(viewState.theme.foreground3.color.opacity(0.5))
                            }
                            .padding(20)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        Divider().padding(.horizontal, 20)
                        
                        // Quick Status Button
                        Button {
                            showStatusEditor = true
                        } label: {
                            HStack {
                                Image(systemName: "face.smiling.fill")
                                    .foregroundStyle(viewState.theme.accent.color)
                                Text("Set Custom Status")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(viewState.theme.foreground2.color)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(cardBackgroundColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(viewState.theme.foreground3.color.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 16)
                }

                // Account Section
                settingsGroup(header: "Account") {
                    VStack(spacing: 0) {
                        SettingsRow(icon: "person.fill", title: "My Account", color: .blue) { UserSettings() }
                        Divider().padding(.leading, 56)
                        SettingsRow(icon: "paintpalette.fill", title: "Profile Appearance", color: .purple) { ProfileSettings() }
                        Divider().padding(.leading, 56)
                        SettingsRow(icon: "lock.shield.fill", title: "Safety & Sessions", color: .green) { SessionsSettings() }
                    }
                }

                // Preferences Section
                settingsGroup(header: "App Settings") {
                    VStack(spacing: 0) {
                        SettingsRow(icon: "sparkles", title: "Appearance", color: .orange) { AppearanceSettings() }
                        Divider().padding(.leading, 56)
                        SettingsRow(icon: "speaker.wave.3.fill", title: "Voice & Audio", color: Color(hex: "5865F2")) { AudioSettingsView() }
                        Divider().padding(.leading, 56)
                        SettingsRow(icon: "bell.badge.fill", title: "Notifications", color: .red) { NotificationSettings() }
                        Divider().padding(.leading, 56)
                        SettingsRow(icon: "character.bubble.fill", title: "Language", color: .teal) { LanguageSettings() }
                    }
                }

                // Advanced Section
                settingsGroup(header: "Advanced") {
                    VStack(spacing: 0) {
                        SettingsRow(icon: "cpu.fill", title: "Developer Tools", color: .indigo) { BotSettings() }
                        Divider().padding(.leading, 56)
                        SettingsRow(icon: "testtube.2", title: "Experimental Features", color: .mint) { ExperimentsSettings() }
                    }
                }

                // Support Section
                settingsGroup(header: "Support") {
                    SettingsRow(icon: "info.circle.fill", title: "About Gangio", color: .gray) { About() }
                }

                // Danger Zone
                VStack(spacing: 12) {
                    Button(action: { presentLogoutDialog = true }) {
                        HStack {
                            if isLoggingOut {
                                ProgressView().tint(.red)
                            } else {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Log Out")
                                    .fontWeight(.bold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.red.opacity(0.1))
                        .foregroundStyle(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.red.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .disabled(isLoggingOut)
                    
                    Text("Gangio v1.0.0 (Premium)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(viewState.theme.foreground3.color)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .background(backgroundColor.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
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
    }

    @ViewBuilder
    func settingsGroup<Content: View>(header: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(header.uppercased())
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(viewState.theme.foreground3.color.opacity(0.7))
                .padding(.leading, 24)

            content()
                .background(cardBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(viewState.theme.foreground3.color.opacity(0.1), lineWidth: 1)
                )
        }
        .padding(.horizontal, 16)
    }
}

struct SettingsRow<Destination: View>: View {
    @EnvironmentObject var viewState: AppViewState
    let icon: String
    let title: String
    let color: Color
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink(destination: LazyView(destination())) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(color)
                }

                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(viewState.theme.foreground.color)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(viewState.theme.foreground3.color.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                                                .fill(viewState.theme.accent.color.opacity(0.1))
                                                .frame(width: 32, height: 32)
                                            Image(systemName: "mic.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(Color(hex: "5865F2"))
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
                                                .foregroundColor(Color(hex: "5865F2"))
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
                        .background(Color(hex: "5865F2"))
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
                        .foregroundStyle(Color(hex: "5865F2"))
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






#Preview {
    Settings()
        .applyPreviewModifiers(withState: AppViewState.preview())
}
