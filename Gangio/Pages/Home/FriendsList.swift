//
//  FriendsList.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import SwiftUI
import Types

struct Friends {
    var outgoing: [User]
    var incoming: [User]
    var friends: [User]
    var blocked: [User]
    var blockedBy: [User]
}

struct FriendsList: View {
    @EnvironmentObject var viewState: AppViewState
    @State private var searchText = ""

    func getFriends() -> Friends {
        var friends = Friends(outgoing: [], incoming: [], friends: [], blocked: [], blockedBy: [])
        
        for user in viewState.users.values {
            switch user.relationship ?? .None {
                case .Blocked:
                    friends.blocked.append(user)
                case .BlockedOther:
                    friends.blockedBy.append(user)
                case .Friend:
                    friends.friends.append(user)
                case .Incoming:
                    friends.incoming.append(user)
                case .Outgoing:
                    friends.outgoing.append(user)
                default:
                    break
            }
        }
        
        return friends
    }
    
    var body: some View {
        let allFriends = getFriends()
        
        ScrollView {
            VStack(spacing: 20) {
                // Header Actions
                HStack(spacing: 12) {
                    FriendActionCard(title: "Add Friend", icon: "person.badge.plus", color: .green) {
                        viewState.path.append(NavigationDestination.add_friend)
                    }
                    
                    FriendActionCard(title: "New Group", icon: "person.2.fill", color: .blue) {
                        viewState.path.append(NavigationDestination.create_group([]))
                    }
                }
                .padding(.horizontal)
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search friends...", text: $searchText)
                        .font(.system(.body, design: .rounded))
                }
                .padding(12)
                .background(viewState.theme.background2.color)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // Sections
                VStack(spacing: 24) {
                    let sections = [
                        ("Requests", allFriends.incoming),
                        ("Pending", allFriends.outgoing),
                        ("All Friends", allFriends.friends),
                        ("Blocked", allFriends.blocked)
                    ].filter { !$0.1.isEmpty }
                    
                    if sections.isEmpty && searchText.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .font(.system(size: 64))
                                .foregroundStyle(.secondary.opacity(0.3))
                            Text("No friends yet")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 40)
                    }
                    
                    ForEach(sections, id: \.0) { title, users in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(title.uppercased())
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                            
                            VStack(spacing: 1) {
                                ForEach(users.filter { searchText.isEmpty || $0.username.localizedCaseInsensitiveContains(searchText) }) { user in
                                    FriendRow(user: user)
                                }
                            }
                            .background(viewState.theme.background2.color)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .background(viewState.theme.background.color)
    }
}

struct FriendActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct FriendRow: View {
    @EnvironmentObject var viewState: AppViewState
    let user: User
    
    var body: some View {
        HStack(spacing: 12) {
            AppAvatar(user: user, width: 44, height: 44, withPresence: true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.display_name ?? user.username)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                if let status = user.status?.text {
                    Text(status)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(user.effectivePresence?.rawValue ?? "Offline")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                switch user.relationship ?? .None {
                case .Incoming:
                    // Accept (✓) and reject (✗): backend treats DELETE
                    // /users/{id}/friend on an Incoming request as "decline".
                    Button {
                        Task { await viewState.http.acceptFriendRequest(user: user.id) }
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                    }
                    Button {
                        Task { await viewState.http.removeFriend(user: user.id) }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.red)
                    }
                case .Outgoing:
                    // Cancel pending request.
                    Button {
                        Task { await viewState.http.removeFriend(user: user.id) }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.orange)
                    }
                case .Friend:
                    Button {
                        Task { await viewState.openDm(with: user.id) }
                    } label: {
                        Image(systemName: "bubble.left.fill")
                            .font(.title3)
                            .foregroundStyle(Color(hex: "5865F2"))
                    }
                case .Blocked:
                    Button {
                        Task { _ = await viewState.http.unblockUser(user: user.id) }
                    } label: {
                        Image(systemName: "lock.open.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                default:
                    EmptyView()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            viewState.openUserSheet(user: user)
        }
        .contextMenu {
            // Long-press menu mirrors Discord: a single "Remove Friend"
            // entry on real friends, otherwise nothing destructive.
            if user.relationship == .Friend {
                Button(role: .destructive) {
                    Task { await viewState.http.removeFriend(user: user.id) }
                } label: {
                    Label("Remove Friend", systemImage: "person.badge.minus")
                }
            }
        }
    }
}


#Preview {
    FriendsList()
        .applyPreviewModifiers(withState: AppViewState.preview())
}
