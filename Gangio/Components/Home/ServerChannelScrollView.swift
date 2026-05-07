//
//  ServerChannelScrollView.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import SwiftUI
import Types


struct ChannelListItem: View {
    @EnvironmentObject var viewState: AppViewState
    var server: Server
    var channel: Channel
    
    @State var updateVoiceState: Bool = false
    
    var toggleSidebar: () -> ()
    
    @State var inviteSheetUrl: InviteUrl? = nil
    
    func getValues() -> (Bool, UnreadCount?, ThemeColor, ThemeColor) {
        let isSelected = viewState.currentChannel.id == channel.id
        let unread = viewState.getUnreadCountFor(channel: channel)
        
        let notificationValue = viewState.userSettingsStore.cache.notificationSettings.channel[channel.id]
        let isMuted = notificationValue == .muted || notificationValue == NotificationState.none
        
        let foregroundColor: ThemeColor
        
        if isSelected {
            foregroundColor = viewState.theme.foreground
        } else if isMuted {
            foregroundColor = viewState.theme.foreground3
        } else if unread != nil {
            foregroundColor = viewState.theme.foreground
        } else {
            foregroundColor = viewState.theme.foreground3
        }
        
        let backgroundColor = isSelected ? viewState.theme.background : viewState.theme.background2
                
        return (isMuted, unread, backgroundColor, foregroundColor)
    }
    
    var body: some View {
        let (isMuted, unread, _, _) = getValues()
        let isSelected = viewState.currentChannel.id == channel.id
        
        // Determine foreground explicitly for better visibility
        let channelForeground: Color = {
            if isSelected || unread != nil {
                return viewState.theme.foreground.color
            } else if isMuted {
                return viewState.theme.foreground3.color.opacity(0.5)
            } else {
                return viewState.theme.foreground2.color
            }
        }()
        
        Button {
            toggleSidebar()
            viewState.selectChannel(inServer: server.id, withId: channel.id)
        } label: {
            HStack(spacing: 8) {
                // Channel type icon
                channelTypeIcon
                    .font(.system(size: 18))
                    .foregroundStyle(channelForeground)
                    .frame(width: 24)
                
                // Channel name
                Text(channel.getName(viewState))
                    .font(.system(size: 15, weight: isSelected || unread != nil ? .semibold : .regular))
                    .foregroundStyle(channelForeground)
                    .lineLimit(1)
                
                Spacer()
                
                // Unread badge
                if let unread = unread, !isMuted {
                    UnreadCounter(unread: unread, mentionSize: 20, unreadSize: 8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? viewState.theme.background4.color.opacity(0.5)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Voice state participants
            if let channelVoiceState = viewState.voiceStates[channel.id] {
                ForEach(channelVoiceState.values.compactMap({ participant in
                    let user = viewState.users[participant.id]
                    let member = viewState.members[server.id]![participant.id]
                    
                    if let user, let member {
                        return (participant, user, member)
                    } else {
                        Task {
                            if user == nil {
                                viewState.users[participant.id] = try! await viewState.http.fetchUser(user: participant.id).get()
                            }
                            
                            if member == nil {
                                viewState.members[server.id]![participant.id] = try! await viewState.http.fetchMember(server: server.id, member: participant.id).get()
                            }
                            
                            updateVoiceState.toggle()
                        }
                        
                        return nil
                    }
                }), id: \.0.id) { args in
                    let (participant, user, member) = args
                    
                    Button {
                        viewState.openUserSheet(user: user, member: member)
                    } label: {
                        HStack(spacing: 8) {
                            AppAvatar(user: user, width: 16, height: 16)
                            Text(verbatim: user.display_name ?? user.username)
                                .font(.caption)
                                .foregroundStyle(Color(hex: "B9BBBE"))
                            
                            Spacer()
                            
                            if participant.camera {
                                Image(systemName: "camera.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 14, height: 14)
                                    .foregroundStyle(Color(hex: "B9BBBE"))
                            }
                            
                            if participant.screensharing {
                                Image(systemName: "desktopcomputer")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 14, height: 14)
                                    .foregroundStyle(Color(hex: "B9BBBE"))
                            }
                            
                            if !(member.can_receive ?? true) {
                                Image(systemName: "mic.slash.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 14, height: 14)
                                    .foregroundStyle(.red)
                                
                            } else if !participant.is_publishing {
                                Image(systemName: "mic.slash.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 14, height: 14)
                                    .foregroundStyle(Color(hex: "72767D"))
                            }
                            
                            if !(member.can_receive ?? true) {
                                Image("headphones.slash")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 14, height: 14)
                                    .foregroundStyle(.red)
                                
                            } else if !participant.is_receiving {
                                Image("headphones.slash")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 14, height: 14)
                                    .foregroundStyle(Color(hex: "72767D"))
                            }
                        }
                    }
                }
                .padding(.leading, 40)
            }
        }
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 6))
        .contextMenu {
            Button("Mark as read") {
                Task {
                    if let last_message = viewState.channelMessages[channel.id]?.last {
                        let _ = try! await viewState.http.ackMessage(channel: channel.id, message: last_message).get()
                    }
                }
            }
            
            Button("Notification options") {
                viewState.path.append(NavigationDestination.channel_info(channel.id))
            }
            
            Button("Create Invite") {
                Task {
                    let res = await viewState.http.createInvite(channel: channel.id)
                    
                    if case .success(let invite) = res {
                        inviteSheetUrl = InviteUrl(url: URL(string: "https://rvlt.gg/\(invite.id)")!)
                    }
                }
            }
        }
        .sheet(item: $inviteSheetUrl) { url in
            ShareInviteSheet(channel: channel, url: url.url)
        }
    }
    
    @ViewBuilder
    var channelTypeIcon: some View {
        switch channel {
        case .text_channel(let tc):
            if tc.voice != nil {
                Image(systemName: "speaker.wave.2")
            } else {
                Image(systemName: "number")
            }
        case .voice_channel:
            Image(systemName: "speaker.wave.2")
        default:
            Image(systemName: "number")
        }
    }
}

struct CategoryListItem: View {
    @EnvironmentObject var viewState: AppViewState
    
