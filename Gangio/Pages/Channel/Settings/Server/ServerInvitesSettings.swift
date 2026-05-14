//
//  ServerInvitesSettings.swift
//  Gangio
//

import SwiftUI
import Types

struct ServerInvitesSettings: View {
    @EnvironmentObject var viewState: AppViewState
    @Binding var server: Server
    
    @State private var invites: [Invite] = []
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            viewState.theme.background.color.ignoresSafeArea()
            
            if isLoading {
                ProgressView("Loading invites...")
            } else if invites.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "envelope.open")
                        .font(.system(size: 48))
                        .foregroundStyle(viewState.theme.foreground3.color)
                    Text("No invites")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(viewState.theme.foreground.color)
                    Text("Create an invite from a channel to share this server.")
                        .font(.system(size: 13))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(viewState.theme.foreground3.color)
                        .padding(.horizontal, 40)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(invites, id: \.id) { invite in
                            inviteRow(invite: invite)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Invites")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadInvites()
        }
    }
    
    @ViewBuilder
    private func inviteRow(invite: Invite) -> some View {
        let code = invite.id
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "link")
                    .foregroundStyle(viewState.theme.accent.color)
                Text("gangio.pro/invite/\(code)")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(viewState.theme.foreground.color)
                Spacer()
                Button {
                    UIPasteboard.general.string = "https://gangio.pro/invite/\(code)"
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .foregroundStyle(viewState.theme.foreground2.color)
                }
            }
            
            HStack(spacing: 12) {
                if case .server(let s) = invite, let creator = viewState.users[s.creator] {
                    HStack(spacing: 4) {
                        AppAvatar(user: creator, width: 18, height: 18)
                        Text(creator.display_name ?? creator.username)
                            .font(.system(size: 12))
                            .foregroundStyle(viewState.theme.foreground2.color)
                    }
                }
                Spacer()
            }
        }
        .padding(12)
        .background(viewState.theme.background2.color)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func loadInvites() async {
        isLoading = true
        let result = await viewState.http.fetchInvites(server: server.id)
        if case .success(let data) = result {
            await MainActor.run {
                invites = data
            }
        }
        isLoading = false
    }
}
