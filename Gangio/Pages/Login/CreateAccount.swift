//
//  CreateAccount.swift
//  Gangio
//
//  Created by Tom on 2023-11-13.
//

import SwiftUI
import Types

struct CreateAccount: View {
    enum OnboardingStage {
        case Initial
        case Verify
        case Username
    }
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var viewState: ViewState

    @State private var email = ""
    @State private var password = ""
    @State private var verifyCode = ""
    @State private var username = ""
    @State private var showPassword = false
    @State private var errorMessage: String? = nil
    
    @State private var isWaitingWithSpinner = false
    @State private var isSpinnerComplete = false
    @State private var animateGradients = false
    @State private var hCaptchaResult: String? = nil
    
    @State var onboardingStage = OnboardingStage.Initial
    
    @FocusState private var focus1: Bool
    @FocusState private var focus2: Bool
    
    @FocusState private var autoFocusPull: Bool
    
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
                if (!isWaitingWithSpinner && onboardingStage == .Initial) || [OnboardingStage.Username, OnboardingStage.Verify].contains(onboardingStage) {
                    Spacer()
                }

                VStack(spacing: 12) {
                    if onboardingStage == .Initial {
                        Image("wide")
                            .resizable()
                            .if(colorScheme == .dark, content: { $0.colorInvert() })
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 30)
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
                            .padding(.bottom, 8)
                    }
                    
