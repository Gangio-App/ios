//
//  WebhookSettings.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import SwiftUI
import Types

struct WebhookSettings: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewState: AppViewState
    
    @Binding var channel: Channel
    @Binding var webhook: Webhook
    
    @State var current: Webhook
    
    init(channel: Binding<Channel>, webhook: Binding<Webhook>) {
        self._channel = channel
        self._webhook = webhook
        self.current = webhook.wrappedValue
    }
    
    var body: some View {
        List {
            Section("Webhook Name") {
                TextField("Name", text: $current.name)
            }
            .listRowBackground(viewState.theme.background3)
            
            Section {
                Button("Copy URL") {
                    if let token = webhook.token {
                        let url = "\(viewState.http.baseURL)/webhooks/\(webhook.id)/\(token)"
                        copyText(text: url)
                    }
                }
            }
            .listRowBackground(viewState.theme.background2)
            
            Section {
                Button("Delete", role: .destructive) {
                    Task {
                        let _ = try! await viewState.http.deleteWebhook(webhook: webhook.id).get()
                        dismiss()
                    }
                }
                .foregroundStyle(viewState.theme.error)
            }
            .listRowBackground(viewState.theme.background2)
        }
        .scrollContentBackground(.hidden)
        .background(viewState.theme.background)
        .navigationTitle(webhook.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if webhook != current {
                    Button("Save") {
                        
                    }
                    .foregroundStyle(viewState.theme.accent)
                }
            }
        }
    }
}

