//
//  ChannelIcon.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import SwiftUI
import Types

struct ChannelIcon: View {
    @EnvironmentObject var viewState: AppViewState
    
    var channel: Channel
    var withUserPresence: Bool = false
    var showLabel: Bool = true
    
    var spacing: CGFloat = 12
    var initialSize: (CGFloat, CGFloat) = (16, 16)
    var frameSize: (CGFloat, CGFloat) = (24, 24)
    
    init(channel: Channel, withUserPresence: Bool = false, showLabel: Bool = true, width: CGFloat? = nil, height: CGFloat? = nil) {
        self.channel = channel
        self.withUserPresence = withUserPresence
        self.showLabel = showLabel
        if let w = width, let h = height {
            self.initialSize = (w, h)
            self.frameSize = (w, h)
        }
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            switch channel {
                case .text_channel(let c):
                    if let icon = c.icon {
                        LazyImage(source: .file(icon), height: initialSize.0, width: initialSize.0, clipTo: Rectangle())
                            .frame(width: frameSize.0, height: frameSize.1)
                    } else {
                        Image(systemName: c.voice != nil ? "speaker.wave.2" : "number")
                            .resizable()
                            .frame(width: initialSize.0, height: initialSize.1)
                            .frame(width: frameSize.0, height: frameSize.1)
                    }
                    
                    if showLabel { Text(c.name) }
                    
                case .voice_channel(let c):
                    if let icon = c.icon {
                        LazyImage(source: .file(icon), height: initialSize.0, width: initialSize.0, clipTo: Rectangle())
                            .frame(width: frameSize.0, height: frameSize.1)
                    } else {
                        Image(systemName: "speaker.wave.2")
                            .symbolRenderingMode(.hierarchical)
                            .resizable()
                            .frame(width: initialSize.0, height: initialSize.1)
                            .frame(width: frameSize.0, height: frameSize.1)
                    }
                    
                    if showLabel { Text(c.name) }
                    
                case .group_dm_channel(let c):
                    if let icon = c.icon {
                        LazyImage(source: .file(icon), height: initialSize.0, width: initialSize.0, clipTo: Rectangle())
                            .frame(width: frameSize.0, height: frameSize.1)
                    } else {
                        Image(systemName: "number")
                            .resizable()
                            .frame(width: initialSize.0, height: initialSize.1)
                            .frame(width: frameSize.0, height: frameSize.1)
                    }
                    
                    if showLabel { Text(c.name) }
                    
                case .dm_channel(let c):
                    if let currentUserId = viewState.currentUser?.id,
                       let recipientId = c.recipients.first(where: { $0 != currentUserId }),
                       let recipient = viewState.users[recipientId] {
                        
                        AppAvatar(user: recipient, withPresence: withUserPresence)
                            .frame(width: initialSize.0, height: initialSize.1)
                            .frame(width: frameSize.0, height: frameSize.1)
                        
                        if showLabel { Text(recipient.username) }
                    } else {
                        // Fallback if data is missing
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .foregroundStyle(.gray)
                            .frame(width: initialSize.0, height: initialSize.1)
                            .frame(width: frameSize.0, height: frameSize.1)
                        
                        if showLabel {
                            Text("Unknown User")
                                .foregroundStyle(.secondary)
                        }
                    }

                case .saved_messages(_):
                    Image(systemName: "note.text")
                        .resizable()
                        .frame(width: initialSize.0, height: initialSize.1)
                        .frame(width: frameSize.0, height: frameSize.1)
                    
                    if showLabel { Text("Saved Messages") }
            }
        }
        .lineLimit(1)
    }
}

struct ChannelIcon_Preview: PreviewProvider {
    static var viewState: AppViewState = AppViewState.preview()
    
    static var previews: some View {
        ChannelIcon(channel: viewState.channels["0"]!)
            .previewLayout(.sizeThatFits)
    }
}

