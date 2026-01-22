//
//  SettingsView.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import AuthenticationServices
import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState: AppState?
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        TabView {
            GeneralSettingsView(settings: settings)
                .tabItem {
                    Label(L10n.Settings.general, systemImage: "gear")
                }

            AccountSettingsView()
                .tabItem {
                    Label(L10n.Settings.account, systemImage: "person.circle")
                }

            SubscriptionSettingsView()
                .tabItem {
                    Label(L10n.Settings.subscription, systemImage: "crown")
                }

            AboutView()
                .tabItem {
                    Label(L10n.Settings.about, systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var permissionsManager = PermissionsManager.shared
    @State private var localizationManager = LocalizationManager.shared
    @State private var showRestartAlert = false

    var body: some View {
        Form {
            Section {
                Picker(L10n.Settings.historyLimit, selection: $settings.historyLimit) {
                    Text("50 \(L10n.Settings.items)").tag(50)
                    Text("100 \(L10n.Settings.items)").tag(100)
                    Text("200 \(L10n.Settings.items)").tag(200)
                    Text("500 \(L10n.Settings.items)").tag(500)
                }
            }

            Section(L10n.Settings.startup) {
                Toggle(L10n.Settings.launchAtLogin, isOn: $permissionsManager.isLaunchAtLoginEnabled)
                Toggle(L10n.Settings.showInDock, isOn: $settings.showInDock)
            }

            Section(L10n.Settings.language) {
                Picker(L10n.Settings.language, selection: $localizationManager.currentLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .onChange(of: localizationManager.currentLanguage) { _, _ in
                    showRestartAlert = true
                }

                if showRestartAlert {
                    Text(L10n.Settings.restartRequired)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section(L10n.Settings.hotkey) {
                HStack {
                    Text(L10n.Settings.globalHotkey)
                    Spacer()
                    Text("⇧⌘V")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.primary.opacity(0.1))
                        )
                }
            }

            Section(L10n.Settings.permissions) {
                HStack {
                    Text(L10n.Onboarding.accessibilityTitle)
                    Spacer()
                    if permissionsManager.hasAccessibilityPermission {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(L10n.Settings.granted)
                            .foregroundStyle(.secondary)
                    } else {
                        Button(L10n.enable) {
                            permissionsManager.requestAccessibilityPermission()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .help(L10n.Onboarding.accessibilityDesc)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AccountSettingsView: View {
    @State private var authManager = AuthManager.shared

    var body: some View {
        VStack(spacing: 0) {
            if authManager.isAuthenticated {
                // Signed in state
                VStack(spacing: 20) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 80, height: 80)

                        Text(authManager.userName?.prefix(1).uppercased() ?? "U")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: 4) {
                        Text(authManager.userName ?? "Apple User")
                            .font(.title2)
                            .fontWeight(.semibold)

                        if let email = authManager.userEmail {
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Sync status
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.icloud.fill")
                            .foregroundStyle(.green)
                        Text("Synced")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(16)

                    Spacer()

                    // Sign out button
                    Button(action: {
                        authManager.signOut()
                    }) {
                        Text(L10n.Settings.signOut)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .frame(maxWidth: 200)
                }
                .padding(32)
            } else {
                // Not signed in state
                VStack(spacing: 24) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.1))
                            .frame(width: 80, height: 80)

                        Image(systemName: "icloud.and.arrow.up")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.accentColor)
                    }

                    // Title and description
                    VStack(spacing: 8) {
                        Text("iCloud Sync")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(L10n.Settings.syncDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Benefits list
                    VStack(alignment: .leading, spacing: 12) {
                        AccountBenefitRow(icon: "arrow.triangle.2.circlepath", text: "Sync clipboard across all devices")
                        AccountBenefitRow(icon: "lock.shield", text: "End-to-end encryption")
                        AccountBenefitRow(icon: "arrow.clockwise.icloud", text: "Automatic backup")
                    }
                    .padding(.vertical, 8)

                    // Sign in button
                    SignInWithAppleButton(.signIn, onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    }, onCompletion: { result in
                        handleSignIn(result)
                    })
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .frame(maxWidth: 280)
                    .cornerRadius(10)

                    if let error = authManager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userID = credential.user
                let email = credential.email
                let fullName = credential.fullName
                let name = [fullName?.givenName, fullName?.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")

                authManager.userID = userID
                authManager.userEmail = email ?? authManager.userEmail
                authManager.userName = name.isEmpty ? authManager.userName : name
                authManager.isAuthenticated = true

                UserDefaults.standard.set(userID, forKey: "appleUserID")
                if let email = email {
                    UserDefaults.standard.set(email, forKey: "appleUserEmail")
                }
                if !name.isEmpty {
                    UserDefaults.standard.set(name, forKey: "appleUserName")
                }
            }
        case .failure(let error):
            authManager.errorMessage = error.localizedDescription
        }
    }
}

struct AccountBenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct SubscriptionSettingsView: View {
    @State private var subscriptionManager = SubscriptionManager.shared

    var body: some View {
        Form {
            Section {
                if subscriptionManager.isPro {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "crown.fill")
                                .font(.title)
                                .foregroundStyle(.yellow)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.Settings.proBadge)
                                    .font(.headline)

                                if subscriptionManager.hasLifetimePurchase {
                                    Text(L10n.Settings.lifetimeLicense)
                                        .font(.subheadline)
                                        .foregroundStyle(.green)
                                } else if let expDate = subscriptionManager.subscriptionExpirationDate {
                                    Text(L10n.Settings.renewsOn.localized(with: expDate.formatted(date: .abbreviated, time: .omitted)))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Divider()

                        if !subscriptionManager.hasLifetimePurchase {
                            Button(L10n.Settings.manageSubscription) {
                                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "crown")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)

                        Text(L10n.Settings.upgradeToPro)
                            .font(.headline)

                        Text(L10n.Settings.upgradeDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        VStack(spacing: 8) {
                            ForEach(subscriptionManager.products, id: \.id) { product in
                                Button(action: {
                                    Task {
                                        await subscriptionManager.purchase(product)
                                    }
                                }) {
                                    HStack {
                                        Text(product.displayName)
                                        Spacer()
                                        Text(product.displayPrice)
                                            .fontWeight(.semibold)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .frame(maxWidth: 280)

                        Button(L10n.Settings.restorePurchases) {
                            Task {
                                await subscriptionManager.restorePurchases()
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .font(.footnote)

                        if let error = subscriptionManager.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "clipboard")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text(L10n.appName)
                .font(.title)
                .fontWeight(.semibold)

            Text("\(L10n.Settings.version) 1.0.0")
                .foregroundStyle(.secondary)

            Text(L10n.Settings.aboutDescription)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: 20) {
                Link(L10n.Settings.website, destination: URL(string: "https://example.com")!)
                Link(L10n.Settings.privacy, destination: URL(string: "https://example.com/privacy")!)
                Link(L10n.Settings.terms, destination: URL(string: "https://example.com/terms")!)
            }
            .font(.footnote)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    SettingsView()
}
