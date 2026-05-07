//
//  ServerScrollView.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import SwiftUI
import Types

// MARK: - Horizontal Server Strip (Discord-style top row)
struct HorizontalServerStrip: View {
    @EnvironmentObject var viewState: AppViewState
    let iconSize: CGFloat = 54
    
    @State var showAddServerSheet = false
    
    private var isDark: Bool {
        !Theme.isLightOrDark(viewState.theme.background)
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // DMs / Home button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewState.selectDms()
                    }
                } label: {
                    let isSelected = viewState.currentSelection == .dms
                    ZStack {
                        Circle()
                            .fill(isSelected ? viewState.theme.accent.color : viewState.theme.background3.color)
                            .frame(width: iconSize, height: iconSize)
                        
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(isSelected ? .white : viewState.theme.foreground2.color)
                    }
                    .overlay(
                        Circle()
                            .stroke(isSelected ? viewState.theme.accent.color.opacity(0.6) : .clear, lineWidth: 2.5)
                            .frame(width: iconSize + 4, height: iconSize + 4)
                    )
                }
                
                // Server icons
                ForEach(viewState.servers.elements, id: \.key) { elem in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewState.selectServer(withId: elem.key)
                        }
                    } label: {
                        let isSelected = viewState.currentSelection == .server(elem.key)
                        
                        ZStack(alignment: .topTrailing) {
                            ServerIcon(
                                server: elem.value,
                                height: iconSize,
                                width: iconSize,
                                clipTo: Circle()
                            )
                            .overlay(
                                Circle()
                                    .stroke(isSelected ? viewState.theme.accent.color.opacity(0.8) : .clear, lineWidth: 2.5)
                                    .frame(width: iconSize + 4, height: iconSize + 4)
                            )
                            
                            // Unread badge
                            if let unread = viewState.getUnreadCountFor(server: elem.value) {
                                UnreadCounter(unread: unread, mentionSize: 18, unreadSize: 8)
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                }
                
                // + Add server button (always at end)
                Button {
                    showAddServerSheet.toggle()
                } label: {
                    ZStack {
                        Circle()
                            .fill(viewState.theme.background3.color)
                            .frame(width: iconSize, height: iconSize)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(viewState.theme.accent.color)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .sheet(isPresented: $showAddServerSheet) {
            AddServerSheet()
        }
    }
}

// MARK: - Legacy vertical ServerScrollView (kept for iPad/Mac)
struct ServerScrollView: View {
    let buttonSize = 44.0
    let viewWidth = 60.0
    
    @EnvironmentObject var viewState: AppViewState
    
    @State var showAddServerSheet = false
    
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                Spacer()
                    .frame(height: buttonSize + 12 + 8)
                Section {
                    ForEach(viewState.servers.elements, id: \.key) { elem in
                        Button {
                            withAnimation {
                                viewState.selectServer(withId: elem.key)
                            }
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                ServerListIcon(server: elem.value, height: buttonSize, width: buttonSize, currentSelection: $viewState.currentSelection)
                                
                                if let unread = viewState.getUnreadCountFor(server: elem.value) {
                                    ZStack(alignment: .center) {
                                        Circle()
                                            .foregroundStyle(.black)
                                            .frame(width: (buttonSize / 3) + 6, height: (buttonSize / 3) + 6)
                                            .blendMode(.destinationOut)
                                        
                                        UnreadCounter(unread: unread, mentionSize: buttonSize / 2.5, unreadSize: buttonSize / 3)
                                            .background(viewState.theme.foreground)
                                            .containerShape(Circle())
                                    }
                                    .padding(.top, -2)
                                    .padding(.trailing, -2)
                                }
                            }
                            .compositingGroup()
                        }
                        .padding(.vertical, 2)
                    }
                }
                
                Divider()
                    .frame(height: 12)
                
                Section {
                    Button {
                        showAddServerSheet.toggle()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(viewState.theme.accent.color, viewState.theme.background2.color)
                            .frame(width: buttonSize, height: buttonSize)
                            .font(.system(size: buttonSize))
                    }
                    
                    NavigationLink(value: NavigationDestination.discover) {
                        Image(systemName: "safari.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(viewState.theme.accent.color, viewState.theme.background2.color)
                            .frame(width: buttonSize, height: buttonSize)
                            .font(.system(size: buttonSize))
                    }
                    
                    NavigationLink(value: NavigationDestination.settings) {
                        Image(systemName: "gearshape.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(viewState.theme.accent.color, viewState.theme.background2.color)
                            .frame(width: buttonSize, height: buttonSize)
                            .font(.system(size: buttonSize))
                    }
                }
                
                // Buffer to prevent BottomBar overlap
                Spacer()
                    .frame(height: 120)
            }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            
            VStack {
                Button {
                    viewState.selectDms()
                } label: {
                    if viewState.currentUser != nil {
                        AppAvatar(user: viewState.currentUser!, width: buttonSize, height: buttonSize, withPresence: true)
                            .frame(width: buttonSize, height: buttonSize)
                    }
                }
                
                Divider()
            }
            .background(viewState.theme.background)
        }
        .padding(.horizontal, viewWidth - buttonSize)
        .background(viewState.theme.background)
        .sheet(isPresented: $showAddServerSheet) {
            AddServerSheet()
        }
    }
}

#Preview(traits: .fixedLayout(width: 60, height: 500)) {
    ServerScrollView()
        .applyPreviewModifiers(withState: AppViewState.preview().applySystemScheme(theme: .light))
}
