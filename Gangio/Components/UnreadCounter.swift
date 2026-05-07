//
//  UnreadCounter.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import SwiftUI
import Types

struct UnreadCounter: View {
    @EnvironmentObject var viewState: AppViewState
    var unread: UnreadCount
    var mentionSize: CGFloat = 24
    var unreadSize: CGFloat = 8
    
    var body: some View {
        switch unread {
            case .mentions(let count):
                ZStack(alignment: .center) {
                    Circle()
                        .frame(width: mentionSize, height: mentionSize)
                        .foregroundStyle(.red)
                    Text("\(count)")
                        .foregroundStyle(.white)
                }
                
            case .unread:
                Circle()
                    .frame(width: unreadSize, height: unreadSize)
                    .foregroundStyle(viewState.theme.foreground.color)
        }
    }
}
