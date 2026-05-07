//
//  MessageBadge.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import SwiftUI
import Types

struct MessageBadge: View {
    var text: String
    var color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(color, in: RoundedRectangle(cornerRadius: 5))
    }
}

#Preview {
    MessageBadge(text: "Masquerade", color: .teal)
}

#Preview {
    MessageBadge(text: "Bot", color: .purple)
}
