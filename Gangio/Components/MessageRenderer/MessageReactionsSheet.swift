//
//  MessageReactionsSheet.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import SwiftUI
import Types

struct MessageReactionsSheet: View {
    @EnvironmentObject var viewState: AppViewState
    
    @ObservedObject var viewModel: MessageContentsViewModel
    @State var selection: String
    
    init(viewModel: MessageContentsViewModel) {
        self.viewModel = viewModel
        // Best-effort initial selection. Body re-resolves from viewState live.
        selection = viewModel.message.reactions?.keys.first ?? ""
    }
    
    var body: some View {
        // Read live message from viewState so updates re-render this sheet.
        let liveMessage = viewState.messages[viewModel.messageId] ?? viewModel.message
        let reactions = liveMessage.reactions ?? [:]
        
        VStack {
            ScrollView(.horizontal) {
                HStack {
                    ForEach(Array(reactions.keys), id: \.self) { emoji in
                        Button {
                            selection = emoji
                        } label: {
                            HStack(spacing: 8) {
                                if emoji.count == 26 {
                                    LazyImage(source: .emoji(emoji), height: 16, width: 16, clipTo: Rectangle())
                                } else {
                                    Text(verbatim: emoji)
                                        .font(.system(size: 16))
                                }
                                
                                Text(verbatim: String(reactions[emoji]?.count ?? 0))
                            }
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 5).foregroundStyle(selection == emoji ? viewState.theme.background3 : viewState.theme.background2))
                    }
                }
                .padding(16)
            }
            
            HStack {
                let users = reactions[selection] ?? []
                
                List {
                    ForEach(users.compactMap({ viewState.users[$0] }), id: \.self) { user in
                        let member: Member? = viewModel.server.flatMap { viewState.members[$0.id]?[user.id] }
                        
                        Button {
                            viewState.openUserSheet(user: user, member: member)
                        } label: {
                            HStack(spacing: 8) {
                                AppAvatar(user: user, member: member)
                                
                                Text(verbatim: member?.nickname ?? user.display_name ?? user.username)
                            }
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(viewState.theme.background)
                }
            }
        }
        .padding(.top, 16)
        .presentationDragIndicator(.visible)
        .presentationBackground(viewState.theme.background)
    }
}
