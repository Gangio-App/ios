//
//  ServerCategoriesSettings.swift
//  Gangio
//

import SwiftUI
import Types

struct ServerCategoriesSettings: View {
    @EnvironmentObject var viewState: AppViewState
    @Binding var server: Server
    
    @State private var showAddCategory = false
    @State private var newCategoryName = ""
    
    var body: some View {
        ZStack {
            viewState.theme.background.color.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 12) {
                    // Add new category button
                    Button {
                        showAddCategory = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(viewState.theme.accent.color)
                            Text("New Category")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(viewState.theme.foreground.color)
                            Spacer()
                        }
                        .padding(14)
                        .background(viewState.theme.background2.color)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    
                    // Existing categories
                    if let categories = server.categories, !categories.isEmpty {
                        ForEach(categories) { category in
                            categoryCard(category: category)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(viewState.theme.foreground3.color)
                            Text("No categories yet")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(viewState.theme.foreground.color)
                            Text("Group your channels by creating categories.")
                                .font(.system(size: 12))
                                .foregroundStyle(viewState.theme.foreground3.color)
                                .multilineTextAlignment(.center)
                        }
                        .padding(24)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .alert("New Category", isPresented: $showAddCategory) {
            TextField("Category name", text: $newCategoryName)
            Button("Cancel", role: .cancel) { newCategoryName = "" }
            Button("Create") {
                Task { await createCategory() }
            }
        }
    }
    
    @ViewBuilder
    private func categoryCard(category: Types.Category) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(viewState.theme.accent.color)
                Text(category.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(viewState.theme.foreground.color)
                Spacer()
                Text("\(category.channels.count) channels")
                    .font(.system(size: 11))
                    .foregroundStyle(viewState.theme.foreground3.color)
            }
            
            if !category.channels.isEmpty {
                ForEach(category.channels.compactMap { viewState.channels[$0] }, id: \.id) { channel in
                    HStack(spacing: 8) {
                        ChannelIcon(channel: channel)
                        Spacer()
                    }
                    .padding(.leading, 12)
                }
            }
        }
        .padding(12)
        .background(viewState.theme.background2.color)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func createCategory() async {
        let name = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        
        var categories = server.categories ?? []
        let newCategory = Types.Category(
            id: UUID().uuidString.replacingOccurrences(of: "-", with: ""),
            title: name,
            channels: []
        )
        categories.append(newCategory)
        
        var edit = ServerEdit()
        edit.categories = categories
        let result = await viewState.http.editServer(server: server.id, edits: edit)
        if case .success(let updated) = result {
            await MainActor.run {
                server = updated
                viewState.servers[updated.id] = updated
                newCategoryName = ""
            }
        }
    }
}
