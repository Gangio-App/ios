//
//  ChannelSettiings.swift
//  Gangio
//
//  Created by Angelo on 08/01/2024.
//

import Foundation
import SwiftUI
import Types

struct ChannelSettings: View {
    @EnvironmentObject var viewState: AppViewState
    
    @Binding var server: Server?
    @Binding var channel: Channel
    
    var body: some View {
        List {
            Section("Settings") {
                NavigationLink {
                    ChannelOverviewSettings.fromState(viewState: viewState, channel: $channel)
                } label: {
                    Image(systemName: "info.circle.fill")
                    Text("Overview")
                }
                
                NavigationLink {
                    ChannelPermissionsSettings(server: $server, channel: $channel)
                } label: {
                    Image(systemName: "list.bullet")
                    Text("Permissions")
                }
                
                if let server = Binding($server) {
                    NavigationLink {
                        ChannelWebhookSettings(server: server, channel: $channel)
                    } label: {
                        Image(systemName: "cloud.fill")
                        Text("Webhooks")
                    }
                }
            }
            .listRowBackground(viewState.theme.background2)
            
            Button {
                
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Delete channel")
                }
                .foregroundStyle(.red)
            }
            .listRowBackground(viewState.theme.background2)

        }
        .scrollContentBackground(.hidden)
        .background(viewState.theme.background)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ChannelIcon(channel: channel)
            }
        }
        .toolbarBackground(viewState.theme.topBar.color, for: .automatic)

    }
}

#Preview {
    @Previewable @StateObject var viewState = AppViewState.preview().applySystemScheme(theme: .light)
    let channel = Binding($viewState.channels["0"])!
    let server = $viewState.servers["0"]
    
    return NavigationStack {
        ChannelSettings(server: server, channel: channel)
    }.applyPreviewModifiers(withState: viewState)
}
