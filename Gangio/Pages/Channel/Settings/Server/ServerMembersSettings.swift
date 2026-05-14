//
//  ServerMembersSettings.swift
//  Gangio
//

import SwiftUI
import Types

struct ServerMembersSettings: View {
    @EnvironmentObject var viewState: AppViewState
    @Binding var server: Server
    
    @State private var members: [Member] = []
    @State private var users: [String: User] = [:]
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var selectedMember: Member? = nil
    
    private var filteredMembers: [Member] {
        let allMembers = members.sorted { a, b in
            let nameA = (users[a.id.user]?.display_name ?? users[a.id.user]?.username ?? "").lowercased()
            let nameB = (users[b.id.user]?.display_name ?? users[b.id.user]?.username ?? "").lowercased()
            return nameA < nameB
        }
        if searchText.isEmpty { return allMembers }
        let q = searchText.lowercased()
        return allMembers.filter { m in
            let user = users[m.id.user]
            return (user?.username.lowercased().contains(q) ?? false) ||
                   (user?.display_name?.lowercased().contains(q) ?? false) ||
                   (m.nickname?.lowercased().contains(q) ?? false)
        }
    }
    
    var body: some View {
        ZStack {
            viewState.theme.background.color.ignoresSafeArea()
            
            if isLoading {
                ProgressView("Loading members...")
            } else {
                VStack(spacing: 0) {
                    // Search bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(viewState.theme.foreground3.color)
                        TextField("Search members...", text: $searchText)
                            .foregroundStyle(viewState.theme.foreground.color)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(viewState.theme.background2.color)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    Text("\(filteredMembers.count) members")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(viewState.theme.foreground3.color)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(filteredMembers, id: \.id.user) { member in
                                memberRow(member: member)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                    }
                }
            }
        }
        .navigationTitle("Members")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMembers()
        }
    }
    
    @ViewBuilder
    private func memberRow(member: Member) -> some View {
        if let user = users[member.id.user] {
            Button {
                viewState.openUserSheet(user: user, member: member)
            } label: {
                HStack(spacing: 12) {
                    AppAvatar(user: user, member: member, width: 40, height: 40, withPresence: true)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.nickname ?? user.display_name ?? user.username)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(viewState.theme.foreground.color)
                        Text("@\(user.username)#\(user.discriminator)")
                            .font(.system(size: 12))
                            .foregroundStyle(viewState.theme.foreground3.color)
                    }
                    
                    Spacer()
                    
                    if let roles = member.roles, !roles.isEmpty,
                       let topRole = roles.compactMap({ server.roles?[$0] }).sorted(by: { $0.rank < $1.rank }).first {
                        Text(topRole.name)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(viewState.theme.background3.color)
                            .clipShape(Capsule())
                    }
                }
                .padding(12)
                .background(viewState.theme.background2.color)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .contextMenu {
                let userPermissions = currentUserPermissions()
                
                Button {
                    viewState.openUserSheet(user: user, member: member)
                } label: { Label("View Profile", systemImage: "person.crop.circle") }
                
                if userPermissions.contains(.kickMembers) && member.id.user != viewState.currentUser?.id {
                    Button(role: .destructive) {
                        Task {
                            _ = await viewState.http.kickMember(server: server.id, user: member.id.user)
                            await loadMembers()
                        }
                    } label: { Label("Kick", systemImage: "person.fill.xmark") }
                }
                
                if userPermissions.contains(.banMembers) && member.id.user != viewState.currentUser?.id {
                    Button(role: .destructive) {
                        Task {
                            _ = await viewState.http.banMember(server: server.id, user: member.id.user, reason: nil)
                            await loadMembers()
                        }
                    } label: { Label("Ban", systemImage: "hand.raised.slash.fill") }
                }
            }
        }
    }
    
    private func currentUserPermissions() -> Permissions {
        guard let user = viewState.currentUser,
              let myMember = viewState.members[server.id]?[user.id] else { return [] }
        return resolveServerPermissions(user: user, member: myMember, server: server)
    }
    
    private func loadMembers() async {
        isLoading = true
        let result = await viewState.http.fetchMembers(server: server.id, excludeOffline: false)
        if case .success(let data) = result {
            await MainActor.run {
                members = data.members
                for u in data.users {
                    users[u.id] = u
                    viewState.users[u.id] = u
                }
                for m in data.members {
                    viewState.members[server.id, default: [:]][m.id.user] = m
                }
            }
        }
        isLoading = false
    }
}
