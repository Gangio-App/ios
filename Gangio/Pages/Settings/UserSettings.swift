//
//  UserSettings.swift
//  Gangio
//
//  Created & Design by github.com/benyigit on 21/04/2026.
//

import SwiftUI
import OSLog
import Sentry
import Alamofire // literally just for types
import UniformTypeIdentifiers


let log = Logger(subsystem: "app.gangio.chat", category: "UserSettingsViews")

func generateTOTPUrl(secret: String, email: String) -> String {
    return "otpauth://totp/Gangio:\(email)?secret=\(secret)&issuer=Gangio"
}


/// Takes a callback that receives either the totp code or the recovery code (in that argument order).
/// Wont be called if neither are found.
func maybeGetPasteboardValue(_ callback: (String?, String?) -> ()) {
    #if os(iOS)
    let pasteboardItem = UIPasteboard.general.string
    #elseif os(macOS)
    let pasteboardItem = NSPasteboard.general.string(forType: .string)
    #endif
    if let pasteboardItem = pasteboardItem {
        let regex = /(?<totp>\d{6})|(?<recovery>[a-z0-9]{5}-[a-z0-9]{5})/
        if let match = try? regex.wholeMatch(in: pasteboardItem) {
            if match.output.recovery != nil {
                callback(nil, String(match.output.recovery!))
            } else if match.output.totp != nil {
                callback(String(match.output.totp!), nil)
            }
        }
    }
}

// MARK: - MFA stuff

fileprivate struct CreateMFATicketView: View {
    @EnvironmentObject var viewState: AppViewState
    @Environment(\.colorScheme) var colorScheme
    @State private var fieldIsIncorrect = false
    @State private var fieldShake = false
    @State private var fieldValue = ""
    @State private var isLoading = false
    
    enum RequestTicketType { case Password, Code, RecoveryCode }
    
    var requestTicketType: RequestTicketType
    var doneCallback: (MFATicketResponse) -> ()
    
    func setBadField() {
        withAnimation {
            fieldIsIncorrect = true
        }
        
        fieldShake = true
        withAnimation(Animation.spring(response: 0.2, dampingFraction: 0.2, blendDuration: 0.2)) {
            fieldShake = false
        }
    }
    
    func submitForTicket() async {
        isLoading = true
        if fieldIsIncorrect {
            withAnimation {
                fieldIsIncorrect = false
            }
        }
        
        if fieldValue.isEmpty {
            setBadField()
            isLoading = false
            return
        }
        
        var requestType = requestTicketType
        if requestTicketType == .Code && fieldValue.contains("-") {
            requestType = .RecoveryCode
        }
        
        let resp = switch requestType {
        case .Password:
            await viewState.http.submitMFATicket(password: fieldValue)
        case .Code:
            await viewState.http.submitMFATicket(totp: fieldValue)
        case .RecoveryCode:
            await viewState.http.submitMFATicket(recoveryCode: fieldValue)
        }
        
        let ticket = try? resp.get()
        
        if ticket == nil {
            setBadField()
            isLoading = false
            return
        }
        
        doneCallback(ticket!)
        isLoading = false
    }
    
    func receivePasteboardCallback(totp: String?, recovery: String?) {
        if totp != nil {
            fieldValue = totp!
            Task { await submitForTicket() }
        } else if recovery != nil {
            fieldValue = recovery!
            Task { await submitForTicket() }
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: requestTicketType == .Password ? "lock.shield.fill" : "key.fill")
                    .font(.system(size: 48))
                    .foregroundColor(viewState.theme.accent.color)
                
                Text(requestTicketType == .Password ? "Verification Required" : "Enter Code")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                
                Text(requestTicketType == .Password 
                     ? "Please enter your account password to verify your identity." 
                     : "Check your authenticator app for the 2FA code.")
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 20)
            
            VStack(alignment: .leading, spacing: 10) {
                if requestTicketType == .Password {
                    SecureField("Password", text: $fieldValue)
                        .padding()
                        .background(colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(fieldIsIncorrect ? Color.red : Color.clear, lineWidth: 1)
                        )
                        .textContentType(.password)
                        .offset(x: fieldShake ? 10 : 0)
                        .onSubmit {
                            Task { await submitForTicket() }
                        }
                } else {
                    TextField("2FA Code", text: $fieldValue)
                        .padding()
                        .background(colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(fieldIsIncorrect ? Color.red : Color.clear, lineWidth: 1)
                        )
                        .textContentType(.oneTimeCode)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .offset(x: fieldShake ? 10 : 0)
                        .onChange(of: fieldValue) { _, _ in
                            if fieldValue.count == 6 && requestTicketType == .Code {
                                Task { await submitForTicket() }
                            }
                        }
                        .onTapGesture {
                            maybeGetPasteboardValue(receivePasteboardCallback)
                        }
                }
                
                if fieldIsIncorrect {
                    Text(fieldValue.isEmpty ? "Required field" : "Incorrect authentication code")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.leading, 4)
                }
            }
            
            Button(action: {
                Task { await submitForTicket() }
            }) {
                HStack {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Continue")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(viewState.theme.accent.color))
            }
            .disabled(isLoading || fieldValue.isEmpty)
        }
        .padding(24)
    }
}


