//
//  Section.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import SwiftUI


extension Section {
    init(_ title: String, content: @escaping () -> Content, footer: @escaping () -> Footer) where Parent == Text, Content: View, Footer: View {
        self.init(content: content, header: { Text(title) }, footer: footer)
    }
}
