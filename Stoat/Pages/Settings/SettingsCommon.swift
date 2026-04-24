//
//  SettingsCommon.swift
//  Revolt
//
//  Created by Angelo on 2024-02-10.
//

import SwiftUI

fileprivate struct SettingsFieldTextField: View {
    var body: some View {
        Text("Text Field")
    }
}

struct SettingFieldNavigationItem: View {
    @EnvironmentObject var viewState: ViewState
    
    @State var includeValueIfAvailable: Bool

    var body: some View {
        Text("Hello, World!")
    }
}

struct SettingsSheetContainer<Content: View>: View {
    @EnvironmentObject var viewState: ViewState
    
    @Binding var showSheet: Bool
    @ViewBuilder var sheet: () -> Content
    
    var body: some View {
        NavigationView {
            sheet()
                .padding()
                .backgroundStyle(viewState.theme.background)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            showSheet = false
                        } label: {
                            Text("Cancel")
                        }
                    }
                }
        }
    }
}

struct MaybeDismissableSettingsSheetContainer<Content: View>: View {
    @EnvironmentObject var viewState: ViewState
    
    @Binding var showSheet: Bool
    @Binding var sheetDismissDisabled: Bool
    @ViewBuilder var sheet: () -> Content
    
    var body: some View {
        NavigationView {
            sheet()
                .padding()
                .backgroundStyle(viewState.theme.background)
                .interactiveDismissDisabled(sheetDismissDisabled)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            showSheet = false
                        } label: {
                            Text("Cancel")
                        }
                    }
                }
        }
    }
}


struct CheckboxListItem: View {
    @EnvironmentObject var viewState: ViewState

    @State var title: String
    @Binding var isOn: Bool
    var willChange: ( (Bool) -> (Bool) )?
    var onChange: ( (Bool) -> Void )?
    
    init(title: String, isOn: Bool, onChange: ((Bool) -> Void)? = nil, willChange: ((Bool) -> Bool)? = nil) {
        self._title = State(initialValue: title)
        self._isOn = .constant(isOn)
        self.onChange = onChange
        self.willChange = willChange
    }
    
    init(title: String, isOn: Binding<Bool>, onChange: ((Bool) -> Void)? = nil, willChange: ((Bool) -> Bool)? = nil) {
        self._title = State(initialValue: title)
        self._isOn = isOn
        self.onChange = onChange
        self.willChange = willChange
    }
    
    private func prepareChange() {
        if willChange != nil {
            if !willChange!(isOn) {
                isOn = !isOn
                return
            }
        }
        
        if onChange != nil {
            onChange!(isOn)
        }
    }
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(viewState.theme.foreground)
            Spacer()
            Toggle(isOn: $isOn) {}
                .toggleStyle(.switch)
        }
        .onTapGesture {
            isOn = !isOn
        }
        .onChange(of: isOn) {
            prepareChange()
        }
        
        .backgroundStyle(viewState.theme.background2)
    }
}

// MARK: - Premium Settings Container
struct SettingsSectionView<Content: View>: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(LocalizedStringKey(title.uppercased()))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.gray.opacity(0.8))
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                content
            }
            .background(.ultraThinMaterial.opacity(0.8))
            .background(colorScheme == .dark ? Color.white.opacity(0.02) : Color.black.opacity(0.01))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.05), lineWidth: 1)
            )
        }
    }
}