fileprivate struct AddTOTPSheet: View {
    private enum Phase { case Password, Code, Verify, FatalError}
    @EnvironmentObject var viewState: AppViewState
    @Environment(\.colorScheme) var colorScheme
    @State private var currentPhase: Phase = .Password
    @Binding var showSheet: Bool
    
    @State var OTP = ""
    @State var fieldShake = false
    @State var fieldIsIncorrect = false
    @State var isSaving = false
    
    @State var ticket: MFATicketResponse? = nil
    @State var secret: String? = nil
    
    func receiveTicket(mfaTicket: MFATicketResponse) async {
        ticket = mfaTicket
        
        let secretResp = await viewState.http.getTOTPSecret(mfaToken: ticket!.token)
        do {
            let secretModel = try secretResp.get()
            secret = secretModel.secret
            
            withAnimation {
                currentPhase = .Code
            }
        } catch {
            withAnimation {
                currentPhase = .FatalError
            }
        }
    }
    
    func finalize() async {
        isSaving = true
        let resp = await viewState.http.enableTOTP(mfaToken: ticket!.token, totp_code: OTP)
        
        do {
            _ = try resp.get()
            showSheet = false
        } catch {
            withAnimation {
                fieldIsIncorrect = true
                fieldShake = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                fieldShake = false
            }
        }
        isSaving = false
    }
    
    var body: some View {
        VStack {
            if currentPhase == .Password {
                CreateMFATicketView(requestTicketType: .Password, doneCallback: {ticket in Task{await receiveTicket(mfaTicket: ticket)}})
            }
            else if currentPhase == .Code {
                VStack(spacing: 24) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 48))
                        .foregroundColor(viewState.theme.accent.color)
                    
                    Text("Setup Authenticator")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    
                    Text("Manually enter this secret in your authenticator app, or click below to open it directly.")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Text(secret!)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95))
                        .cornerRadius(12)
                        .onTapGesture {
                            UIPasteboard.general.string = secret!
                        }
                    
                    Link(destination: URL(string: generateTOTPUrl(secret: secret!, email: viewState.userSettingsStore.cache.accountData!.email))!) {
                        HStack {
                            Image(systemName: "plus.app.fill")
                            Text("Open Authenticator App")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue))
                    }
                    
                    Button(action: {
                        withAnimation { currentPhase = .Verify }
                    }) {
                        Text("Next Step")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(viewState.theme.accent.color))
                    }
                }
                .padding(24)
            }
            else if currentPhase == .Verify {
                VStack(spacing: 24) {
                    Image(systemName: "checkerboard.shield")
                        .font(.system(size: 48))
                        .foregroundColor(viewState.theme.accent.color)
                    
                    Text("Verify Authenticator")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    
                    Text("Enter the 6-digit code from your authenticator app to complete setup.")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    TextField("6-digit Code", text: $OTP)
                        .padding()
                        .background(colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(fieldIsIncorrect ? Color.red : Color.clear, lineWidth: 1)
                        )
                        .textContentType(.oneTimeCode)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .offset(x: fieldShake ? 10 : 0)
                        .onChange(of: OTP) { _, _ in
                            if OTP.count == 6 {
                                Task { await finalize() }
                            }
                        }
                    
                    Button(action: {
                        Task { await finalize() }
                    }) {
                        HStack {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text("Enable 2FA")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(viewState.theme.accent.color))
                    }
                    .disabled(OTP.count != 6 || isSaving)
                }
                .padding(24)
            }
            else if currentPhase == .FatalError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Something went wrong")
                    Button("Close") { showSheet = false }
                }
                .padding()
            }
        }
    }
}


