import sys

with open('Stoat/Pages/Settings/UserSettings.swift', 'r') as f:
    lines = f.readlines()

new_lines = []
in_body = False
in_scrollview = False

for i, line in enumerate(lines):
    if line.strip() == "var body: some View {":
        in_body = True
        new_lines.append(line)
        continue
        
    if in_body and not in_scrollview and "ScrollView {" in line:
        in_scrollview = True
        new_lines.extend("""        Form {
            // Account Info Section
            Section(header: Text("Account Info")) {
                Button(action: { presentChangeUsernameSheet = true }) {
                    HStack {
                        Image(systemName: "person.fill").foregroundColor(.purple).frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Username").font(.body).foregroundColor(.primary)
                            if let user = viewState.userSettingsStore.cache.user {
                                Text("\\(user.username)#\\(user.discriminator)")
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
                        Image(systemName: "envelope.fill").foregroundColor(.purple).frame(width: 24)
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
                        Image(systemName: "lock.fill").foregroundColor(.purple).frame(width: 24)
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

                    if viewState.userSettingsStore.cache.accountData!.mfaStatus.totp_active {
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
        .tint(.purple)
        .refreshable {
            await viewState.userSettingsStore.fetchFromApi()
        }
        .onAppear {
""".splitlines(keepends=True))
        continue
        
    if in_scrollview and line.strip() == ".onAppear {":
        in_scrollview = False
        continue
    
    if not in_scrollview:
        new_lines.append(line)

with open('Stoat/Pages/Settings/UserSettings.swift', 'w') as f:
    f.writelines(new_lines)
