//
//  InviteEmbed.swift
//  Gangio
//
//  Discord-like server invite embed for messages.
//

import SwiftUI
import Types

struct InviteEmbed: View {
    @EnvironmentObject var viewState: AppViewState
    let code: String
    
    @State private var inviteInfo: InviteInfoResponse? = nil
    @State private var isLoading = true
    @State private var failed = false
    @State private var isJoining = false
    @State private var joinError: String? = nil
    
    var body: some View {
        Group {
            if isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Loading invite...")
                        .font(.system(size: 13))
                        .foregroundStyle(viewState.theme.foreground2.color)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(viewState.theme.background2.color)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if let info = inviteInfo {
                inviteContent(info: info)
            } else if failed {
                Text("Invalid or expired invite")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .background(viewState.theme.background2.color)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .task {
            let result = await viewState.http.fetchInvite(code: code)
            if case .success(let info) = result {
                inviteInfo = info
            } else {
                failed = true
            }
            isLoading = false
        }
    }
    
    @ViewBuilder
    private func inviteContent(info: InviteInfoResponse) -> some View {
        switch info {
        case .server(let server):
            // Vertical card layout: banner → server info row → full-width Join button.
            // Avoids text/button overlap on narrow widths.
            VStack(alignment: .leading, spacing: 0) {
                // Banner / gradient header
                ZStack(alignment: .bottomLeading) {
                    if let banner = server.server_banner {
                        LazyImage(source: .file(banner), height: 80, clipTo: Rectangle())
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .clipped()
                    } else {
                        LinearGradient(
                            colors: [viewState.theme.accent.color, viewState.theme.accent.color.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(height: 80)
                    }
                    
                    // Subtle dark scrim for readability of the badge below
                    LinearGradient(
                        colors: [.black.opacity(0), .black.opacity(0.35)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 80)
                    
                    Text("INVITE")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.0)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.4), in: Capsule())
                        .padding(10)
                }
                
                // Server identity row
                HStack(alignment: .center, spacing: 12) {
                    Group {
                        if let icon = server.server_icon {
                            LazyImage(source: .file(icon), height: 48, clipTo: RoundedRectangle(cornerRadius: 12))
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(viewState.theme.background3.color)
                                .overlay(
                                    Text(String(server.server_name.first ?? "?").uppercased())
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(viewState.theme.foreground.color)
                                )
                        }
                    }
                    .frame(width: 48, height: 48)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(server.server_name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(viewState.theme.foreground.color)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        HStack(spacing: 6) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 8, height: 8)
                                Text("\(server.member_count) members")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(viewState.theme.foreground2.color)
                                    .lineLimit(1)
                            }
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 10)
                
                if let error = joinError {
                    Text(error)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Full-width Join action: avoids overlap and is easy to tap.
                Button {
                    joinServer()
                } label: {
                    HStack(spacing: 8) {
                        if isJoining {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text(isAlreadyMember(serverId: server.server_id) ? "Open Server" : "Join Server")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(viewState.theme.accent.color)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(isJoining)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .background(viewState.theme.background2.color)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(viewState.theme.background3.color, lineWidth: 1)
            )
            .frame(maxWidth: 380)
            
        case .group(let group):
            HStack(spacing: 12) {
                if let avatar = group.user_avatar {
                    LazyImage(source: .file(avatar), height: 48, clipTo: Circle())
                        .frame(width: 48, height: 48)
                } else {
                    Circle()
                        .fill(viewState.theme.background3.color)
                        .frame(width: 48, height: 48)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("GROUP INVITE")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(0.8)
                        .foregroundStyle(viewState.theme.foreground3.color)
                    Text(group.channel_name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(viewState.theme.foreground.color)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(viewState.theme.background2.color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func isAlreadyMember(serverId: String) -> Bool {
        viewState.servers[serverId] != nil
    }
    
    private func joinServer() {
        guard !isJoining else { return }
        isJoining = true
        joinError = nil
        
        Task {
            // Capture server id from cached invite info before any state changes.
            let preknownServerId: String? = {
                if case .some(.server(let s)) = inviteInfo { return s.server_id }
                return nil
            }()
            
            // If the user is already a member, just navigate without re-joining.
            if let id = preknownServerId, viewState.servers[id] != nil {
                await MainActor.run {
                    viewState.selectServer(withId: id)
                    viewState.selectedTab = .servers
                    isJoining = false
                }
                return
            }
            
            let result = await viewState.http.joinServer(code: code)
            await MainActor.run {
                switch result {
                case .success(let response):
                    // Persist server + channels locally.
                    viewState.servers[response.server.id] = response.server
                    for channel in response.channels {
                        viewState.channels[channel.id] = channel
                        if viewState.channelMessages[channel.id] == nil {
                            viewState.channelMessages[channel.id] = []
                        }
                    }
                    
                    // Switch to the servers tab and open the new server.
                    viewState.selectedTab = .servers
                    viewState.selectServer(withId: response.server.id)
                    isJoining = false
                    
                case .failure(let error):
                    // "AlreadyInServer" → just open it instead of failing silently.
                    if case .HTTPError(let body, _) = error,
                       let body, body.type == "AlreadyInServer",
                       let id = preknownServerId {
                        viewState.selectedTab = .servers
                        viewState.selectServer(withId: id)
                        isJoining = false
                        return
                    }
                    
                    joinError = "Couldn't join. Please try again."
                    isJoining = false
                }
            }
        }
    }
}

// Helper to detect invite codes in message content
struct InviteCodeDetector {
    static func extractCodes(from text: String) -> [String] {
        // Match: gangio.pro/invite/CODE, https://gangio.pro/invite/CODE, etc.
        let pattern = #"(?:https?://)?(?:www\.)?(?:gangio\.(?:pro|chat)|rvlt\.gg)/invite/([a-zA-Z0-9]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        return matches.compactMap { match in
            guard let codeRange = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[codeRange])
        }
    }
}
