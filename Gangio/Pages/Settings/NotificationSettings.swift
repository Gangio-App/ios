//
//  NotificationSettings.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import SwiftUI
import Sentry

struct NotificationSettings: View {
    @EnvironmentObject var viewState: AppViewState
    @Environment(\.colorScheme) var colorScheme
    @State var pushNotificationsEnabled = false
    @State var notificationsWhileAppRunningEnabled = false
    @State var showSystemSettingsAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Main Toggle Section
                SettingsSectionView(title: "Notification Permissions") {
                    VStack(spacing: 0) {
                        notificationToggle(
                            title: "Push Notifications",
                            subtitle: "Receive notifications when the app is closed",
                            icon: "bell.badge.fill",
                            color: .red,
                            isOn: $pushNotificationsEnabled
                        ) { enabled in
                            if enabled {
                                Task {
                                    await viewState.promptForNotifications()
                                    // Check again if still disabled (user might have said no)
                                    checkPermissionStatus()
                                }
                            } else {
                                Task {
                                    do {
                                        let _ = try await viewState.http.revokeNotificationToken().get()
                                    } catch {
                                        SentrySDK.capture(error: error as! GangioError)
                                        viewState.userSettingsStore.store.notifications.rejectedRemoteNotifications = false
                                        return
                                    }
                                    viewState.userSettingsStore.store.notifications.rejectedRemoteNotifications = true
                                    viewState.userSettingsStore.store.notifications.wantsNotificationsWhileAppRunning = false
                                    notificationsWhileAppRunningEnabled = false
                                }
                            }
                        }

                        Divider().padding(.leading, 56)

                        notificationToggle(
                            title: "In-App Notifications",
                            subtitle: "Show notifications while using the app",
                            icon: "app.badge.fill",
                            color: .orange,
                            isOn: $notificationsWhileAppRunningEnabled
                        ) { enabled in
                            viewState.userSettingsStore.store.notifications.wantsNotificationsWhileAppRunning = enabled
                        }
                    }
                }

                // Global Preferences Section
                SettingsSectionView(title: "Account Preferences") {
                    VStack(spacing: 0) {
                        NavigationLink {
                            GlobalNotificationPreferenceView()
                        } label: {
                            HStack(spacing: 14) {
                                settingsIcon("message.badge.filled.fill", color: .blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Global Preferences")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                                    Text("DMs, mentions, and server defaults")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.gray.opacity(0.5))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                }

                // Problem Solving Section
                SettingsSectionView(title: "Troubleshooting") {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 14) {
                            settingsIcon("gearshape.fill", color: .gray)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("System Settings")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                                Text("Open device settings to manage alerts")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.gray.opacity(0.5))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
                
                Text("If you're not receiving messages, ensure that background refresh is enabled in system settings.")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(viewState.theme.background.color)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkPermissionStatus()
        }
    }
    
    func checkPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let isAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
                pushNotificationsEnabled = isAuthorized && !viewState.userSettingsStore.store.notifications.rejectedRemoteNotifications
                notificationsWhileAppRunningEnabled = viewState.userSettingsStore.store.notifications.wantsNotificationsWhileAppRunning
            }
        }
    }

    @ViewBuilder
    func notificationToggle(title: String, subtitle: String, icon: String, color: Color, isOn: Binding<Bool>, action: @escaping (Bool) -> Void) -> some View {
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
                .onChange(of: isOn.wrappedValue) { _, enabled in
                    action(enabled)
                }
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

struct GlobalNotificationPreferenceView: View {
    @EnvironmentObject var viewState: AppViewState
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        List {
            Section {
                Toggle("DMs Notification", isOn: .constant(true))
                    .disabled(true)
            } header: {
                Text("Direct Messages")
            } footer: {
                Text("DMs always trigger notifications by default.")
            }
            
            Section {
                Text("Mentions and server notification defaults are managed per server. You can change them by long-pressing a server icon in the sidebar.")
                    .font(.caption)
                    .foregroundStyle(.gray)
            } header: {
                Text("Servers & Mentions")
            }
        }
        .navigationTitle("Preferences")
        .background(viewState.theme.background.color)
    }
}

#Preview {
    NotificationSettings()
}
