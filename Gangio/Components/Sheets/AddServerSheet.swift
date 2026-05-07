//
//  JoinServer.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import Foundation
import SwiftUI
import Types
import Gangio

struct AddServerSheet: View {
    @EnvironmentObject var viewState: AppViewState
    @Environment(\.dismiss) var dismiss

    @State var showJoinServerAlert: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Add a Server")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(viewState.theme.foreground.color)
                    
                    Text("Your server is where you and your friends hang out. Make yours and start talking.")
                        .font(.system(size: 15))
                        .foregroundStyle(viewState.theme.foreground2.color)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 32)
                
                // Options
                VStack(spacing: 12) {
                    // Create Server Card
                    Button {
                        dismiss()
                        viewState.path.append(NavigationDestination.create_server)
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "plus.app.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(Color(hex: "5865F2")) // Blurple
                            
                            Text("Create a new server")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(viewState.theme.foreground.color)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(viewState.theme.foreground3.color)
                        }
                        .padding(16)
                        .background(viewState.theme.background2.color)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    
                    // Join Server Card
                    Button {
                        showJoinServerAlert.toggle()
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "link.circle.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(Color(hex: "3BA55D")) // Green
                            
                            Text("Join a server")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(viewState.theme.foreground.color)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(viewState.theme.foreground3.color)
                        }
                        .padding(16)
                        .background(viewState.theme.background2.color)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(.horizontal, 16)
                
                Spacer()
                
                // Footer
                VStack(spacing: 12) {
                    Text("Have an invite already?")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(viewState.theme.foreground2.color)
                    
                    Button {
                        showJoinServerAlert.toggle()
                    } label: {
                        Text("Join Server")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "5865F2"))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(viewState.theme.background.color.ignoresSafeArea())
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .alert("Join Server", isPresented: $showJoinServerAlert) {
            JoinServerAlert()
        } message: {
            Text("Enter an invite link or code to join an existing server.")
        }
    }
}

struct JoinServerAlert: View {
    @EnvironmentObject var viewState: AppViewState
    
    @State var text: String = ""
    
    func parseInvite() -> String? {
        if let match = text.wholeMatch(of: /(?:(?:https?:\/\/)?rvlt\.gg\/)?(\w+)/) {
            return String(match.output.1)
        } else {
            return nil
        }
    }
    
    var body: some View {
        TextField("Invite code or link", text: $text)

        Button("Join") {
            
            Task {
                if let invite_code = parseInvite(), (try? await viewState.http.fetchInvite(code: invite_code).get()) != nil {
                    viewState.path.append(NavigationDestination.invite(invite_code))
                }
            }
        }
        
        Button("Cancel", role: .cancel) {}
    }
}

#Preview {
    AddServerSheet()
        .applyPreviewModifiers(withState: AppViewState.preview())
}
