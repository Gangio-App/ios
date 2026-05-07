//
//  Image.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import SwiftUI
import Types

extension Image {
    /// Inverts the image depending on the lightness of color
    /// This is specifically designed for use in the sessions settings menu
    @ViewBuilder
    public func maybeColorInvert(color: ThemeColor, isDefaultImage: Bool, defaultIsLight: Bool = true) -> some View {
        if isDefaultImage {
            self
        } else {
            let isLight = Theme.isLightOrDark(color)
            
            if isLight && defaultIsLight {
                self.colorInvert()
            } else if !isLight && !defaultIsLight {
                self.colorInvert()
            } else {
                self
            }
        }
    }
}