                    Text(onboardingStage == .Initial ? "Let's sign you up" : (onboardingStage == .Verify ? "Check your email" : "Pick a Username"))
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
                    } else if onboardingStage == .Verify {
                        Text("We sent a link to your email.\nClick it, then come back and tap Check Verification.")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                            .multilineTextAlignment(.center)
                    } else if onboardingStage == .Username {
                        Text("This is how other users will recognize you")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.bottom, 20)

                VStack(spacing: 16) {
                    if !isWaitingWithSpinner && onboardingStage == .Initial {
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
                                .disabled(isWaitingWithSpinner)
                                .focused($autoFocusPull)
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
                                
                            ZStack(alignment: .trailing) {
                                if showPassword {
                                    TextField("Password", text: $password)
                                        .textContentType(.password)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                        .disabled(isWaitingWithSpinner)
                                        .focused($focus1)
                                        .foregroundStyle(colorScheme == .light ? .black : .white)
                                } else {
                                    SecureField("Password", text: $password)
                                        .textContentType(.password)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                        .disabled(isWaitingWithSpinner)
                                        .focused($focus2)
                                        .foregroundStyle(colorScheme == .light ? .black : .white)
                                }
                                
                                Button(action: {
                                    showPassword.toggle()
                                    if showPassword { focus1 = true } else { focus2 = true }
                                }) {
                                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.gray)
                                        .padding(.leading, 8)
                                }
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
                        .onAppear { autoFocusPull = true }

                    } else if onboardingStage == .Verify {
                        HStack(spacing: 12) {
                            Image(systemName: "link")
                                .foregroundColor(.gray)
                            TextField("Verification Token (Optional)", text: $verifyCode)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .disabled(isWaitingWithSpinner)
                                .focused($autoFocusPull)
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
                        .onAppear { autoFocusPull = true }

                    } else if onboardingStage == .Username {
                        HStack(spacing: 12) {
                            Image(systemName: "at")
                                .foregroundColor(.gray)
                            TextField("Username", text: $username)
                                .textContentType(.username)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .disabled(isWaitingWithSpinner)
                                .focused($autoFocusPull)
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
                        .onAppear { autoFocusPull = true }
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                    .frame(height: 20)

                Group {
                        Button(action: {
                            autoFocusPull = false // reset focus state so it gets reenabled on state change via onAppear
                            
                            if onboardingStage == .Initial {
                                if email.isEmpty || password.isEmpty {
                                    withAnimation { errorMessage = "Please enter your email and password" }
                                    return
                                }
                                errorMessage = nil
                                if viewState.apiInfo!.features.captcha.enabled && hCaptchaResult == nil {
                                    withAnimation { isWaitingWithSpinner.toggle() }
                                } else {
                                    Task {
                                        do {
                                            _ = try await viewState.http.createAccount(email: email, password: password, invite: nil, captcha: hCaptchaResult).get()
                                        } catch {
                                            withAnimation {
                                                isSpinnerComplete = false
                                                isWaitingWithSpinner = false
                                                errorMessage = "Sorry, your email or password was invalid"
                                            }
                                            return
                                        }
                                        withAnimation {
                                            isWaitingWithSpinner = false
                                            isSpinnerComplete = false
                                            onboardingStage = .Verify
                                        }
                                    }
                                }
                            }
                            else if onboardingStage == .Verify {
                                errorMessage = nil
                                withAnimation { isWaitingWithSpinner = true }
                                Task {
                                    if verifyCode.isEmpty {
                                        // User clicked the email link, try to sign in directly
                                        await viewState.signIn(email: email, password: password, callback: { state in
                                            Task { @MainActor in
                                                withAnimation { isSpinnerComplete = true }
                                                try? await Task.sleep(for: .seconds(2))
                                                withAnimation {
                                                    isWaitingWithSpinner = false
                                                    isSpinnerComplete = false
                                                }
                                                switch state {
                                                case .Onboarding:
                                                    withAnimation { onboardingStage = .Username }
                                                case .Success:
                                                    viewState.isOnboarding = false
                                                default:
                                                    withAnimation { errorMessage = "Not verified yet. Click the email link first, then try again." }
                                                }
                                            }
                                        })
                                    } else {
                                        let resp = await viewState.signInWithVerify(code: verifyCode, email: email, password: password)
                                        if !resp {
                                            withAnimation {
                                                isWaitingWithSpinner = false
                                                errorMessage = "Invalid verification code"
                                            }
                                            return
                                        }
                                        withAnimation { isSpinnerComplete = true }
                                        try? await Task.sleep(for: .seconds(2))
                                        withAnimation {
                                            isWaitingWithSpinner = false
                                            isSpinnerComplete = false
                                            onboardingStage = .Username
                                        }
                                    }
                                }
                            }
                            else if onboardingStage == .Username {
                                if username.isEmpty {
                                    withAnimation { errorMessage = "Please enter a username" }
                                    return
                                }
                                errorMessage = nil
                                withAnimation { isWaitingWithSpinner = true }
                                Task {
                                    do {
                                        _ = try await viewState.http.completeOnboarding(username: username).get()
                                    } catch {
                                        withAnimation {
                                            isWaitingWithSpinner = false
                                            errorMessage = "Invalid Username, try something else"
                                        }
                                        return
                                    }
                                    withAnimation { isSpinnerComplete = true }
                                    
                                    try? await Task.sleep(for: .seconds(2))
                                    withAnimation {
                                        isWaitingWithSpinner = false
                                        isSpinnerComplete = false
                                    }
                                    viewState.isOnboarding = false
                                }
                            }
                        }) {
                            if isWaitingWithSpinner || isSpinnerComplete {
                                LoadingSpinnerView(frameSize: CGSize(width: 25, height: 25), isActionComplete: $isSpinnerComplete)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text(onboardingStage == .Initial ? "Create Account" : onboardingStage == .Verify ? "Check Verification" : "Select Username")
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
                        .disabled(isWaitingWithSpinner || isSpinnerComplete)
                }
                
                if (!isWaitingWithSpinner && onboardingStage == .Initial) {
                    NavigationLink(destination: ResendEmail()) {
                        Text("Resend a verification email")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .padding(.top, 10)
                    }
                }
                
                if (!isWaitingWithSpinner && onboardingStage == .Initial) || [OnboardingStage.Username, OnboardingStage.Verify].contains(onboardingStage) {
                    Spacer()
                }
            }
            // we remove the outermost padding() to allow backgrounds to reach safe areas if they need to, but keep inner paddings
            
            if isWaitingWithSpinner && onboardingStage == .Initial {
                VStack {
                    #if canImport(UIKit)
                    HCaptchaView(apiKey: viewState.apiInfo!.features.captcha.key, baseURL: viewState.http.baseURL, result: $hCaptchaResult)
                        .onChange(of: hCaptchaResult) {
                            withAnimation {
                                isWaitingWithSpinner = false
                                isSpinnerComplete = true
                            }
                            Task {
                                do {
                                    _ = try await viewState.http.createAccount(email: email, password: password, invite: nil, captcha: hCaptchaResult).get()
                                } catch {
                                    withAnimation {
                                        isSpinnerComplete = false
                                        isWaitingWithSpinner = false
                                        errorMessage = "Sorry, your email or password was invalid"
                                    }
                                    return
                                }
                                try! await Task.sleep(for: .seconds(2))
                                withAnimation {
                                    isSpinnerComplete = false
                                    if viewState.apiInfo?.features.email == true {
                                        onboardingStage = .Verify
                                    } else {
                                        onboardingStage = .Username
                                    }
                                }
                            }
                    }
                    
                    #else
                    Text("No hcaptcha support")
                    #endif
                }
            }
        }
        .onAppear {
            viewState.isOnboarding = true
        }
    }
}

#Preview {
    var viewState = ViewState.preview()
    
    return CreateAccount()
            .environmentObject(viewState)
}
