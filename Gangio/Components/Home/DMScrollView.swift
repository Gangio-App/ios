//
//  DMScrollView.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import SwiftUI
import Types

struct DMScrollView: View {
    @EnvironmentObject var viewState: AppViewState
    @Binding var currentChannel: ChannelSelection
    var toggleSidebar: () -> Void

    @State private var searchText = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                let filteredDMs = viewState.dms.filter { channel in
                    switch channel {
                    case .saved_messages: return false
                    default: return true
                    }
                }
                
                if filteredDMs.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 40))
                            .foregroundStyle(viewState.theme.foreground3.color)
                        
                        Text("No recent conversations")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(viewState.theme.foreground3.color)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    ForEach(filteredDMs) { channel in
                        DMRow(channel: channel, toggleSidebar: toggleSidebar)
                        
                        // Subtle separator
                        Rectangle()
                            .fill(Color.white.opacity(0.04))
                            .frame(height: 0.5)
                            .padding(.leading, 76)
                    }
                }
            }
            .padding(.bottom, 120)
        }
        .background(Color.clear)
    }
}

struct DMRow: View {
    @EnvironmentObject var viewState: AppViewState
    let channel: Channel
    let toggleSidebar: () -> Void
    
    var body: some View {
        let isSelected = viewState.currentChannel.id == channel.id
        
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            toggleSidebar()
            viewState.selectDm(withId: channel.id)
        } label: {
            HStack(spacing: 14) {
                // Avatar with presence
                ChannelIcon(channel: channel, withUserPresence: true, showLabel: false, width: 50, height: 50)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Top row: Name + Time
                    HStack(alignment: .top) {
                        let channelName: String = {
                            switch channel {
                            case .dm_channel(let c):
                                if let currentUserId = viewState.currentUser?.id,
                                   let recipientId = c.recipients.first(where: { $0 != currentUserId }),
                                   let recipient = viewState.users[recipientId] {
                                    return recipient.display_name ?? recipient.username
                                }
                                return "Direct Message"
                            default:
                                return channel.name ?? "Unknown"
                            }
                        }()
                        
                        Text(channelName)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(viewState.theme.foreground.color)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Timestamp
                        if let lastMsgId = channel.last_message_id,
                           let msg = viewState.messages[lastMsgId] {
                            Text(formatMessageTime(id: msg.id))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(viewState.theme.foreground3.color)
                        }
                    }
                    
                    // Bottom row: Message preview + Unread badge
                    HStack(alignment: .center) {
                        // Last message preview
                        if let lastMsgId = channel.last_message_id,
                           let msg = viewState.messages[lastMsgId] {
                            Text(msg.content ?? "")
                                .font(.system(size: 15))
                                .foregroundStyle(viewState.theme.foreground3.color)
                                .lineLimit(1)
                        } else if channel.last_message_id != nil {
                            Text("Tap to view")
                                .font(.system(size: 15))
                                .foregroundStyle(viewState.theme.foreground3.color)
                                .lineLimit(1)
                        } else {
                            Text("No messages yet")
                                .font(.system(size: 15))
                                .italic()
                                .foregroundStyle(viewState.theme.foreground3.color.opacity(0.6))
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        // Unread counter
                        if let unread = viewState.getUnreadCountFor(channel: channel) {
                            UnreadCounter(unread: unread, mentionSize: 22, unreadSize: 10)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? viewState.theme.background3.color.opacity(0.4) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    func formatMessageTime(id: String) -> String {
        // Simple time formatting from ULID timestamp
        // ULID's first 10 chars encode timestamp in Crockford Base32
        let crockford = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
        let chars = id.uppercased().prefix(10)
        var timestamp: UInt64 = 0
        for char in chars {
            if let index = crockford.firstIndex(of: char) {
                timestamp = timestamp * 32 + UInt64(crockford.distance(from: crockford.startIndex, to: index))
            }
        }
        
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd/yy"
            return formatter.string(from: date)
        }
    }
}


#Preview {
    @Previewable @StateObject var viewState = AppViewState.preview()

    DMScrollView(currentChannel: $viewState.currentChannel, toggleSidebar: {})
        .applyPreviewModifiers(withState: viewState)
}
