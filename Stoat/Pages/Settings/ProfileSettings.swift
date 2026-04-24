//
//  ProfileSettings.swift
//  Revolt
//
//  Created by Angelo on 31/10/2023.
//

import Foundation
import SwiftUI
import PhotosUI
import Types

struct ProfileSettings: View {
    @EnvironmentObject var viewState: ViewState
    @Environment(\.colorScheme) var colorScheme
    @State var profile: Profile? = nil
    @State var avatarItem: PhotosPickerItem? = nil
    @State var bannerItem: PhotosPickerItem? = nil
    @State var isUploadingAvatar = false
    @State var isUploadingBanner = false
    @State var uploadSuccess: String? = nil
    @State var uploadError: String? = nil

    private var backgroundColor: Color {
        viewState.theme.background.color
    }
    
    private var cardBackgroundColor: Color {
        viewState.theme.background2.color
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    let user = viewState.currentUser!

                    // Interactive Profile Card
                    VStack(spacing: 0) {
                        // Banner Area - Tap to Edit
                        PhotosPicker(selection: $bannerItem, matching: .images) {
                            ZStack(alignment: .topTrailing) {
                                if let banner = profile?.background {
                                    LazyImage(source: .file(banner), height: 160, clipTo: UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
                                } else {
                                    LinearGradient(
                                        colors: [Color(hex: "9D4EDD"), Color(hex: "C77DFF")],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                    .frame(height: 160)
                                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
                                }
                                
                                // Edit Indicator overlay
                                ZStack {
                                    Circle().fill(.black.opacity(0.4)).frame(width: 32, height: 32)
                                    if isUploadingBanner {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(12)
                            }
                        }
                        .disabled(isUploadingBanner)
                        
                        // Avatar + Info
                        HStack(alignment: .top, spacing: 16) {
                            // Avatar Area - Tap to Edit
                            PhotosPicker(selection: $avatarItem, matching: .images) {
                                ZStack(alignment: .bottomTrailing) {
                                    Avatar(user: user, width: 80, height: 80, withPresence: false)
                                    
                                    ZStack {
                                        Circle().fill(Color.purple).frame(width: 28, height: 28)
                                        if isUploadingAvatar {
                                            ProgressView().scaleEffect(0.6).tint(.white)
                                        } else {
                                            Image(systemName: "pencil")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .offset(x: 4, y: 4)
                                }
                            }
                            .disabled(isUploadingAvatar)
                            .offset(y: -30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                if let dn = user.display_name {
                                    Text(dn)
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                                }
                                Text("\(user.username)#\(user.discriminator)")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.gray)
                            }
                            .padding(.top, 12)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    }
                    .background(cardBackgroundColor)
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.06), radius: 10, y: 4)

                    // Bio Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ABOUT ME")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.gray)
                            .padding(.leading, 8)
                        
                        VStack(spacing: 0) {
                            TextEditor(text: Binding(
                                get: { profile?.content ?? "" },
                                set: { profile?.content = $0 }
                            ))
                            .frame(height: 120)
                            .padding(12)
                            .scrollContentBackground(.hidden)
                            .background(cardBackgroundColor)
                            .font(.system(size: 15))
                            
                            Divider()
                            
                            Button {
                                Task {
                                    do {
                                        let _ = try await viewState.http.req(method: .patch, route: "/users/@me", parameters: ["profile": ["content": profile?.content]]) as Result<Types.User, RevoltError>
                                        uploadSuccess = "Bio updated successfully!"
                                    } catch {
                                        uploadError = "Failed to update bio"
                                    }
                                }
                            } label: {
                                Text("Save Bio")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.purple)
                                    .cornerRadius(10)
                                    .padding(12)
                            }
                        }
                        .background(cardBackgroundColor)
                        .cornerRadius(18)
                    }

                    // Status Feedback
                    if let success = uploadSuccess {
                        Label(success, systemImage: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.green)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    if let error = uploadError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.red)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Profile Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            profile = try? await viewState.http.fetchProfile(user: viewState.currentUser!.id).get()
        }
        .onChange(of: avatarItem) { _, newItem in
            guard let newItem else { return }
            Task { @MainActor in
                isUploadingAvatar = true
                uploadError = nil
                uploadSuccess = nil
                do {
                    guard let data = try await newItem.loadTransferable(type: Data.self) else {
                        uploadError = "Could not load image"
                        isUploadingAvatar = false
                        return
                    }
                    let uploadResp = try await viewState.http.uploadFile(data: data, name: "avatar.png", category: .avatar).get()
                    let _ = try await viewState.http.req(method: .patch, route: "/users/@me", parameters: ["avatar": uploadResp.id]) as Result<Types.User, RevoltError>
                    await viewState.userSettingsStore.fetchFromApi()
                    uploadSuccess = "Avatar updated!"
                } catch {
                    uploadError = "Failed to upload avatar"
                }
                isUploadingAvatar = false
                avatarItem = nil
            }
        }
        .onChange(of: bannerItem) { _, newItem in
            guard let newItem else { return }
            Task { @MainActor in
                isUploadingBanner = true
                uploadError = nil
                uploadSuccess = nil
                do {
                    guard let data = try await newItem.loadTransferable(type: Data.self) else {
                        uploadError = "Could not load image"
                        isUploadingBanner = false
                        return
                    }
                    let uploadResp = try await viewState.http.uploadFile(data: data, name: "banner.png", category: .background).get()
                    let _ = try await viewState.http.req(method: .patch, route: "/users/@me", parameters: ["profile": ["background": uploadResp.id]]) as Result<Types.User, RevoltError>
                    profile = try? await viewState.http.fetchProfile(user: viewState.currentUser!.id).get()
                    uploadSuccess = "Banner updated!"
                } catch {
                    uploadError = "Failed to upload banner"
                }
                isUploadingBanner = false
                bannerItem = nil
            }
        }
    }
}
