//
//  EnvironmentValues.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import SwiftUI
import Types

extension EnvironmentValues {
    @Entry var currentMessage: MessageContentsViewModel? = nil
    @Entry var currentServer: Server? = nil
    @Entry var currentChannel: Channel? = nil
    @Entry var channelMessageSelection: Binding<Set<String>> = .constant([])
}
