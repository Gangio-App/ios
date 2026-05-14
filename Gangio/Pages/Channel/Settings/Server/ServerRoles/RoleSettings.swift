//
//  RoleSettings.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import Types
import SwiftUI


struct RoleSettings: View {
    @EnvironmentObject var viewState: AppViewState
    
    @Binding var server: Server
    var roleId: String
    @State var initial: Role
    @State var currentValue: Role
    @State var showAdvancedColourSheet: Bool = false
    
    @State var cachedRoleColor: CssColor? = nil

    init(server s: Binding<Server>, roleId: String, role: Role) {
        self._server = s
        self.roleId = roleId
        self.initial = role
        self.currentValue = role
    }
    
    var body: some View {
        List {
            Section("Role Name") {
                TextField(text: $currentValue.name) {
                    Text("Role Name")
                }
            }
            .listRowBackground(viewState.theme.background3)
            
            Section("Role Colour") {
                HStack {
                    TextField(text: $currentValue.colour.bindOr(defaultTo: "")) {
                        Text("Role Colour")
                    }
                    
                    Circle()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(currentValue.colour.map { parseCSSColorToShapeStyle(currentTheme: viewState.theme, input: $0) } ?? AnyShapeStyle(viewState.theme.foreground))

                }
                .listRowSeparator(.hidden)
                
                Button("Advanced Color options") {
                    showAdvancedColourSheet.toggle()
                }
                .foregroundStyle(viewState.theme.accent)
                .listRowBackground(viewState.theme.background2)
            }
            .listRowBackground(viewState.theme.background3)
            
            CheckboxListItem(title: "Hoist role", isOn: $currentValue.hoist.bindOr(defaultTo: false))
                .listRowBackground(viewState.theme.background2)
            
            Section("Role Rank") {
                TextField(value: $currentValue.rank, format: .number) {
                    Text("Role Name")
                }
            }
            .listRowBackground(viewState.theme.background3)
            
            Section("Edit Permissions") {
                AllPermissionSettings(permissions: .role($currentValue.permissions))
            }
            .listRowBackground(viewState.theme.background2)
            
            Button {
                Task {
                    try! await viewState.http.deleteRole(server: server.id, role: roleId).get()
                }
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Delete role")
                }
                .foregroundStyle(.red)
            }
            .listRowBackground(viewState.theme.background2)
        }
        .scrollContentBackground(.hidden)
        .background(viewState.theme.background)
        .sheet(isPresented: $showAdvancedColourSheet) {
            ColorSheet(value: Binding(
                get: { parseCSSColor(input: currentValue.colour ?? "", default: cachedRoleColor) },
                set: { value in
                    cachedRoleColor = value
                    currentValue.colour = convertCSSColorToString(input: value)
                }
            ))
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(verbatim: initial.name)
                    .bold()
                    .foregroundStyle(initial.colour.map { parseCSSColorToShapeStyle(currentTheme: viewState.theme, input: $0) } ?? AnyShapeStyle(viewState.theme.foreground))
            }
            
#if os(iOS)
            let placement = ToolbarItemPlacement.topBarTrailing
#elseif os(macOS)
            let placement = ToolbarItemPlacement.automatic
#endif
            ToolbarItem(placement: placement) {
                if initial != currentValue {
                    Button {
                        Task { await saveRole() }
                    } label: {
                        Text("Save")
                            .foregroundStyle(viewState.theme.accent)
                    }
                }
            }
        }
    }
    
    @MainActor
    private func saveRole() async {
        var payload = RoleEditPayload()
        
        if initial.name != currentValue.name {
            payload.name = currentValue.name
        }
        
        if initial.colour != currentValue.colour {
            if currentValue.colour == nil || currentValue.colour == "" {
                if payload.remove == nil { payload.remove = [] }
                payload.remove!.append(.colour)
            } else {
                payload.colour = currentValue.colour
            }
        }
        
        if initial.hoist != currentValue.hoist {
            payload.hoist = currentValue.hoist
        }
        
        if initial.rank != currentValue.rank {
            payload.rank = currentValue.rank
        }
        
        // Edit role properties (name/colour/hoist/rank) — handle errors gracefully.
        let editResult = await viewState.http.editRole(server: server.id, role: roleId, payload: payload)
        guard case .success(var updatedRole) = editResult else {
            print("[Gangio] editRole failed: \(editResult)")
            return
        }
        
        // Apply permission changes if any
        if initial.permissions != currentValue.permissions {
            let permResult = await viewState.http.setRolePermissions(server: server.id, role: roleId, overwrite: currentValue.permissions)
            if case .success = permResult {
                updatedRole.permissions = currentValue.permissions
            }
        }
        
        // Persist locally so all places (chat, settings, etc.) reflect the new role colour.
        if viewState.servers[server.id] != nil {
            viewState.servers[server.id]?.roles?[roleId] = updatedRole
            // Also update the local @Binding copy so this view's state is in sync.
            server.roles?[roleId] = updatedRole
        }
        
        initial = updatedRole
        currentValue = updatedRole
    }
}
