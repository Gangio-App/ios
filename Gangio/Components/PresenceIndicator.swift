//
//  PresenceIndicator.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import SwiftUI
import Types

let colours: [Presence?: Color] = [
    .Online: Color(.green),
    .Busy: Color(.red),
    .Idle: Color(.yellow),
    .Focus: Color(.blue),
    .Invisible: Color(.gray),
    nil: Color(.gray)
]

struct PresenceIndicator: View {
    var presence: Presence?
    var width: CGFloat? = nil
    var height: CGFloat? = nil
    
    var body: some View {
        let colour = colours[presence]!
        
        Circle()
            .fill(colour)
            .frame(width: width, height: height)
    }
}
