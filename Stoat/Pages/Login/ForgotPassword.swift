//
//  ForgotPassword.swift
//  Revolt
//
//  Created by Tom on 2023-11-16.
//

import SwiftUI
import Types

struct ForgotPassword_Reset: View {
    @EnvironmentObject var viewState: ViewState
    @Environment(\.colorScheme) var colorScheme
    
    @State var errorMessage: String? = nil
    
    @State var resetToken = ""
    @State var newPassword = ""
    
    @State var showSpinner = false
    @State var completeSpinner = false
    
    @State var goToOnboarding: Bool = false
    
    var email: String
    
    @State private var animateGradients = false

    func process() {
        Task {
            do {
                _ = try await viewState.http.resetPassword(token: resetToken, password: newPassword).get()
            } catch {
                withAnimation {
                    errorMessage = "Your token was invalid or your password sucked. Direct all complaints about this message to zomatree" // TODO: get error type?
                    showSpinner = false
                }
                return
            }
            
            completeSpinner = true
            try! await Task.sleep(for: .seconds(3))
            
            await viewState.signIn(email: email, password: newPassword, callback: { state in
                switch state {
                case .Disabled, .Invalid:
                    withAnimation {
                        errorMessage = "Your account has been disabled,\nhowever the reset was successful"
                    }
                case .Onboarding: goToOnboarding = true
                default: viewState.isOnboarding = false
            }})
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
                        
                    Text("Forgot your password?")
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
                    } else {
                        Text("We sent a token to your email.\nEnter it here, along with your new password")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.bottom, 20)
                
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "number.circle.fill")
                            .foregroundColor(.gray)
                        TextField("Email Token", text: $resetToken)
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

                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.gray)
                        SecureField("New Password", text: $newPassword)
                            .textContentType(.newPassword)
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

                Button(action: {
                    if resetToken.isEmpty || newPassword.isEmpty {
                        withAnimation {
                            errorMessage = "Please enter the token sent to your email, and your new password"
                        }
                        return
                    }
                    withAnimation{
                        showSpinner = true
                    }
                    process()
                }) {
                    if showSpinner || completeSpinner {
                        LoadingSpinnerView(frameSize: CGSize(width: 25, height: 25), isActionComplete: $completeSpinner)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Reset Password")
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

                Spacer()
            }
        }
        .navigationDestination(isPresented: $goToOnboarding) {
            CreateAccount(onboardingStage: .Username)
        }
    }
}

struct ForgotPassword: View {
    @EnvironmentObject var viewState: ViewState
    @Environment(\.colorScheme) var colorScheme
    
    @State var errorMessage: String? = nil
    @State var email = ""
    
    @State var showSpinner = false
    @State var completeSpinner = false
    @State var captchaResult: String? = nil
    
    @State var goToResetPage = false
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
            goToResetPage = true
            
            try! await Task.sleep(for: .seconds(1))
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
                        
                    Text("Forgot your password?")
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
                        Text("Let's fix that")
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
                            Text("Reset Password")
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
        .navigationDestination(isPresented: $goToResetPage) {
            ForgotPassword_Reset(email: email)
        }
    }
}

#Preview {
    NavigationStack {
        ForgotPassword_Reset(email: "")
            .environmentObject(ViewState.preview())
    }
}