fileprivate struct RemoveTOTPSheet: View {
    @EnvironmentObject var viewState: AppViewState
    @Binding var showSheet: Bool
    @State var errorOccurred = false
    
    func removeTOTP(ticket: MFATicketResponse) {
        Task {
            do {
                _ = try await viewState.http.disableTOTP(mfaToken: ticket.token).get()
                showSheet = false
            } catch {
                withAnimation { errorOccurred = true }
            }
        }
    }
    
    var body: some View {
        VStack {
            CreateMFATicketView(requestTicketType: .Password, doneCallback: removeTOTP)
            if errorOccurred {
                Text("Error removing 2FA. Identity verification failed.")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.bottom, 20)
            }
        }
    }
}

fileprivate struct GenerateRecoveryCodesSheet: View {
    @EnvironmentObject var viewState: AppViewState
    @Environment(\.colorScheme) var colorScheme
    @Binding var showSheet: Bool
    @Binding var sheetIsNotDismissable: Bool
    @State var codes: [String] = []
    @State var isCopied = false
    
    func generateCodes(ticket: MFATicketResponse) {
        Task {
            do {
                let _codes = try await viewState.http.generateRecoveryCodes(mfaToken: ticket.token).get()
                sheetIsNotDismissable = true
                withAnimation { codes = _codes }
            } catch {
                // handle error
            }
        }
    }
    
    var body: some View {
        VStack {
            if codes.isEmpty {
                CreateMFATicketView(requestTicketType: .Password, doneCallback: generateCodes)
            } else {
                VStack(spacing: 24) {
                    Image(systemName: "key.horizontal.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    
                    Text("Recovery Codes")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    
                    Text("Save these codes in a safe place. You can use them to sign in if you lose your 2FA device.")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(codes, id: \.self) { code in
                            Text(code)
                                .font(.system(.subheadline, design: .monospaced))
                                .padding(8)
                                .frame(maxWidth: .infinity)
                                .background(colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 10)

                    VStack(spacing: 12) {
                        Button(action: {
                            UIPasteboard.general.string = codes.joined(separator: "\n")
                            withAnimation { isCopied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { isCopied = false }
                        }) {
                            HStack {
                                Image(systemName: isCopied ? "checkmark" : "doc.on.doc.fill")
                                Text(isCopied ? "Copied!" : "Copy All")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(isCopied ? Color.green : Color.blue))
                        }
                        
                        Button("Done") { showSheet = false }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                    }
                }
                .padding(24)
            }
        }
    }
}

// MARK: - Account fields

fileprivate struct UsernameUpdateSheet: View {
    @EnvironmentObject var viewState: AppViewState
    @Environment(\.colorScheme) var colorScheme
    @Binding var showSheet: Bool
    
    @State var value: String
    @State var password: String = ""
    @State var isSaving = false
    @State var errorText: String? = nil
    
    init(viewState: AppViewState, showSheet sheet: Binding<Bool>) {
        _showSheet = sheet
        _value = State(initialValue: viewState.userSettingsStore.cache.user?.username ?? "")
    }
    
    func submitName() async {
        isSaving = true
        errorText = nil
        do {
            _ = try await viewState.http.updateUsername(newName: value, password: password).get()
            showSheet = false
        } catch {
            errorText = "Incorrect password or username invalid"
        }
        isSaving = false
    }
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "person.text.rectangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(viewState.theme.accent.color)
                
                Text("Change Username")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
            }
            .padding(.top, 20)
            
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("NEW USERNAME")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                    
                    TextField("Username", text: $value)
                        .padding()
                        .background(colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95))
                        .cornerRadius(12)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("CONFIRM PASSWORD")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                    
                    SecureField("Current Password", text: $password)
                        .padding()
                        .background(colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95))
                        .cornerRadius(12)
                }
                
                if let error = errorText {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 4)
                }
            }
            
            Button(action: { Task { await submitName() } }) {
                HStack {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text("Update Username")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(viewState.theme.accent.color))
            }
            .disabled(isSaving || value.isEmpty || password.isEmpty)
            
            Spacer().frame(height: 10)
        }
        .padding(24)
    }
}


