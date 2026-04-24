//
//  DeveloperSettings.swift
//  Gangio
//
//  Created by Angelo Manca on 2024-07-12.
//

import SwiftUI

struct DeveloperSettings: View {
    @EnvironmentObject var viewState: ViewState
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Debug Actions
                SettingsSectionView(title: "Debug Actions") {
                    Button(action: {
                        Task {
                            await viewState.promptForNotifications()
                        }
                    }) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "bell.badge.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                            Text("Force Remote Notification Upload")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }

                // API Info (read-only)
                SettingsSectionView(title: "API Info") {
                    InfoRow(icon: "server.rack", iconColor: .purple, title: "API URL", value: viewState.http.baseURL)
                    Divider().padding(.leading, 52)
                    InfoRow(icon: "antenna.radiowaves.left.and.right", iconColor: .green, title: "WS", value: viewState.apiInfo?.ws ?? "N/A")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(colorScheme == .dark ? Color(hue: 0.62, saturation: 0.1, brightness: 0.05) : Color(hue: 0.62, saturation: 0.02, brightness: 0.96))
        .toolbarBackground(viewState.theme.topBar, for: .automatic)
        .navigationTitle("Developer")
    }
}