    var server: Server
    var category: Types.Category
    var selectedChannel: String?
    
    var toggleSidebar: () -> ()

    var body: some View {
        let isClosed = viewState.userSettingsStore.store.closedCategories[server.id]?.contains(category.id) ?? false
        
        VStack(alignment: .leading, spacing: 2) {
            // Category header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isClosed {
                        viewState.userSettingsStore.store.closedCategories[server.id]?.remove(category.id)
                    } else {
                        viewState.userSettingsStore.store.closedCategories[server.id, default: Set()].insert(category.id)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .resizable()
                        .rotationEffect(Angle(degrees: isClosed ? 0 : 90))
                        .scaledToFit()
                        .frame(width: 8, height: 8)
                        .foregroundStyle(viewState.theme.foreground3.color)
                    
                    Text(category.title.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(viewState.theme.foreground3.color)
                        .tracking(0.5)
                    
                    Spacer()
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 10)
            }
            
            if !isClosed {
                ForEach(category.channels.compactMap({ viewState.channels[$0] }), id: \.id) { channel in
                    ChannelListItem(server: server, channel: channel, toggleSidebar: toggleSidebar)
                }
            }
        }
    }
}

struct ServerChannelScrollView: View {
    @EnvironmentObject var viewState: AppViewState
    @Binding var currentSelection: MainSelection
    @Binding var currentChannel: ChannelSelection
    var toggleSidebar: () -> ()
    
    @State var showServerSheet: Bool = false
    
    private var canOpenServerSettings: Bool {
        if let user = viewState.currentUser, let member = viewState.openServerMember, let server = viewState.openServer {
            let perms = resolveServerPermissions(user: user, member: member, server: server)
            
            return !perms.intersection([.manageChannel, .manageServer, .managePermissions, .manageRole, .manageCustomisation, .kickMembers, .banMembers, .timeoutMembers, .assignRoles, .manageNickname, .manageMessages, .manageWebhooks, .muteMembers, .deafenMembers, .moveMembers]).isEmpty
        } else {
            return false
        }
    }
    
    var body: some View {
        let maybeSelectedServer: Server? = switch currentSelection {
            case .server(let serverId): viewState.servers[serverId]
            default: nil
        }

        if let server = maybeSelectedServer {
            let categoryChannels = server.categories?.flatMap(\.channels) ?? []
            let nonCategoryChannels = server.channels.filter({ !categoryChannels.contains($0) })
            
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    // Server Banner Card
                    Button {
                        showServerSheet = true
                    } label: {
                        ZStack(alignment: .top) {
                            // Banner image
                            if let banner = server.banner {
                                LazyImage(source: .file(banner), height: 140, clipTo: Rectangle())
                                    .frame(maxWidth: .infinity)
                            } else {
                                LinearGradient(
                                    colors: [viewState.theme.accent.color, viewState.theme.accent.color.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .frame(height: 140)
                            }
                            
                            // Top subtle shadow gradient for text readability
                            LinearGradient(
                                colors: [.black.opacity(0.6), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 64)
                            
                            // Top overlay: name (top-left) + 3-dot (top-right)
                            HStack(alignment: .top, spacing: 6) {
                                // Server badge/icon
                                ServerBadges(value: server.flags)
                                
                                // Server name
                                Text(server.name)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white) // White text for overlay
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                // 3-dot menu
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.bottom, 16)
                    
                    // Non-category channels
                    ForEach(nonCategoryChannels.compactMap({ viewState.channels[$0] })) { channel in
                        ChannelListItem(server: server, channel: channel, toggleSidebar: toggleSidebar)
                    }
                    
                    // Categories
                    ForEach(server.categories ?? []) { category in
                        CategoryListItem(server: server, category: category, toggleSidebar: toggleSidebar)
                    }
                    
                    // Buffer to prevent BottomBar overlap
                    Spacer()
                        .frame(height: 120)
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
            }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .background(Color.clear)
            .sheet(isPresented: $showServerSheet) {
                ServerInfoSheet(server: server)
                    .presentationBackground(viewState.theme.background)
            }
        } else {
            Text("How did you get here?")
        }
    }
}

#Preview {
    let state = AppViewState.preview()
    return ServerChannelScrollView(currentSelection: .constant(MainSelection.server("0")), currentChannel: .constant(ChannelSelection.channel("2")), toggleSidebar: {})
        .applyPreviewModifiers(withState: state)
}