fileprivate struct PasswordUpdateSheet: View {
    @EnvironmentObject var viewState: AppViewState
    @Environment(\.colorScheme) var colorScheme
    @Binding var showSheet: Bool
    
    @State var oldPassword: String = ""
    @State var newPassword: String = ""
    @State var isSaving = false
    @State var errorText: String? = nil
    
    func submitPassword() async {
        isSaving = true
        errorText = nil
        do {
            _ = try await viewState.http.updatePassword(newPassword: newPassword, oldPassword: oldPassword).get()
            showSheet = false
        } catch {
            errorText = "Current password is incorrect"
        }
        isSaving = false
    }
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundColor(viewState.theme.accent.color)
                
                Text("Change Password")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
            }
            .padding(.top, 20)
            
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CURRENT PASSWORD")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                    
                    SecureField("Enter Current Password", text: $oldPassword)
                        .padding()
                        .background(colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95))
                        .cornerRadius(12)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("NEW PASSWORD")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                    
                    SecureField("Enter New Password", text: $newPassword)
                        .padding()
                        .background(colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.95))
                        .cornerRadius(12)
                }
                
                if let error = errorText {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Button(action: { Task { await submitPassword() } }) {
                HStack {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text("Update Password")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(viewState.theme.accent.color))
            }
            .disabled(isSaving || oldPassword.isEmpty || newPassword.isEmpty)
        }
        .padding(24)
    }
}

fileprivate struct DisableAccountSheet: View {
    @EnvironmentObject var viewState: AppViewState
    @Binding var showSheet: Bool
    @State var ticket: MFATicketResponse? = nil
    @State var isDeleting = false
    
    var body: some View {
        if ticket == nil {
            CreateMFATicketView(requestTicketType: .Password, doneCallback: { self.ticket = $0 })
        } else {
            VStack(spacing: 24) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                
                Text("Disable Account?")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                
                Text("This will prevent anyone from signing into your account. You can reactivate it later by contacting support.")
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: {
                    isDeleting = true
                    Task {
                        _ = try? await viewState.http.disableAccount(mfaToken: ticket!.token).get()
                        _ = await viewState.signOut()
                        showSheet = false
                    }
                }) {
                    Text(isDeleting ? "Disabling..." : "Disable Account")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange))
                }
                .disabled(isDeleting)
                
                Button("Cancel") { showSheet = false }
                    .foregroundColor(.gray)
            }
            .padding(24)
        }
    }
}


fileprivate struct DeleteAccountSheet: View {
    @EnvironmentObject var viewState: AppViewState
    @Binding var showSheet: Bool
    @State var ticket: MFATicketResponse? = nil
    @State var isDeleting = false
    
    var body: some View {
        if ticket == nil {
            CreateMFATicketView(requestTicketType: .Password, doneCallback: { self.ticket = $0 })
        } else {
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.red)
                
                Text("Delete Account?")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                
                Text("Are you absolutely sure? Your account will be scheduled for permanent deletion in 7 days.")
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: {
                    isDeleting = true
                    Task {
                        _ = try? await viewState.http.deleteAccount(mfaToken: ticket!.token).get()
                        _ = await viewState.signOut()
                        showSheet = false
                    }
                }) {
                    Text(isDeleting ? "Deleting..." : "Permanently Delete")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.red))
                }
                .disabled(isDeleting)
                
                Button("Go Back") { showSheet = false }
                    .foregroundColor(.gray)
            }
            .padding(24)
        }
    }
}

struct UserSettings: View {
    @EnvironmentObject var viewState: AppViewState
    @Environment(\.colorScheme) var colorScheme
    
