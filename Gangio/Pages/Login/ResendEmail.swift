//
//  ResendEmail.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import SwiftUI
import Types

struct ResendEmail: View {
    @EnvironmentObject var viewState: AppViewState
    @Environment(\.colorScheme) var colorScheme
    
    @State var errorMessage: String? = nil
    @State var email = ""
    
    @State var showSpinner = false
    @State var completeSpinner = false
    @State var captchaResult: String? = nil
    
    @State var goToVerificationPage = false
    
    @State private var animateGradients = false

    func preProcessRequest() {
        withAnimation {
            errorMessage = nil
        }
        
        if email.isEmpty {
            withAnimation {
                errorMessage = "Enter your email"
            }
            return
        }
        
        withAnimation {
            showSpinner = true
        }
    }
    
    func processRequest() {
        Task {
            completeSpinner = true
            try! await Task.sleep(for: .seconds(3)) // let the spinner fill

            do {
                _ = try await viewState.http.createAccount_ResendVerification(email: email, captcha: captchaResult).get()
            } catch {
                withAnimation {
                    errorMessage = "Invalid email"
                    showSpinner = false
                    completeSpinner = false
                    captchaResult = nil
                }
                return
            }
            
            try! await Task.sleep(for: .seconds(1))
            goToVerificationPage = true
            
            try! await Task.sleep(for: .seconds(1)) // fix values after navigation change in case they press back
            showSpinner = false
            completeSpinner = false
            captchaResult = nil
        }
    }
    
    var body: some View {
        ZStack {
            (colorScheme == .light ? Color(hue: 0.62, saturation: 0.02, brightness: 0.98) : Color(hue: 0.62, saturation: 0.1, brightness: 0.05))
                .ignoresSafeArea()

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

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 12) {
                    Image("wide")
                        .resizable()
                        .if(colorScheme == .dark, content: { $0.colorInvert() })
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 30)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
                        .padding(.bottom, 8)
                        
                    Text("Didn't get an email?")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle((colorScheme == .light) ? Color.black : Color.white)
                        .multilineTextAlignment(.center)
                    
                    if let error = errorMessage {
                        Text(verbatim: error)
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(Color.red.opacity(0.9))
                            .clipShape(Capsule())
                            .shadow(color: Color.red.opacity(0.3), radius: 5, x: 0, y: 3)
                    } else if !showSpinner && captchaResult == nil {
                        Text("Enter your email, and if we've got you on record we'll send you another one")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.bottom, 20)
                
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.gray)
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            #if os(iOS)
                            .keyboardType(.emailAddress)
                            #endif
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .disabled(showSpinner)
                            .foregroundStyle(colorScheme == .light ? .black : .white)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 24)

                Spacer()
                    .frame(height: 20)

                if showSpinner && captchaResult == nil && viewState.apiInfo!.features.captcha.enabled {
                    #if os(macOS)
                    Text("No hcaptcha support")
                    #else
                    HCaptchaView(apiKey: viewState.apiInfo!.features.captcha.key, baseURL: viewState.http.baseURL, result: $captchaResult)
                    #endif
                } else {
                    Button(action: {
                        preProcessRequest()
                        if !viewState.apiInfo!.features.captcha.enabled || captchaResult != nil {
                            processRequest()
                        }
                    }) {
                        if showSpinner || completeSpinner {
                            LoadingSpinnerView(frameSize: CGSize(width: 25, height: 25), isActionComplete: $completeSpinner)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Get another code")
                                .font(.headline)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 16)
                    .foregroundColor(colorScheme == .light ? .white : .black)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(colorScheme == .light ? Color.black : Color.white)
                    )
                    .shadow(color: (colorScheme == .light ? Color.black : Color.white).opacity(0.2), radius: 10, x: 0, y: 4)
                    .padding(.horizontal, 24)
                    .disabled(showSpinner || completeSpinner)
                }

                Spacer()
            }
        }
        .onChange(of: captchaResult) {
            if captchaResult != nil {
                processRequest()
            }
        }
        .navigationDestination(isPresented: $goToVerificationPage) {
            CreateAccount(onboardingStage: .Verify)
        }
    }
}

#Preview {
    ResendEmail()
        .environmentObject(AppViewState.preview())
}
