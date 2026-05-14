//
//  Permissions.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import Types

func resolveServerPermissions(user: User, member: Member, server: Server) -> Permissions {
    if user.privileged == true || server.owner == user.id {
        return Permissions.all
    }
    
    var permissions = server.default_permissions
    
    for role in member.roles?
        .compactMap({ server.roles?[$0] })
        .sorted(by: { $0.rank < $1.rank }) ?? []
    {
        permissions.formApply(overwrite: role.permissions)
    }
    
    if member.timeout != nil {
        permissions = permissions.intersection(Permissions.defaultAllowInTimeout)
    }

    return permissions
}

func resolveChannelPermissions(from: User, targettingUser user: User, targettingMember member: Member?, channel: Channel, server: Server?) -> Permissions {
    if user.privileged == true || server?.owner == user.id {
        return Permissions.all
    }
    
    switch channel {
        case .saved_messages(let savedMessages):
            if savedMessages.user == user.id {
                return Permissions.all
            } else {
                return Permissions.none
            }
        case .dm_channel(let dMChannel):
            if dMChannel.recipients.contains(user.id) {
                let userPermissions = resolveUserPermissions(from: from, targetting: user)
                
                if userPermissions.contains(UserPermissions.sendMessage) {
                    return Permissions.defaultDirectMessages
                } else {
                    return Permissions.defaultViewOnly
                }
            } else {
                return Permissions.none
            }
        case .group_dm_channel(let groupDMChannel):
            if groupDMChannel.owner == user.id {
                return Permissions.all
            } else if groupDMChannel.recipients.contains(user.id) {
                return Permissions.defaultViewOnly.union(groupDMChannel.permissions ?? Permissions.none)
            } else {
                return Permissions.none
            }
        case .text_channel(let textChannel):
            // Without a server we can't resolve role-based perms; without a
            // member the user isn't part of the server. Either way, deny.
            // (Previously this force-unwrapped `server!`/`member!` and would
            // crash for channels the user hadn't joined yet.)
            guard let server, let member else { return Permissions.none }
            if server.owner == user.id {
                return Permissions.all
            }
            
            // Discord-style baseline: every member starts with the standard
            // "default" perms (view + read history + send + embeds + upload +
            // invite + connect + speak). Channel admins lock things down by
            // adding explicit DENY overwrites — nothing-defined means
            // nothing-restricted. Without this baseline, a server whose
            // `default_permissions` happen to omit `sendMessages` (the common
            // case for permission-tightened community servers) would silently
            // lock everyone out of every channel they hadn't been explicitly
            // granted.
            let serverPerms = resolveServerPermissions(user: user, member: member, server: server)
            var permissions = serverPerms.union(Permissions.default)
            
            if let defaultPermissions = textChannel.default_permissions {
                permissions.formApply(overwrite: defaultPermissions)
            }
            
            let overwrites = textChannel.role_permissions?
                .compactMap({ (id, overwrite) in
                    guard let role = server.roles?[id] else {
                        return nil
                    }
                    
                    return (role, overwrite)
                })
                .sorted(by: { (a, b) in a.0.rank < b.0.rank})
                ?? ([] as [(Role, Overwrite)])
            
            for (_, overwrite) in overwrites {
                permissions.formApply(overwrite: overwrite)
            }
            
            if member.timeout != nil {
                permissions.formIntersection(Permissions.defaultAllowInTimeout)
            }
            
            if !permissions.contains(Permissions.viewChannel) {
                permissions = Permissions.none
            }
            
            return permissions
    
        case .voice_channel(let voiceChannel):
            guard let server, let member else { return Permissions.none }
            if server.owner == user.id {
                return Permissions.all
            }
            
            let hasChannelOverrides = voiceChannel.default_permissions != nil
                || !(voiceChannel.role_permissions?.isEmpty ?? true)
            let serverPerms = resolveServerPermissions(user: user, member: member, server: server)
            var permissions = hasChannelOverrides ? serverPerms : serverPerms.union(Permissions.default)
            
            if let defaultPermissions = voiceChannel.default_permissions {
                permissions.formApply(overwrite: defaultPermissions)
            }
            
            let overwrites = voiceChannel.role_permissions?
                .compactMap({ (id, perm) in server.roles?[id].map { role in (role, perm) } })
                .sorted(by: {$0.0.rank < $1.0.rank}) ?? []
            
            for (_, overwrite) in overwrites {
                permissions.formApply(overwrite: overwrite)
            }
            
            if member.timeout != nil {
                permissions.formIntersection(Permissions.defaultAllowInTimeout)
            }
            
            if !permissions.contains(Permissions.viewChannel) {
                permissions = Permissions.none
            }
            
            return permissions
    }
}

func resolveUserPermissions(from: User, targetting: User) -> UserPermissions {
    if from.privileged == true {
        return UserPermissions.all
    }
    
    if from.id == targetting.id {
        return UserPermissions.all
    }
    
    var permissions = UserPermissions.none
    
    // `from` will only ever be ourself so we can rely on .relationship being correct
    switch targetting.relationship {
        case .Blocked, .BlockedOther:
            return UserPermissions.access
        case .Friend:
            return UserPermissions.all
        case .Incoming, .Outgoing:
            permissions = UserPermissions.access.union(UserPermissions.viewProfile)
        default:
            ()
    }
    
    if from.bot != nil || targetting.bot != nil {
        permissions = permissions.union(UserPermissions.sendMessage)
    }
    
    return permissions
}
