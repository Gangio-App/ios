//
//  ChannelSearch.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import SwiftUI
import Types

struct ChannelSearch: View {
    @EnvironmentObject var viewState: AppViewState
    
    @Binding var channel: Channel
    
    @State var searchQuery: String = ""
    @State var results: [Types.Message] = []
    
    var body: some View {
        let server = channel.server.map { $viewState.servers[$0] } ?? .constant(nil)
        
        List {
            ForEach(results) { result in
                MessageView(
                    viewModel: .init(
                        viewState: viewState,
                        messageId: result.id,
                        channelId: channel.id,
                        server: server,
                        channel: $channel,
                        replies: .constant([]),
                        channelScrollPosition: .empty,
                        editing: .constant(nil)
                    ),
                    isStatic: true
                )
            }
            .listRowBackground(viewState.theme.background2)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(viewState.theme.background)
        .searchable(text: $searchQuery)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .resizable()
                        .frame(width: 24, height: 24)
                    
                    Text("Search")
                }
            }
        }
        .toolbarBackground(viewState.theme.topBar, for: .automatic)
        .onChange(of: searchQuery, { _, query in
            if query.count >= 1, query.count <= 64 {
                Task {
                    guard let response = try? await viewState.http.searchChannel(channel: channel.id, query: query).get() else {
                        return
                    }
                    
                    for user in response.users {
                        if !viewState.users.keys.contains(user.id) {
                            viewState.users[user.id] = user
                        }
                    }
                    
                    for member in response.members {
                        if viewState.members[member.id.server] == nil {
                            viewState.members[member.id.server] = [:]
                        }
                        if !(viewState.members[member.id.server]?.keys.contains(member.id.user) ?? false) {
                            viewState.members[member.id.server]?[member.id.user] = member
                        }
                    }
                    
                    // Stage messages so the id-based MessageContentsViewModel
                    // can resolve them via viewState.messages.
                    for msg in response.messages {
                        viewState.messages[msg.id] = msg
                    }
                    
                    results = response.messages
                }
            }
        })
    }
}
