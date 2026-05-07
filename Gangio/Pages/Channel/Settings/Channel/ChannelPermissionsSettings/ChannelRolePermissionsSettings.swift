//
//  ChannelRolePermissionsSettings.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import SwiftUI
import Types

struct ChannelRolePermissionsSettings: View {
    @EnvironmentObject var viewState: AppViewState
    
    enum Value: Equatable {
        case permission(Permissions)
        case overwrite(Overwrite)
    }
    
    @Binding var server: Server
    @Binding var channel: Channel
    
    var roleId: String?
    @State var initial: Value
    @State var currentValue: Value
    
    init(server: Binding<Server>, channel: Binding<Channel>, roleId: String?, permissions: Value) {
        self._server = server
        self._channel = channel
        self.roleId = roleId
        self.initial = permissions
        self.currentValue = permissions
    }
    
    var permissionBinding: AllPermissionSettings.RolePermissions {
        switch currentValue {
            case .permission(let permissions):
                    return .defaultRole(Binding {
                        permissions
                    } set: {
                        currentValue = .permission($0)
                    })
            case .overwrite(let overwrite):
                    return .role(Binding {
                        overwrite
                    } set: {
                        currentValue = .overwrite($0)
                    })
        }
    }
    
    var body: some View {
        List {
            AllPermissionSettings(
                permissions: permissionBinding,
                filter: [.viewChannel, .readMessageHistory, .sendMessages, .manageMessages, .inviteOthers, .sendEmbeds, .uploadFiles, .masquerade, .react, .manageChannel, .managePermissions]
            )
                .listRowBackground(viewState.theme.background2)
        }
        .scrollContentBackground(.hidden)
        .background(viewState.theme.background)
        .toolbar {
#if os(iOS)
            let placement = ToolbarItemPlacement.topBarTrailing
#elseif os(macOS)
            let placement = ToolbarItemPlacement.automatic
#endif
            ToolbarItem(placement: placement) {
                if initial != currentValue {
                    Button {
                        Task {
                            var output: Result<Channel, GangioError>? = nil
                            
                            if let roleId {
                                switch currentValue {
                                    case .permission(let permissions):
                                        ()  // unreachable
                                    case .overwrite(let overwrite):
                                        output = await viewState.http.setRoleChannelPermissions(channel: channel.id, role: roleId, overwrite: overwrite)
                                }
                            } else {
                                switch currentValue {
                                    case .permission(let permissions):
                                        output = await viewState.http.setDefaultRoleChannelPermissions(channel: channel.id, permissions: permissions)
                                    case .overwrite(let overwrite):
                                        output = await viewState.http.setDefaultRoleChannelPermissions(channel: channel.id, overwrite: overwrite)
                                }
                            }
                            
                            if let output, let channel = try? output.get() {
                                initial = currentValue
                            }
                        }
                    } label: {
                        Text("Save")
                            .foregroundStyle(viewState.theme.accent)
                    }
                }
                
            }
        }
        .toolbarBackground(viewState.theme.topBar.color, for: .automatic)
    }
}
