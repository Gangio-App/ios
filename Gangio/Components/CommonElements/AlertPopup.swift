//
//  AlertPopup.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import SwiftUI

struct AlertPopup<C: View, P: View>: View {
    @EnvironmentObject var viewState: AppViewState
    
    var show: Bool
    var inner: C
    var popup: () -> P
    
    var body: some View {
        inner.overlay {
            if show {
                popup()
                    .fontWeight(.semibold)
                    .foregroundStyle(viewState.theme.foreground)
                    .padding()
                    .padding(.bottom, 38)
                    .shadow(radius: 5)
                    .transition(.move(edge: .bottom))
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
    }
}
