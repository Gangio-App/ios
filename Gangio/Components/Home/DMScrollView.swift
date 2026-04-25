//
//  DMScrollView.swift
//  Gangio
//
//  Created by Angelo on 27/11/2023.
//

import Foundation
import SwiftUI
import Types

struct DMScrollView: View {
    @EnvironmentObject var viewState: AppViewState
    @Binding var currentChannel: ChannelSelection
    var toggleSidebar: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Top Utilities
                VStack(spacing: 1) {
                    DMUtilityRow(title: "Home", icon: "house.fill", color: .blue) {
                        toggleSidebar()
                        currentChannel = .home
                    }
                    
                    DMUtilityRow(title: "Friends", icon: "person.2.fill", color: .green) {
                        toggleSidebar()
                        currentChannel = .friends
                    }
                    
                    DMUtilityRow(title: "Saved Messages", icon: "bookmark.fill", color: .orange) {
                        Task {
                            if let user = viewState.currentUser {
                                let channel = try? await viewState.http.openDm(user: user.id).get()
                                if let id = channel?.id {
                                    toggleSidebar()
                                    currentChannel = .channel(id)
                                }
                            }
                        }
                    }
                }
                .background(viewState.theme.background2.color)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                .padding(.top, 12)

                // DM Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("DIRECT MESSAGES")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    
                    VStack(spacing: 1) {
                        let filteredDMs = viewState.dms.filter { channel in
                            switch channel {
                            case .saved_messages: return false
                            default: return true
                            }
                        }
                        
                        if filteredDMs.isEmpty {
                            Text("No recent conversations")
                                .font(.system(size: 14).italic())
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                        } else {
                            ForEach(filteredDMs) { channel in
                                DMRow(channel: channel, toggleSidebar: toggleSidebar)
                            }
                        }
                    }
                    .background(viewState.theme.background2.color)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 100)
        }
        .background(viewState.theme.background.color)
    }
}

struct DMUtilityRow: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

struct DMRow: View {
    @EnvironmentObject var viewState: AppViewState
    let channel: Channel
    let toggleSidebar: () -> Void
    
    var body: some View {
        Button {
            toggleSidebar()
            viewState.selectDm(withId: channel.id)
        } label: {
            HStack(spacing: 12) {
                ChannelIcon(channel: channel, withUserPresence: true, showLabel: false, width: 44, height: 44)
                
                VStack(alignment: .leading, spacing: 2) {
                    let channelName: String = {
                        switch channel {
                        case .dm_channel(let c):
                            if let currentUserId = viewState.currentUser?.id,
                               let recipientId = c.recipients.first(where: { $0 != currentUserId }),
                               let recipient = viewState.users[recipientId] {
                                return recipient.username
                            }
                            return "Direct Message"
                        default:
                            return channel.name ?? "Unknown"
                        }
                    }()
                    
                    Text(channelName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    
                    if channel.last_message_id != nil {
                        // In a real app we'd fetch the preview, for now just show a status
                        Text("Active conversation")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if let unread = viewState.getUnreadCountFor(channel: channel) {
                    UnreadCounter(unread: unread)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}


#Preview {
    @Previewable @StateObject var viewState = AppViewState.preview()

    DMScrollView(currentChannel: $viewState.currentChannel, toggleSidebar: {})
        .applyPreviewModifiers(withState: viewState)
}
