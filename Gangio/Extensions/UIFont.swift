//
//  UIFont.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import UIKit

extension UIFont {
    func bottomOffsetFromBaselineForVerticalCentering(targetHeight height: CGFloat) -> CGFloat {
        let textHeight = ascender - descender
        let offset = (textHeight - height) / 2 + descender
        return offset
    }
}
