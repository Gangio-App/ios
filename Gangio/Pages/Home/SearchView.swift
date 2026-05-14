//
//  SearchView.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import SwiftUI
import Types

struct SearchView: View {
    @EnvironmentObject var viewState: AppViewState
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    private var isDark: Bool {
        !Theme.isLightOrDark(viewState.theme.background)
    }
    
    /// Search results: filters all cached messages by content
    private var searchResults: [(message: Message, channel: Channel?, user: User?)] {
        guard searchText.count >= 2 else { return [] }
        let query = searchText.lowercased()
        
        var results: [(Message, Channel?, User?)] = []
        
        for (_, message) in viewState.messages {
            if let content = message.content, content.lowercased().contains(query) {
                let channel = viewState.channels[message.channel]
                let user = viewState.users[message.author]
                results.append((message, channel, user))
            }
        }
        
        // Sort by message ID (ULID = chronological)
        results.sort { $0.0.id > $1.0.id }
        return Array(results.prefix(50)) // Limit to 50 results
    }
    
    /// Server search results
    private var serverResults: [Server] {
        guard searchText.count >= 2 else { return [] }
        let query = searchText.lowercased()
        return viewState.servers.values.filter { $0.name.lowercased().contains(query) }
    }
    
    /// User search results
    private var userResults: [User] {
        guard searchText.count >= 2 else { return [] }
        let query = searchText.lowercased()
        return viewState.users.values.filter {
            $0.username.lowercased().contains(query) ||
            ($0.display_name?.lowercased().contains(query) ?? false)
        }.prefix(20).map { $0 }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image("logo_round")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                
                Text("Search")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(viewState.theme.foreground.color)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
            
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(viewState.theme.foreground3.color)
                
                TextField("Search messages...", text: $searchText)
                    .font(.system(size: 16))
                    .foregroundStyle(viewState.theme.foreground.color)
                    .focused($isSearchFocused)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(viewState.theme.foreground3.color)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(viewState.theme.background2.color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            // Results
            if searchText.isEmpty {
                // Empty state
                VStack(spacing: 20) {
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(viewState.theme.accent.color.opacity(0.1))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 42))
                            .foregroundStyle(viewState.theme.accent.color)
                    }
                    
                    VStack(spacing: 6) {
                        Text("Search Messages")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(viewState.theme.foreground.color)
                        
                        Text("Find messages across all your\nchannels and conversations")
                            .font(.system(size: 14))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(viewState.theme.foreground3.color)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if searchText.count < 2 {
                VStack(spacing: 12) {
                    Spacer()
                    Text("Type at least 2 characters to search")
                        .font(.system(size: 15))
                        .foregroundStyle(viewState.theme.foreground3.color)
                    Spacer()
                }
            } else if searchResults.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(viewState.theme.foreground3.color)
                    
                    Text("No results found")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(viewState.theme.foreground.color)
                    
                    Text("Try a different search term")
                        .font(.system(size: 14))
                        .foregroundStyle(viewState.theme.foreground3.color)
                    
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        // Servers section
                        if !serverResults.isEmpty {
                            sectionHeader("SERVERS")
                            ForEach(serverResults, id: \.id) { server in
                                Button {
                                    viewState.selectServer(withId: server.id)
                                    viewState.selectedTab = .servers
                                } label: {
                                    HStack(spacing: 12) {
                                        ServerIcon(server: server, height: 40, width: 40, clipTo: RoundedRectangle(cornerRadius: 10))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(server.name)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(viewState.theme.foreground.color)
                                            if let desc = server.description {
                                                Text(desc).lineLimit(1)
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(viewState.theme.foreground3.color)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(viewState.theme.background2.color)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // Users section
                        if !userResults.isEmpty {
                            sectionHeader("USERS")
                            ForEach(userResults, id: \.id) { user in
                                Button {
                                    viewState.openUserSheet(user: user, member: nil)
                                } label: {
                                    HStack(spacing: 12) {
                                        AppAvatar(user: user, width: 40, height: 40)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(user.display_name ?? user.username)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(viewState.theme.foreground.color)
                                            Text("@\(user.username)#\(user.discriminator)")
                                                .font(.system(size: 12))
                                                .foregroundStyle(viewState.theme.foreground3.color)
                                        }
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(viewState.theme.background2.color)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // Messages section
                        if !searchResults.isEmpty {
                            sectionHeader("MESSAGES")
                            ForEach(searchResults, id: \.message.id) { result in
                                SearchResultRow(
                                    message: result.message,
                                    channel: result.channel,
                                    user: result.user
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 120)
                }
            }
        }
        .background(viewState.theme.background.color)
        .onAppear {
            isSearchFocused = true
        }
    }
    
    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(viewState.theme.foreground3.color)
                .tracking(1.0)
            Spacer()
        }
        .padding(.top, 8)
    }
}

struct SearchResultRow: View {
    @EnvironmentObject var viewState: AppViewState
    let message: Message
    let channel: Channel?
    let user: User?
    
    private var isDark: Bool {
        !Theme.isLightOrDark(viewState.theme.background)
    }
    
    var body: some View {
        Button {
            // Navigate to the message's channel and scroll to message
            if let channel = channel {
                if let server = channel.server {
                    viewState.currentSelection = .server(server)
                } else {
                    viewState.currentSelection = .dms
                }
                viewState.currentChannel = .channel(channel.id)
                viewState.selectedTab = .servers
                viewState.pendingScrollToMessage = message.id
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                // Channel info
                HStack(spacing: 6) {
                    if let channel = channel {
                        Image(systemName: "number")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(viewState.theme.foreground3.color)
                        
                        Text(channel.getName(viewState))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(viewState.theme.foreground3.color)
                    }
                    
                    Spacer()
                }
                
                // Message content
                HStack(alignment: .top, spacing: 10) {
                    if let user = user {
                        AppAvatar(user: user, width: 36, height: 36)
                    } else {
                        Circle()
                            .fill(viewState.theme.background3.color)
                            .frame(width: 36, height: 36)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(user?.display_name ?? user?.username ?? "Unknown")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(viewState.theme.foreground.color)
                            
                            Text(formatTime(id: message.id))
                                .font(.system(size: 11))
                                .foregroundStyle(viewState.theme.foreground3.color)
                        }
                        
                        Text(message.content ?? "")
                            .font(.system(size: 14))
                            .foregroundStyle(viewState.theme.foreground2.color)
                            .lineLimit(3)
                    }
                }
            }
            .padding(12)
            .background(viewState.theme.background2.color)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
    
    func formatTime(id: String) -> String {
        let crockford = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
        let chars = id.uppercased().prefix(10)
        var timestamp: UInt64 = 0
        for char in chars {
            if let index = crockford.firstIndex(of: char) {
                timestamp = timestamp * 32 + UInt64(crockford.distance(from: crockford.startIndex, to: index))
            }
        }
        
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }
}