    // Everything here should be a sheet, no making navlinks!
    @State var presentGenerateCodesSheet = false
    @State var GenerateCodeSheetIsNotDismissable = false
    @State var presentAddTOTPSheet = false
    @State var presentRemoveTOTPSheet = false
    @State var presentChangeUsernameSheet = false
    @State var presentChangeEmailSheet = false
    @State var presentChangePasswordSheet = false
    @State var presentDisableAccountSheet = false
    @State var presentDeleteAccountSheet = false
    
    @State var emailSubstitute = "loading..."
    
    func substituteEmail(_ email: String) -> String {
        let groups = try! /(?<addr>[^@]+)\@(?<url>[^.]+)\.(?<domain>.+)/.wholeMatch(in: email)
        guard let groups = groups else { return "loading@loading.com" }
        
        // cursed
        let m1 = String(repeating: "•", count: groups.output.addr.count)
        let m2 = String(repeating: "•", count: groups.output.url.count)
        let m3 = String(repeating: "•", count: groups.output.domain.count)
        let resp = "\(m1)@\(m2).\(m3)"
        emailSubstitute = resp
        return resp
    }
    
    var body: some View {
        Form {
            // Account Info Section
            Section(header: Text("Account Info")) {
                Button(action: { presentChangeUsernameSheet = true }) {
                    HStack {
                        Image(systemName: "person.fill").foregroundColor(viewState.theme.accent.color).frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Username").font(.body).foregroundColor(.primary)
                            if let user = viewState.userSettingsStore.cache.user {
                                Text("\(user.username)#\(user.discriminator)")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else {
                                Text("loading...").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.gray.opacity(0.5)).font(.system(size: 14))
                    }
                }

                Button(action: { presentChangeEmailSheet = true }) {
                    HStack {
                        Image(systemName: "envelope.fill").foregroundColor(viewState.theme.accent.color).frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Email").font(.body).foregroundColor(.primary)
                            Text(verbatim: emailSubstitute)
                                .font(.caption).foregroundStyle(.secondary)
                                .onChange(of: viewState.userSettingsStore.cache.accountData?.email, { _, value in
                                    let raw = viewState.userSettingsStore.cache.accountData?.email
                                    guard let raw = raw else { return }
                                    _ = substituteEmail(raw)
                                })
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.gray.opacity(0.5)).font(.system(size: 14))
                    }
                }

                Button(action: { presentChangePasswordSheet = true }) {
                    HStack {
                        Image(systemName: "lock.fill").foregroundColor(viewState.theme.accent.color).frame(width: 24)
                        Text("Change Password").foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.gray.opacity(0.5)).font(.system(size: 14))
                    }
                }
            }

            // Two-Factor Auth Section
            Section(header: Text("Two-Factor Authentication")) {
                if viewState.userSettingsStore.cache.accountData?.mfaStatus == nil {
                    HStack {
                        ProgressView()
                        Text("Loading...").foregroundColor(.secondary).padding(.leading, 8)
                    }
                } else {
                    if !viewState.userSettingsStore.cache.accountData!.mfaStatus.anyMFA {
                        HStack {
                            Image(systemName: "exclamationmark.shield.fill").foregroundColor(.orange)
                            Text("Two-factor auth is not enabled").foregroundColor(.orange)
                        }
                    }

                    Button(action: { presentGenerateCodesSheet = true }) {
                        HStack {
                            Image(systemName: "key.fill").foregroundColor(.green).frame(width: 24)
                            Text(viewState.userSettingsStore.cache.accountData!.mfaStatus.recovery_active ? "Regenerate Recovery Codes" : "Generate Recovery Codes").foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.gray.opacity(0.5)).font(.system(size: 14))
                        }
                    }

                    if viewState.userSettingsStore.cache.accountData!.mfaStatus.totp_mfa {
                        Button(action: { presentRemoveTOTPSheet = true }) {
                            HStack {
                                Image(systemName: "minus.circle.fill").foregroundColor(.red).frame(width: 24)
                                Text("Disable Authenticator App").foregroundColor(.red)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(.gray.opacity(0.5)).font(.system(size: 14))
                            }
                        }
                    } else {
                        Button(action: { presentAddTOTPSheet = true }) {
                            HStack {
                                Image(systemName: "plus.app.fill").foregroundColor(.blue).frame(width: 24)
                                Text("Enable Authenticator App").foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(.gray.opacity(0.5)).font(.system(size: 14))
                            }
                        }
                    }
                }
            }

