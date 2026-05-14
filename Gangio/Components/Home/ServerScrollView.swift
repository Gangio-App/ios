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
    @AppStorage("customServerOrder") private var customServerOrderJson: String = "[]"
    
    // Drag & drop state
    @State private var draggingId: String? = nil
    @State private var dragOffset: CGSize = .zero
    @State private var isReorderMode: Bool = false
    
    private var isDark: Bool {
        !Theme.isLightOrDark(viewState.theme.background)
    }
    
    /// Custom-ordered server elements based on UserDefaults preferences.
    private var orderedServers: [(key: String, value: Server)] {
        let stored = (try? JSONDecoder().decode([String].self, from: Data(customServerOrderJson.utf8))) ?? []
        let allElements = viewState.servers.elements
        let allServerIds = Set(allElements.map { $0.key })
        let orderedIds = stored.filter { allServerIds.contains($0) }
        let orderedSet = Set(orderedIds)
        // Append any new servers not in custom order
        let leftovers = allElements.filter { !orderedSet.contains($0.key) }.map { $0.key }
        let finalOrder = orderedIds + leftovers
        let dict: [String: Server] = Dictionary(uniqueKeysWithValues: allElements.map { ($0.key, $0.value) })
        return finalOrder.compactMap { id in
            guard let server = dict[id] else { return nil }
            return (key: id, value: server)
        }
    }
    
    private func saveOrder(_ ids: [String]) {
        if let data = try? JSONEncoder().encode(ids), let str = String(data: data, encoding: .utf8) {
            customServerOrderJson = str
        }
    }
    
    /// Calculates the target index based on drag position and swaps if needed.
    private func handleDragReorder(draggedId: String, translation: CGFloat) {
        var ids = orderedServers.map { $0.key }
        guard let currentIdx = ids.firstIndex(of: draggedId) else { return }
        
        // Each icon is iconSize + 12pt spacing
        let slotWidth = iconSize + 12
        let slotsToMove = Int(round(translation / slotWidth))
        let targetIdx = min(max(currentIdx + slotsToMove, 0), ids.count - 1)
        
        if targetIdx != currentIdx {
            ids.remove(at: currentIdx)
            ids.insert(draggedId, at: targetIdx)
            saveOrder(ids)
            // Reset offset relative to new position
            let diff = targetIdx - currentIdx
            dragOffset.width -= CGFloat(diff) * slotWidth
        }
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
                
                // Server icons with drag & drop
                ForEach(Array(orderedServers.enumerated()), id: \.element.key) { idx, elem in
                    let isDragging = draggingId == elem.key
                    
                    Button {
                        if !isReorderMode {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                viewState.selectServer(withId: elem.key)
                            }
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
                    .scaleEffect(isDragging ? 1.12 : 1.0)
                    .opacity(isDragging ? 0.85 : 1.0)
                    .zIndex(isDragging ? 100 : 0)
                    .offset(isDragging ? dragOffset : .zero)
                    .rotationEffect(isReorderMode && !isDragging ? .degrees(Double.random(in: -1.5...1.5)) : .zero)
                    .animation(isReorderMode ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true) : .default, value: isReorderMode)
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.4)
                            .onEnded { _ in
                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                impact.impactOccurred()
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                    isReorderMode = true
                                    draggingId = elem.key
                                }
                            }
                            .sequenced(before: DragGesture(minimumDistance: 0))
                            .onChanged { value in
                                switch value {
                                case .second(true, let drag):
                                    if let drag = drag, draggingId == elem.key {
                                        dragOffset = CGSize(width: drag.translation.width, height: 0)
                                    }
                                default:
                                    break
                                }
                            }
                            .onEnded { value in
                                if draggingId == elem.key {
                                    handleDragReorder(draggedId: elem.key, translation: dragOffset.width)
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        draggingId = nil
                                        dragOffset = .zero
                                        isReorderMode = false
                                    }
                                }
                            }
                    )
                    .contextMenu {
                        Text(elem.value.name).font(.headline)
                        Button {
                            saveOrder([])
                        } label: {
                            Label("Reset Order", systemImage: "arrow.uturn.backward.circle")
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
