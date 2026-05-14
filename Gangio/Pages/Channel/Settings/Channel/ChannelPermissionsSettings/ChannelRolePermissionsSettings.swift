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
        // IMPORTANT: the getters MUST read from `currentValue`, not from the
        // pattern-matched local. The local is captured at body-eval time and
        // becomes stale the moment the user toggles a permission, which made
        // every toggle silently snap back to its initial state — and made
        // `initial != currentValue` true only briefly, so Save would
        // sometimes appear and other times not. Reading `currentValue` keeps
        // the binding live across renders.
        switch currentValue {
            case .permission:
                return .defaultRole(Binding {
                    if case .permission(let p) = currentValue { return p }
                    return .none
                } set: {
                    currentValue = .permission($0)
                })
            case .overwrite:
                return .role(Binding {
                    if case .overwrite(let o) = currentValue { return o }
                    return Overwrite(a: .none, d: .none)
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
                            
                            // Sanitize: the backend rejects an Override whose
                            // `allow` and `deny` masks share any bit with
                            // `InvalidOperation`. The UI's 3-state toggle
                            // keeps these disjoint when the user actually
                            // touches a permission, but legacy roles whose
                            // DB rows already contained an overlap would
                            // keep failing forever — so strip deny of any
                            // bit that's also allowed before sending.
                            func sanitize(_ o: Overwrite) -> Overwrite {
                                var copy = o
                                copy.d = copy.d.subtracting(copy.a)
                                return copy
                            }
                            
                            if let roleId {
                                switch currentValue {
                                    case .permission:
                                        ()  // unreachable: per-role always uses overwrite
                                    case .overwrite(let overwrite):
                                        output = await viewState.http.setRoleChannelPermissions(channel: channel.id, role: roleId, overwrite: sanitize(overwrite))
                                }
                            } else {
                                switch currentValue {
                                    case .permission(let permissions):
                                        output = await viewState.http.setDefaultRoleChannelPermissions(channel: channel.id, permissions: permissions)
                                    case .overwrite(let overwrite):
                                        output = await viewState.http.setDefaultRoleChannelPermissions(channel: channel.id, overwrite: sanitize(overwrite))
                                }
                            }
                            
                            // Surface failures: previously `try?` swallowed
                            // every backend error (403 from missing
                            // ManagePermissions, 400 from a malformed body,
                            // network drop, ...) and the Save button just
                            // disappeared as if it had worked, leaving the
                            // server unchanged. Log so the failure mode is
                            // at least visible during debugging.
                            switch output {
                                case .success(let updated):
                                    // Mirror the new channel into the global
                                    // store *and* the parent's binding so the
                                    // sidebar / message box / permission
                                    // overview reflect the change immediately
                                    // — without waiting for a websocket
                                    // ChannelUpdate round-trip (which never
                                    // arrived for some self-targeted edits).
                                    viewState.channels[updated.id] = updated
                                    channel = updated
                                    initial = currentValue
                                case .failure(let err):
                                    print("[Gangio] channel permission save failed: \(err)")
                                case .none:
                                    print("[Gangio] channel permission save produced no request (unreachable branch)")
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