            // Danger Zone Section
            Section(header: Text("Danger Zone")) {
                Button(role: .destructive, action: { presentDisableAccountSheet = true }) {
                    HStack {
                        Image(systemName: "nosign").foregroundColor(.red).frame(width: 24)
                        Text("Disable Account")
                        Spacer()
                    }
                }

                Button(role: .destructive, action: { presentDeleteAccountSheet = true }) {
                    HStack {
                        Image(systemName: "trash.fill").foregroundColor(.red).frame(width: 24)
                        Text("Delete Account")
                        Spacer()
                    }
                }
            }
            .listRowBackground(Color.red.opacity(0.1))
        }
        .scrollContentBackground(.hidden)
        .background(viewState.theme.background.color.ignoresSafeArea())
        .toolbarBackground(.hidden, for: .navigationBar)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Account Settings")
            }
        }
        .tint(viewState.theme.accent.color)
        .refreshable {
            await viewState.userSettingsStore.fetchFromApi()
        }
        .onAppear {
            let raw = viewState.userSettingsStore.cache.accountData?.email
            guard let raw = raw else {
                Task {
                    await viewState.userSettingsStore.fetchFromApi()
                }
                return
            }
            emailSubstitute = substituteEmail(raw)

        }
        .sheet(isPresented: $presentGenerateCodesSheet, onDismiss: {
            Task {
                await viewState.userSettingsStore.fetchFromApi()
            }
        }) {
            SettingsSheetContainer(showSheet: $presentGenerateCodesSheet) {
                GenerateRecoveryCodesSheet(showSheet: $presentGenerateCodesSheet, sheetIsNotDismissable: $GenerateCodeSheetIsNotDismissable)
            }
            .presentationBackground(viewState.theme.background)
            .interactiveDismissDisabled(GenerateCodeSheetIsNotDismissable)
        }
        .sheet(isPresented: $presentAddTOTPSheet, onDismiss: {
            Task {
                await viewState.userSettingsStore.fetchFromApi()
            }
        }) {
            SettingsSheetContainer(showSheet: $presentAddTOTPSheet) {
                AddTOTPSheet(showSheet: $presentAddTOTPSheet)
            }
            .presentationBackground(viewState.theme.background)
        }
        .sheet(isPresented: $presentRemoveTOTPSheet, onDismiss: {
            Task {
                await viewState.userSettingsStore.fetchFromApi()
            }
        }) {
            SettingsSheetContainer(showSheet: $presentRemoveTOTPSheet) {
                RemoveTOTPSheet(showSheet: $presentRemoveTOTPSheet)
            }
            .presentationBackground(viewState.theme.background)
        }
        .sheet(isPresented: $presentChangeUsernameSheet, onDismiss: {
            Task {
                await viewState.userSettingsStore.fetchFromApi()
            }
        }) {
            SettingsSheetContainer(showSheet: $presentChangeUsernameSheet) {
                UsernameUpdateSheet(viewState: viewState, showSheet: $presentChangeUsernameSheet)
            }
            .presentationBackground(viewState.theme.background)
        }
        .sheet(isPresented: $presentChangePasswordSheet) {
            SettingsSheetContainer(showSheet: $presentChangePasswordSheet) {
                PasswordUpdateSheet(showSheet: $presentChangePasswordSheet)
            }
            .presentationBackground(viewState.theme.background)
        }
        .sheet(isPresented: $presentDisableAccountSheet) {
            SettingsSheetContainer(showSheet: $presentDisableAccountSheet) {
                DisableAccountSheet(showSheet: $presentDisableAccountSheet)
            }
            .presentationBackground(viewState.theme.background)
        }
        .sheet(isPresented: $presentDeleteAccountSheet) {
            SettingsSheetContainer(showSheet: $presentDeleteAccountSheet) {
                DeleteAccountSheet(showSheet: $presentDeleteAccountSheet)
            }
            .presentationBackground(viewState.theme.background)
        }
    }
}

