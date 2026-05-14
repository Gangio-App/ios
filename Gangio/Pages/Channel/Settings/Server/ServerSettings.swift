//
//  ServerSettings.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import SwiftUI
import Types

struct ServerSettings: View {
    @EnvironmentObject var viewState: AppViewState
    @Environment(\.dismiss) private var dismiss
    @Binding var server: Server
    
    @State var userPermissions: Permissions = Permissions.all
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String? = nil
    
    var body: some View {
        List {
            Section("Settings") {
                if userPermissions.contains(.manageServer) {
                    NavigationLink {
                        ServerOverviewSettings(server: $server)
                    } label: {
                        Image(systemName: "info.circle.fill")
                        Text("Overview")
                    }
                }
                
                if userPermissions.contains(.manageChannel) {
                    NavigationLink {
                        ServerCategoriesSettings(server: $server)
                    } label: {
                        Image(systemName: "list.bullet")
                        Text("Categories")
                    }
                }

                if userPermissions.contains(.manageRole) {
                    NavigationLink {
                        ServerRolesSettings(server: $server)
                    } label: {
                        Image(systemName: "flag.fill")
                        Text("Roles")
                    }
                }
            }
            .listRowBackground(viewState.theme.background2)
            
            Section("Customisation") {
                if userPermissions.contains(.manageCustomisation) {
                    NavigationLink {
                        ServerEmojiSettings(server: $server)
                    } label: {
                        Image(systemName: "face.smiling")
                        Text("Emojis")
                    }
                }
            }
            .listRowBackground(viewState.theme.background2)
            
            Section("User Management") {
                NavigationLink {
                    ServerMembersSettings(server: $server)
                } label: {
                    Image(systemName: "person.2.fill")
                    Text("Members")
                }
                
                if userPermissions.contains(.manageServer) {
                    NavigationLink {
                        ServerInvitesSettings(server: $server)
                    } label: {
                        Image(systemName: "envelope.fill")
                        Text("Invites")
                    }
                }
                
                if userPermissions.contains(.banMembers) {
                    NavigationLink {
                        ServerBanSettings(server: $server)
                    } label: {
                        Image(systemName: "person.fill.xmark")
                        Text("Bans")
                    }
                }
            }
            .listRowBackground(viewState.theme.background2)
            
            // Owners get "Delete Server"; non-owners can leave instead.
            if server.owner == viewState.currentUser?.id {
                Section {
                    if let deleteError {
                        Text(deleteError)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.red)
                    }
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            if isDeleting {
                                ProgressView()
                            } else {
                                Image(systemName: "trash.fill")
                            }
                            Text("Delete server")
                        }
                        .foregroundStyle(.red)
                    }
                    .disabled(isDeleting)
                }
                .listRowBackground(viewState.theme.background2)
            } else {
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            if isDeleting {
                                ProgressView()
                            } else {
                                Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                            }
                            Text("Leave server")
                        }
                        .foregroundStyle(.red)
                    }
                    .disabled(isDeleting)
                }
                .listRowBackground(viewState.theme.background2)
            }
        }
        .scrollContentBackground(.hidden)
        .background(viewState.theme.background)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack {
                    ServerIcon(server: server, height: 24, width: 24, clipTo: Circle())
                    Text(verbatim: server.name)
                }
            }
        }
        .toolbarBackground(viewState.theme.topBar.color, for: .automatic)
        .task {
            if let user = viewState.currentUser, let member = viewState.members[server.id]?[user.id] {
                userPermissions = resolveServerPermissions(user: user, member: member, server: server)
            }
        }
        .confirmationDialog(
            server.owner == viewState.currentUser?.id
                ? "Delete \(server.name)? This cannot be undone."
                : "Leave \(server.name)?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(server.owner == viewState.currentUser?.id ? "Delete Server" : "Leave Server", role: .destructive) {
                Task { await performDeleteOrLeave() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    @MainActor
    private func performDeleteOrLeave() async {
        guard !isDeleting else { return }
        isDeleting = true
        deleteError = nil
        defer { isDeleting = false }
        
        let serverId = server.id
        let isOwner = server.owner == viewState.currentUser?.id
        
        let result = isOwner
            ? await viewState.http.deleteServer(server: serverId)
            : await viewState.http.leaveServer(server: serverId)
        
        switch result {
        case .success:
            // Remove the server from local state and navigate away.
            viewState.servers.removeValue(forKey: serverId)
            // Drop any cached members for this server.
            viewState.members.removeValue(forKey: serverId)
            // Reset selection to DMs.
            viewState.currentSelection = .dms
            viewState.currentChannel = .home
            // Pop back through the settings navigation stack.
            if !viewState.path.isEmpty { viewState.path.removeLast() }
            dismiss()
            
        case .failure(let error):
            deleteError = isOwner
                ? "Failed to delete server. Please try again."
                : "Failed to leave server. Please try again."
            print("[Gangio] server delete/leave failed: \(error)")
        }
    }
}


#Preview {
    let viewState = AppViewState.preview()

    return NavigationStack {
        ServerSettings(server: .constant(viewState.servers["0"]!))
            .applyPreviewModifiers(withState: viewState)
    }
}
