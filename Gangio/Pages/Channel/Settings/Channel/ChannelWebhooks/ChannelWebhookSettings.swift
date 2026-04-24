//
//  ChannelWebhookSettings.swift
//  Gangio
//
//  Created by Angelo on 14/06/2025.
//

import SwiftUI
import Types

struct ChannelWebhookSettings: View {
    @EnvironmentObject var viewState: ViewState
    
    @Binding var server: Server
    @Binding var channel: Channel
    
    @State var webhooks: [Webhook]? = nil
    @State var error: String? = nil
    @State var showCreateWebhook: Bool = false
    
    func fetchWebhooks() async {
        do {
            webhooks = try await viewState.http.fetchWebhooks(channel: channel.id).get()
        } catch let e {
            error = e.localizedDescription
        }
    }
    
    var body: some View {
        Group {
            if let webhooks = Binding($webhooks) {
                List {
                    Section("Webhooks - \(webhooks.wrappedValue.count)") {
                        ForEach(webhooks) { webhook in
                            NavigationLink {
                                WebhookSettings(channel: $channel, webhook: webhook)
                            } label: {
                                HStack {
                                    if let avatar = webhook.wrappedValue.avatar {
                                        LazyImage(source: .file(avatar), height: 24, width: 24, clipTo: Circle())
                                    } else {
                                        Circle()
                                            .foregroundStyle(viewState.theme.foreground3)
                                            .frame(width: 24, height: 24)
                                    }
                                    
                                    Text(verbatim: webhook.wrappedValue.name)
                                }
                            }
                        }
                    }
                    .listRowBackground(viewState.theme.background2)
                    
                    Button("Create Webhook", systemImage: "plus") {
                        showCreateWebhook = true
                    }
                    .foregroundStyle(.green)
                    .listRowBackground(viewState.theme.background2)
                    .alert("Create a new webhook", isPresented: $showCreateWebhook) {
                        CreateWebhookAlert(webhooks: webhooks, channel: $channel, error: $error)
                    }
                }
                .refreshable {
                    await fetchWebhooks()
                }
            } else if let error {
                Text(verbatim: error)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .task {
            await fetchWebhooks()
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Webhooks")
        .background(viewState.theme.background)
    }
}

struct CreateWebhookAlert: View {
    @EnvironmentObject var viewState: ViewState
    
    @Binding var webhooks: [Webhook]
    @Binding var channel: Channel
    @Binding var error: String?
    
    @State var name: String = ""
    
    var body: some View {
        TextField("Webhook Name", text: $name)
        
        Button("Create") {
            Task {
                if name.isEmpty { return }
                
                do {
                    let webhook = try await viewState.http.createWebhook(channel: channel.id, body: CreateWebhookPayload(name: name)).get()
                    webhooks.append(webhook)
                } catch let e {
                    error = e.localizedDescription
                }
            }
        }
        
        Button("Cancel", role: .cancel) {}
    }
}
