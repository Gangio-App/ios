import SwiftUI
import Types


struct LogIn: View {
    @EnvironmentObject var viewState: AppViewState

    @Binding var path: NavigationPath

    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var showMfa = false
    @State private var errorMessage: String? = nil
    
    @State private var needsOnboarding = false
    
    @State private var isWaitingWithSpinner = false
    @State private var isSpinnerComplete = false
    @State private var animateGradients = false

    @Binding public var mfaTicket: String
    @Binding public var mfaMethods: [String]

    @FocusState private var focus1: Bool
    @FocusState private var focus2: Bool
    
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    private func logIn() async {
        await viewState.signIn(email: email, password: password, callback: { state in
            switch state {
                case .Mfa(let ticket, let methods):
                    withAnimation {
                        isWaitingWithSpinner = false
                        isSpinnerComplete = false
                    }
                    self.mfaTicket = ticket
                    self.mfaMethods = methods
                    self.path.append("mfa")

                case .Disabled:
                    withAnimation {
                        isWaitingWithSpinner = false
                        isSpinnerComplete = false
                        self.errorMessage = "Account has been disabled."
                    }

                case .Success:
                    withAnimation {
                        isSpinnerComplete = true
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        withAnimation {
                            isWaitingWithSpinner = false
                            isSpinnerComplete = false
                            path = NavigationPath()
                        }
                    }
                
                case .Invalid:
                    withAnimation {
                        isWaitingWithSpinner = false
                        isSpinnerComplete = false
                        self.errorMessage = "Invalid email and/or password"
                    }
                
                case .Onboarding:
                    withAnimation {
                        isWaitingWithSpinner = false
                        isSpinnerComplete = false
                    }
                    viewState.isOnboarding = true
                    self.needsOnboarding = true
            }
        })
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
                        
                    Text("Welcome Back")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle((colorScheme == .light) ? Color.black : Color.white)
                    
                    Text("Enter your credentials to continue")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
                .padding(.bottom, 20)

                VStack(spacing: 16) {
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
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.gray)
                        TextField("Email", text: $email)
                            #if os(iOS)
                            .keyboardType(.emailAddress)
                            #endif
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .disabled(isWaitingWithSpinner)
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
                }
                .padding(.horizontal, 24)

                Spacer()
                    .frame(height: 20)

                Button(action: {
                    if email.isEmpty || password.isEmpty {
                        withAnimation {
                            errorMessage = "Please enter your email and password"
                        }
                        return
                    }
                    errorMessage = nil
                    withAnimation { isWaitingWithSpinner = true }
                    Task { await logIn() }
                }) {
                    if isWaitingWithSpinner || isSpinnerComplete {
                        LoadingSpinnerView(frameSize: CGSize(width: 25, height: 25), isActionComplete: $isSpinnerComplete)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Log In")
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

                Spacer()

                VStack(spacing: 20) {
                    NavigationLink(destination: { ForgotPassword() }) {
                        Text("Forgot Password?")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(colorScheme == .light ? .black : .white)
                    }
                    
                    NavigationLink(destination: { ResendEmail() }) {
                        Text("Resend verification email")
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .navigationDestination(isPresented: $needsOnboarding) { // we dont use a link+destination because this will overlay when the user hasn't onboarded
            CreateAccount(onboardingStage: .Username)
        }
    }
}

struct Mfa: View {
    @EnvironmentObject var viewState: AppViewState

    @Binding public var path: NavigationPath
    @Binding var ticket: String
    @Binding var methods: [String]

    @State var selected: String? = nil
    @State var currentText: String = ""
    @State var error: String? = nil
    
    @FocusState var textEntryFocus: String?

    @Environment(\.colorScheme) var colorScheme: ColorScheme

    func getMethodDetails(method: String) -> (String, String, String, String, UIKeyboardType) {
        switch method {
            case "Password":
                return ("lock.fill", "Enter a password", "Enter your saved password.", "Password", .default)
            case "Totp":
                return ("checkmark", "Enter a six-digit code", "Enter the six-digit code from your authenticator app", "Code", .numberPad)
            case "Recovery":
                return ("arrow.counterclockwise", "Enter a recovery code", "Enter your backup recovery code", "Recovery code", .default)
            default:
                return ("questionmark", "Unknown", "Unknown", "Unknown", .default)
        }
    }
    
    func sendMfa() {
        let key: String
        
        switch selected {
            case "Password":
                key = "password"
            case "Totp":
                key = "totp_code"
            case "Recovery":
                key = "recovery_code"
            case _:
                return
        }
        
        Task {
            await viewState.signIn(mfa_ticket: ticket, mfa_response: [key: currentText], callback: { response in
                switch response {
                    case .Success:
                        path = NavigationPath()
                    case .Disabled:
                        error = "Account disabled"
                    case .Invalid:
                        error = "Invalid \(selected!.replacing("_", with: " "))"
                    case .Onboarding:
                        ()
                    case .Mfa(let ticket, let methods):
                        self.ticket = ticket
                        self.methods = methods
                        error = "Please try again"
                }
            })
        }
    }
    
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .center, spacing: 16) {
                Spacer()
                
                Text("One more thing")
                    .bold()
                    .font(.title)
                
                Spacer()
                
                Text("You've got 2FA enabled to keep your account extra-safe.")
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if let error {
                    Text(verbatim: error)
                        .foregroundStyle(.red)
                }
                
                ScrollView {
                    ForEach(methods, id: \.self) { method in
                        let (icon, text, desc, placeholder, keyboardType) = getMethodDetails(method: method)
                        
                        VStack(alignment: .leading) {
                            Button {
                                withAnimation {
                                    if selected == method {
                                        selected = nil
                                        textEntryFocus = nil
                                    } else {
                                        selected = method
                                        textEntryFocus = method
                                    }
                                    
                                    currentText = ""
                                }
                            } label: {
                                VStack(alignment: .center, spacing: 12) {
                                    HStack(alignment: .center, spacing: 16) {
                                        
                                        Image(systemName: icon)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 24)
                                        
                                        Text(text)
                                            .bold()
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.down")
                                    }
                                    
                                    if selected == method {
                                        Text(desc)
                                            .foregroundStyle(.secondary)
                                        
                                        VStack(alignment: .leading, spacing: 16) {
                                            TextField(placeholder, text: $currentText)
                                                .focused($textEntryFocus, equals: method)
                                            #if os(iOS)
                                                .keyboardType(keyboardType)
                                            #endif
                                                .textContentType(.oneTimeCode)
                                                .onSubmit(sendMfa)
                                            
                                            Button {
                                                sendMfa()
                                            } label: {
                                                HStack {
                                                    Spacer()
                                                    Text("Next")
                                                    Spacer()
                                                }
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .buttonBorderShape(.roundedRectangle(radius: 8))
                                            .tint(.themePrimary)
                                        }
                                    }
                                }
                                .padding(.horizontal, 32)
                                .padding(.vertical, 16)
                            }
                            .background(RoundedRectangle(cornerRadius: 8)
                                .foregroundStyle(.gray.opacity(0.2))
                            )
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundColor((colorScheme == .light) ? Color.black : Color.white)
    }
}

struct PasswordModifier: ViewModifier {
    var borderColor: Color = Color.gray

    func body(content: Content) -> some View {
        content
            .disableAutocorrection(true)
    }
}



#Preview {
    LogIn(path: .constant(NavigationPath()), mfaTicket: .constant(""), mfaMethods: .constant([]))
        .environmentObject(AppViewState.preview())
}
