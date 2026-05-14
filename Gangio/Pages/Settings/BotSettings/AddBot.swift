//
//  AddBot.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import SwiftUI
import Types

enum AddTarget: Identifiable, Hashable, Equatable {
    case server(Server)
    case group(GroupDMChannel)
    
    var id: String {
        switch self {
            case .server(let server):
                return server.id
            case .group(let groupDMChannel):
                return groupDMChannel.id
        }
    }
}

struct AddBot: View {
    @EnvironmentObject var viewState: AppViewState
    @Environment(\.dismiss) private var dismiss
    
    var user: User
    var bot: Bot
    
    @State var targets: [AddTarget] = []
    @State var selected: Set<AddTarget> = []
    @State private var isInviting = false
    @State private var inviteResultMessage: String? = nil
    @State private var showResult = false

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            AppAvatar(user: user, width: 64, height: 64)
            
            VStack {
                Text(verbatim: user.display_name ?? user.username)
                    .bold()
                    .font(.title)
                
                Text(verbatim: user.username).bold() + Text("#\(user.discriminator)")
                    .font(.subheadline)
                
            }
            
            if bot.privacy_policy_url != nil || bot.terms_of_service_url != nil {
                HStack {
                    if let url = bot.privacy_policy_url {
                        Text("[Privacy Policy](\(url))")
                    }
                    
                    if bot.privacy_policy_url != nil, bot.terms_of_service_url != nil {
                        Text("•")
                    }
                    
                    if let url = bot.terms_of_service_url {
                        Text("[Terms of Use](\(url))")
                    }
                }
            }
            
            ViewThatFits {
                List(targets, selection: $selected) { target in
                    HStack(spacing: 12) {
                        switch target {
                            case .group(let group):
                                ChannelIcon(channel: .group_dm_channel(group), width: 32, height: 32)
                            case .server(let server):
                                ServerIcon(server: server, height: 32, width: 32, clipTo: Circle())
                                
                                Text(server.name)
                        }
                    }
                    .listRowBackground(viewState.theme.background2)
                }
                .contentMargins(.top, 0, for: .scrollContent)
                .scrollContentBackground(.hidden)
            }
        
            VStack {
                Text("Bots are not verified by Gangio.")
                Text("The bot will not be granted any permissions.")
            }
            .font(.footnote)
            
            Button {
                Task { await inviteBotTo(targets: selected) }
            } label: {
                HStack {
                    if isInviting { ProgressView().tint(viewState.theme.foreground.color) }
                    Text(isInviting ? "Adding..." : "Add Bot")
                        .foregroundStyle(selected.isEmpty || isInviting ? viewState.theme.foreground2 : viewState.theme.foreground)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
            }
            .disabled(selected.isEmpty || isInviting)
            .background(viewState.theme.background2)
            .clipShape(.capsule)
            .padding(.leading, 8)
        }
        .alert(inviteResultMessage ?? "", isPresented: $showResult) {
            Button("OK") {
                if inviteResultMessage?.contains("successfully") == true {
                    dismiss()
                }
            }
        }
        .onAppear {
            for server in viewState.servers.values {
                targets.append(.server(server))
            }
            
            for channel in viewState.channels.values {
                if case .group_dm_channel(let group) = channel {
                    targets.append(.group(group))
                }
            }
        }
        .background(viewState.theme.background)
        .navigationTitle("Add bot")
        .toolbarBackground(viewState.theme.topBar, for: .automatic)
        .environment(\.editMode, .constant(.active))
    }
    
    private func inviteBotTo(targets: Set<AddTarget>) async {
        guard !targets.isEmpty else { return }
        isInviting = true
        var successCount = 0
        var failCount = 0
        
        for target in targets {
            let result: Result<EmptyResponse, GangioError>
            switch target {
            case .server(let server):
                result = await viewState.http.inviteBot(bot: bot.id, server: server.id)
            case .group(let group):
                result = await viewState.http.inviteBotToGroup(bot: bot.id, group: group.id)
            }
            switch result {
            case .success: successCount += 1
            case .failure: failCount += 1
            }
        }
        
        isInviting = false
        if failCount == 0 {
            inviteResultMessage = "Bot added successfully to \(successCount) target\(successCount == 1 ? "" : "s")."
        } else {
            inviteResultMessage = "Added to \(successCount), failed for \(failCount)."
        }
        showResult = true
    }
}
