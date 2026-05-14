//
//  ChannelPins.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import SwiftUI
import Types

struct ChannelPins: View {
    @EnvironmentObject var viewState: AppViewState
    
    @Binding var channel: Channel
    
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
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack {
                    Image(systemName: "pin.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                    
                    Text("Pins")
                }
            }
        }
        .toolbarBackground(viewState.theme.topBar, for: .automatic)
        .task {
            guard let response = try? await viewState.http.fetchChannelPins(channel: channel.id).get() else {
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
            
            // Stage messages so the id-based VM can resolve them.
            for msg in response.messages {
                viewState.messages[msg.id] = msg
            }
            
            results = response.messages
        }
    }
}
