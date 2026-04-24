//
//  Welcome.swift
//  Gangio
//
//  Created by Angelo Manca on 2023-11-15.
//

import SwiftUI
import Types

struct Welcome: View {
    @EnvironmentObject var viewState: ViewState
    @State private var path = NavigationPath()
    @State private var mfaTicket = ""
    @State private var mfaMethods: [String] = []
    @State private var animateGradients = false
    @Binding var wasSignedOut: Bool

    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                // Base background color
                (colorScheme == .light ? Color(hue: 0.62, saturation: 0.02, brightness: 0.98) : Color(hue: 0.62, saturation: 0.1, brightness: 0.05))
                    .ignoresSafeArea()
                
                // Animated Glowing Orbs for a lively, modern premium feel
                GeometryReader { proxy in
                    ZStack {
                        Circle()
                            .fill(Color(hue: 0.55, saturation: 0.8, brightness: 0.9).opacity(colorScheme == .light ? 0.15 : 0.25))
                            .blur(radius: 100)
                            .frame(width: proxy.size.width, height: proxy.size.width)
                            .offset(x: animateGradients ? -proxy.size.width/3 : proxy.size.width/3, y: animateGradients ? -proxy.size.height/4 : proxy.size.height/4)
                        
                        Circle()
                            .fill(Color(hue: 0.75, saturation: 0.8, brightness: 0.9).opacity(colorScheme == .light ? 0.15 : 0.25))
                            .blur(radius: 100)
                            .frame(width: proxy.size.width, height: proxy.size.width)
                            .offset(x: animateGradients ? proxy.size.width/3 : -proxy.size.width/3, y: animateGradients ? proxy.size.height/4 : -proxy.size.height/4)
                    }
                }
                .ignoresSafeArea()
                .onAppear {
                    withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                        animateGradients.toggle()
                    }
                }
                
                if wasSignedOut {
                    VStack {
                        Spacer()
                            .frame(height: 25)
                        Text("You have been logged out")
                            .padding(.horizontal, 25)
                            .padding(.vertical, 10)
                            .foregroundStyle(.white)
                            .background(Color(hue: 0, saturation: 95, brightness: 25))
                            .addBorder(.red, cornerRadius: 8)
                        Spacer()
                    }
                    .transition(.slideTop)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: {
                            withAnimation {
                                wasSignedOut = false
                            }
                        })
                    }
                }
                VStack {
                    Spacer()
                    Group {
                        Image("wide")
                            .resizable()
                            .if(colorScheme == .dark, content: { $0.colorInvert() })
                            .aspectRatio(contentMode: .fit)
                            .padding(.horizontal, 32)
                            .padding(.bottom, 20)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        
                        Text("Your space, your community.")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .foregroundColor((colorScheme == .light) ? Color.black : Color.white)
                        
                        Text("Gangio is the best way to stay connected with your friends and community, anywhere, anytime.")
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40.0)
                            .padding(.top, 12.0)
                            .font(.system(size: 15, weight: .regular, design: .default))
                            .foregroundColor((colorScheme == .light) ? Color.black.opacity(0.7) : Color.white.opacity(0.7))
                            .lineSpacing(4)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 16) {
                        NavigationLink(value: "login") {
                            Text("Log In")
                                .font(.headline)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(colorScheme == .light ? Color.black : Color.white)
                                )
                                .foregroundColor((colorScheme == .light) ? Color.white : Color.black)
                                .shadow(color: (colorScheme == .light ? Color.black : Color.white).opacity(0.2), radius: 10, x: 0, y: 4)
                        }
                        .padding(.horizontal, 40)
                        
                        NavigationLink(value: "signup") {
                            Text("Sign Up")
                                .font(.headline)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial)
                                )
                                .foregroundColor((colorScheme == .light) ? .black : .white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(colorScheme == .light ? Color.black.opacity(0.1) : Color.white.opacity(0.15), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal, 40)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Link("Terms of Service", destination: URL(string: "https://gangio.pro/terms")!)
                            .font(.caption)
                            .foregroundColor(Color(white: 0.584))
                        Link("Privacy Policy", destination: URL(string: "#")!)
                            .font(.caption)
                            .foregroundColor(Color(white: 0.584))
                        Link("Community Guidelines", destination: URL(string: "https://gangio.pro/terms")!)
                            .font(.caption)
                            .foregroundColor(Color(white: 0.584))
                    }
                    .padding(.bottom, 10)
                }
                .navigationDestination(for: String.self) { dest in
                    switch dest {
                    case "mfa":
                        Mfa(path: $path, ticket: $mfaTicket, methods: $mfaMethods)
                    case "login":
                        LogIn(path: $path, mfaTicket: $mfaTicket, mfaMethods: $mfaMethods)
                    case "signup":
                        CreateAccount()
                    case _:
                        EmptyView()
                    }
                    
                }
            }
            .onAppear {
                viewState.isOnboarding = false
            }
            .task {
                viewState.apiInfo = try? await viewState.http.fetchApiInfo().get()
            }
        }
    }
}

#Preview {
    @Previewable @State var signedOut = true
    
    Welcome(wasSignedOut: $signedOut)
        .environmentObject(ViewState.preview())
}
