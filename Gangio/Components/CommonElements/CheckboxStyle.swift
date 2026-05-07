//
//  CheckboxStyle.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import SwiftUI

struct CheckboxStyle: ToggleStyle {
    @EnvironmentObject var viewState: AppViewState
    
    func makeBody(configuration: Self.Configuration) -> some View {
        return HStack {
            configuration.label
            
            Spacer()
            
            if configuration.isOn {
                Image(systemName: "checkmark")
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundColor(viewState.theme.accent.color)
            }
            
        }
        .onTapGesture { configuration.isOn.toggle() }
    }
}
