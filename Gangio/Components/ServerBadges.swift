//
//  ServerBadges.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import SwiftUI
import Types

struct ServerBadges: View {
    var value: ServerFlags?
    
    var body: some View {
        if value?.contains(.offical) == true {
            ZStack(alignment: .center) {
                Image(systemName: "seal.fill")
                    .resizable()
                    .frame(width: 12, height: 12)
                    .foregroundStyle(.white)
                
                Image("monochrome")
                    .resizable()
                    .frame(width: 10, height: 10)
                    .colorInvert()
            }
        } else if value?.contains(.verified) == true {
            Image(systemName: "checkmark.seal.fill")
                .resizable()
                .foregroundStyle(.black, .white)
                .frame(width: 12, height: 12)
        }
    }
}
