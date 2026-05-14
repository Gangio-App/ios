//
//  ViewInvite.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import SwiftUI

struct ViewInvite: View {
    @EnvironmentObject var viewState: AppViewState
    
    var code: String
    
    @State var info: InviteInfoResponse?? = nil
    @State private var isJoining = false
    @State private var joinError: String? = nil
    
    var body: some View {
        ZStack {
            viewState.theme.background.color.ignoresSafeArea()
            
            switch info {
            case .none:
                LoadingSpinnerView(frameSize: CGSize(width: 32, height: 32), isActionComplete: .constant(false))
            case .some(.none):
                VStack(spacing: 12) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)
                    Text("Invalid or expired invite")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(viewState.theme.foreground.color)
                }
            case .group:
                Text("Group TODO")
            case .server(let serverInfo):
                serverInviteCard(info: serverInfo)
            }
        }
        .toolbarBackground(viewState.theme.topBar, for: .automatic)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Join Invite")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(viewState.theme.foreground.color)
            }
        }
        .task {
            if let info = try? await viewState.http.fetchInvite(code: code).get() {
                self.info = info
            } else {
                self.info = .some(.none)
            }
        }
    }
    
    @ViewBuilder
    private func serverInviteCard(info serverInfo: ServerInfoResponse) -> some View {
        VStack(spacing: 0) {
            // Banner with server icon overlapping the bottom edge.
            ZStack(alignment: .bottom) {
                Group {
                    if let banner = serverInfo.server_banner {
                        LazyImage(source: .file(banner), clipTo: Rectangle())
                            .frame(maxWidth: .infinity)
                    } else {
                        LinearGradient(
                            colors: [viewState.theme.accent.color, viewState.theme.accent.color.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .frame(height: 130)
                .clipped()
                
                // Subtle scrim
                LinearGradient(
                    colors: [.black.opacity(0), .black.opacity(0.35)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 130)
                .allowsHitTesting(false)
                
                // Server icon — half-overlapping the bottom of the banner.
                Group {
                    if let icon = serverInfo.server_icon {
                        LazyImage(source: .file(icon), clipTo: Circle())
                    } else {
                        FallbackServerIcon(name: serverInfo.server_name, clipTo: Circle())
                    }
                }
                .frame(width: 84, height: 84)
                .overlay(
                    Circle()
                        .stroke(viewState.theme.background.color, lineWidth: 4)
                )
                .offset(y: 42)
            }
            .padding(.bottom, 50) // room for the overlapping icon
            
            // Server identity
            VStack(spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    ServerBadges(value: serverInfo.server_flags)
                    Text(verbatim: serverInfo.server_name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(viewState.theme.foreground.color)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                
                HStack(spacing: 8) {
                    Label {
                        Text("#\(serverInfo.channel_name)")
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "number")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(viewState.theme.foreground2.color)
                    
                    Circle()
                        .fill(viewState.theme.foreground3.color)
                        .frame(width: 3, height: 3)
                    
                    HStack(spacing: 4) {
                        Circle().fill(.green).frame(width: 8, height: 8)
                        Text("\(serverInfo.member_count) members")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(viewState.theme.foreground2.color)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Divider()
                .background(viewState.theme.background3.color)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            
            // Inviter
            HStack(spacing: 10) {
                Group {
                    if let avatar = serverInfo.user_avatar {
                        LazyImage(source: .file(avatar), clipTo: Circle())
                    } else {
                        Circle()
                            .fill(viewState.theme.background3.color)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundStyle(viewState.theme.foreground2.color)
                            )
                    }
                }
                .frame(width: 28, height: 28)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("Invited by")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(viewState.theme.foreground3.color)
                    Text(verbatim: serverInfo.user_name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(viewState.theme.foreground.color)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            
            if let error = joinError {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Action button
            Button {
                acceptInvite(serverInfo: serverInfo)
            } label: {
                HStack(spacing: 8) {
                    if isJoining {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text(viewState.servers[serverInfo.server_id] != nil ? "Open Server" : "Accept Invite")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(viewState.theme.accent.color)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(isJoining)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
        .background(viewState.theme.background2.color)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(viewState.theme.background3.color, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .frame(maxWidth: 480)
    }
    
    private func acceptInvite(serverInfo: ServerInfoResponse) {
        guard !isJoining else { return }
        joinError = nil
        
        // Already a member → just open it.
        if viewState.servers[serverInfo.server_id] != nil {
            viewState.selectChannel(inServer: serverInfo.server_id, withId: serverInfo.channel_id)
            viewState.selectedTab = .servers
            if !viewState.path.isEmpty { viewState.path.removeLast() }
            return
        }
        
        isJoining = true
        Task {
            let result = await viewState.http.joinServer(code: code)
            await MainActor.run {
                switch result {
                case .success(let join):
                    viewState.servers[join.server.id] = join.server
                    for channel in join.channels {
                        viewState.channels[channel.id] = channel
                        if viewState.channelMessages[channel.id] == nil {
                            viewState.channelMessages[channel.id] = []
                        }
                    }
                    
                    // Best-effort: load our own member entry. Don't block on it.
                    let serverId = join.server.id
                    Task {
                        if let userId = await viewState.currentUser?.id,
                           let member = try? await viewState.http.fetchMember(server: serverId, member: userId).get() {
                            await MainActor.run {
                                viewState.members[serverId] = [member.id.user: member]
                            }
                        }
                    }
                    
                    viewState.selectedTab = .servers
                    viewState.selectChannel(inServer: serverInfo.server_id, withId: serverInfo.channel_id)
                    if !viewState.path.isEmpty { viewState.path.removeLast() }
                    isJoining = false
                    
                case .failure(let e):
                    if case .HTTPError(let body, _) = e, let body, body.type == "AlreadyInServer" {
                        viewState.selectedTab = .servers
                        viewState.selectChannel(inServer: serverInfo.server_id, withId: serverInfo.channel_id)
                        if !viewState.path.isEmpty { viewState.path.removeLast() }
                        isJoining = false
                        return
                    }
                    joinError = "Couldn't accept invite. Please try again."
                    isJoining = false
                }
            }
        }
    }
}
