//
//  BotSettings.swift
//  Gangio
//
//  Created by Angelo on 03/10/2024.
//

import Foundation
import SwiftUI
import Types

struct BotSettings: View {
    @EnvironmentObject var viewState: ViewState
    @Environment(\.colorScheme) var colorScheme
    
    @State var bots: [(Bot, User)] = []
    @State var showCreateBotAlert: Bool = false
    @State var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Create Bot Button
                Button(action: { showCreateBotAlert.toggle() }) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Create a Bot")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.indigo)
                    )
                    .shadow(color: Color.indigo.opacity(0.3), radius: 8, x: 0, y: 4)
                }

                // Info Notice
                HStack(spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("By creating a bot, you agree to the [Community Guidelines](https://gangio.chat/legal/community-guidelines).")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .padding(12)
                .background(colorScheme == .dark ? Color(white: 0.1) : Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)

                // My Bots
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading bots...")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else if bots.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "desktopcomputer")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.4))
                        Text("No bots yet")
                            .font(.headline)
                            .foregroundStyle(.gray)
                        Text("Create your first bot to get started")
                            .font(.caption)
                            .foregroundStyle(.gray.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    SettingsSectionView(title: "My Bots (\(bots.count))") {
                        ForEach(Array(bots.enumerated()), id: \.element.0.id) { index, botPair in
                            let (bot, user) = botPair
                            if index > 0 {
                                Divider().padding(.leading, 52)
                            }
                            NavigationLink {
                                BotSetting(bot: bot, user: user)
                            } label: {
                                HStack(spacing: 14) {
                                    Avatar(user: user)
                                        .frame(width: 40, height: 40)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(verbatim: user.display_name ?? user.username)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                            
                                            Text("BOT")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.indigo)
                                                .cornerRadius(4)
                                        }
                                        
                                        HStack(spacing: 4) {
                                            Image(systemName: bot.isPublic ? "globe" : "lock.fill")
                                                .font(.system(size: 10))
                                            Text(bot.isPublic ? "Public" : "Private")
                                                .font(.caption)
                                        }
                                        .foregroundStyle(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.gray.opacity(0.5))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .task {
            if let response = try? await viewState.http.fetchBots().get() {
                bots = response.bots
                    .compactMap { bot in
                        response.users
                            .first(where: { $0.id == bot.id })
                            .map { (bot, $0) }
                    }
            }
            isLoading = false
        }
        .background(colorScheme == .dark ? Color(hue: 0.62, saturation: 0.1, brightness: 0.05) : Color(hue: 0.62, saturation: 0.02, brightness: 0.96))
        .navigationTitle("Bots")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(colorScheme == .dark ? Color(hue: 0.62, saturation: 0.1, brightness: 0.05) : Color(hue: 0.62, saturation: 0.02, brightness: 0.96), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert("Create Bot", isPresented: $showCreateBotAlert) {
            CreateBotAlert(bots: $bots)
        }
    }
}


struct CreateBotAlert: View {
    @EnvironmentObject var viewState: ViewState
    
    @Binding var bots: [(Bot, User)]
    @State var name: String = ""
    
    var body: some View {
        TextField("Username", text: $name)
        
        Button("Create") {
            Task {
                if let bot = try? await viewState.http.createBot(username: name).get() {
                    bots.append((bot, bot.user!))
                }
            }
        }
        
        Button("Cancel", role: .cancel) {}
    }
}
