//
//  VoiceChannelBox.swift
//  Gangio
//
//  Created by Angelo on 27/01/2025.
//

import SwiftUI

struct VoiceChannelBox<Title: View, Contents: View, Trailing: View, Overlay: View>: View {
    @EnvironmentObject var viewState: AppViewState
    
    var title: Title
    var contents: Contents
    var trailing: Trailing?
    var overlay: Overlay?
    
    @State var selected: Bool = false
    
    init(@ViewBuilder title: () -> Title, @ViewBuilder contents: () -> Contents, @ViewBuilder trailing: () -> Trailing, @ViewBuilder overlay: () -> Overlay) {
        self.title = title()
        self.contents = contents()
        self.trailing = trailing()
        self.overlay = overlay()
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            contents
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(0)
            
            // Info Bar
            HStack {
                title
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                
                Spacer()
                
                if let trailing {
                    trailing
                }
            }
            .padding(10)
            .background(LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom))
            .zIndex(1)
            
            if selected && overlay != nil {
                overlay
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .background(viewState.theme.background2.color)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .onTapGesture { withAnimation { selected.toggle() } }
    }
}

extension VoiceChannelBox where Title == Text {
    init(
        title: String,
        @ViewBuilder contents: @escaping () -> Contents,
        @ViewBuilder trailing: @escaping () -> Trailing,
        @ViewBuilder overlay: @escaping () -> Overlay
    ) {
        self.title = Text(title)
        self.contents = contents()
        self.trailing = trailing()
        self.overlay = overlay()
    }
    
    init(
        title: String,
        @ViewBuilder contents: @escaping () -> Contents,
        @ViewBuilder trailing: @escaping () -> Trailing
    )
        where Overlay == EmptyView
    {
        self.title = Text(title)
        self.contents = contents()
        self.trailing = trailing()
        self.overlay = nil
    }
    
    init(
        title: String,
        @ViewBuilder contents: @escaping () -> Contents,
        @ViewBuilder overlay: @escaping () -> Overlay
    )
        where Trailing == EmptyView
    {
        self.title = Text(title)
        self.contents = contents()
        self.trailing = nil
        self.overlay = overlay()
    }
    
    init(
        title: String, @ViewBuilder
        contents: @escaping () -> Contents
    )
        where Trailing == EmptyView,
              Overlay == EmptyView
    {
        self.title = Text(title)
        self.contents = contents()
        self.trailing = nil
        self.overlay = nil
    }
}

extension VoiceChannelBox where Trailing == EmptyView {
    init(
        @ViewBuilder title: () -> Title,
        @ViewBuilder contents: () -> Contents,
        @ViewBuilder overlay: () -> Overlay
    ) {
        self.title = title()
        self.contents = contents()
        self.trailing =  nil
        self.overlay = overlay()
    }
}
