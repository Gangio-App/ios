//
//  ChannelPermissionsSettings.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import SwiftUI
import Types

struct ChannelPermissionsSettings: View {
    @EnvironmentObject var viewState: AppViewState
    
    @Binding var server: Server?
    @Binding var channel: Channel
    
    var body: some View {
        List {
            switch channel {
                case .saved_messages:
                    EmptyView()
                case .dm_channel:
                    EmptyView()
                case .group_dm_channel(let groupDMChannel):
                    GroupDMChannelPermissionsSettings(channel: groupDMChannel)
                case .text_channel, .voice_channel:
                    Section {
                        ForEach(Array(server!.roles ?? [:]).sorted(by: { a, b in a.value.rank < b.value.rank }), id: \.key) { pair in
                            let roleColour = pair.value.colour.map { parseCSSColorToShapeStyle(currentTheme: viewState.theme, input: $0) } ?? AnyShapeStyle(viewState.theme.foreground)
                            
                            NavigationLink {
                                let overwrite = channel.role_permissions?[pair.key] ?? Overwrite(a: .none, d: .none)
                                ChannelRolePermissionsSettings(server: Binding($server)!, channel: $channel, roleId: pair.key, permissions: .overwrite(overwrite))
                                    .toolbar {
                                        ToolbarItem(placement: .principal) {
                                            Text(verbatim: pair.value.name)
                                                .bold()
                                                .foregroundStyle(roleColour)
                                        }
                                    }
                            } label: {
                                Text(verbatim: pair.value.name)
                                    .foregroundStyle(roleColour)
                            }
                        }
                        
                        NavigationLink {
                            ChannelRolePermissionsSettings(
                                server: Binding($server)!,
                                channel: $channel,
                                roleId: nil,
                                permissions: .overwrite(channel.default_permissions ?? Overwrite(a: .none, d: .none))
                            )
                                .navigationTitle("Default")
                        } label: {
                            Text("Default")
                        }
                    }
                    .listRowBackground(viewState.theme.background2)
            }
        }
        .scrollContentBackground(.hidden)
        .background(viewState.theme.background)
        .navigationTitle("Permissions")
    }
}
