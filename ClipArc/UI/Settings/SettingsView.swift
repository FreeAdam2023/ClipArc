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
        Form {
            Section {
                if authManager.isAuthenticated {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(authManager.userName ?? "Apple User")
                                    .font(.headline)

                                if let email = authManager.userEmail {
                                    Text(email)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Divider()

                        Button(L10n.Settings.signOut) {
                            authManager.signOut()
                        }
                        .foregroundStyle(.red)
                    }
                    .padding(.vertical, 8)
                } else {
                    VStack(spacing: 16) {
                        Text(L10n.Settings.syncDescription)
                            .foregroundStyle(.secondary)

                        SignInWithAppleButton(.signIn, onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        }, onCompletion: { result in
                            handleSignIn(result)
                        })
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 44)
                        .frame(maxWidth: 240)
                        .cornerRadius(8)

                        if let error = authManager.errorMessage {
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
