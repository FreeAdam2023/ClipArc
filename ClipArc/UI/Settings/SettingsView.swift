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

            // TODO: Re-enable when cloud sync feature is implemented
            // AccountSettingsView()
            //     .tabItem {
            //         Label(L10n.Settings.account, systemImage: "person.circle")
            //     }

            SubscriptionSettingsView()
                .tabItem {
                    Label(L10n.Settings.subscription, systemImage: "crown")
                }

            AboutView()
                .tabItem {
                    Label(L10n.Settings.about, systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 520)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings
    @Environment(AppState.self) private var appState: AppState?
    @State private var permissionsManager = PermissionsManager.shared
    @State private var localizationManager = LocalizationManager.shared
    @State private var showRestartAlert = false
    @State private var showClearHistoryAlert = false
    @State private var historyCount: Int = 0

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

            Section(L10n.Settings.appearance) {
                Picker(L10n.Settings.appearance, selection: $settings.appearance) {
                    ForEach(AppAppearance.allCases, id: \.self) { appearance in
                        Text(appearance.displayName).tag(appearance)
                    }
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

            Section(L10n.DirectPaste.sectionTitle) {
                DirectPasteSettingsRow()
            }

            Section(L10n.Screenshot.title) {
                ScreenshotMonitorSettingsRow()
            }

            Section(L10n.Settings.storage) {
                // History count
                HStack {
                    Label(L10n.Settings.historyItems, systemImage: "clock.arrow.circlepath")
                    Spacer()
                    Text("\(historyCount) \(L10n.Settings.items)")
                        .foregroundStyle(.secondary)
                }

                // Clear all history button
                Button(action: {
                    showClearHistoryAlert = true
                }) {
                    HStack {
                        Label(L10n.Settings.clearAllHistory, systemImage: "trash")
                            .foregroundStyle(.red)
                        Spacer()
                    }
                }
                .alert(L10n.Settings.clearAllHistory, isPresented: $showClearHistoryAlert) {
                    Button(L10n.cancel, role: .cancel) { }
                    Button(L10n.delete, role: .destructive) {
                        clearAllHistory()
                    }
                } message: {
                    Text(L10n.Settings.clearHistoryMessage)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            historyCount = appState?.items.count ?? 0
        }
    }

    private func clearAllHistory() {
        appState?.clearAll()
        historyCount = 0
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

                    // Account status
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(L10n.Settings.accountLinked)
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

                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.accentColor)
                    }

                    // Title and description
                    VStack(spacing: 8) {
                        Text(L10n.Settings.memberAccount)
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(L10n.Settings.signInDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Benefits list
                    VStack(alignment: .leading, spacing: 12) {
                        AccountBenefitRow(icon: "crown", text: L10n.Settings.benefitMembership)
                        AccountBenefitRow(icon: "arrow.down.circle", text: L10n.Settings.benefitRestore)
                        AccountBenefitRow(icon: "apps.iphone", text: L10n.Settings.benefitMultiDevice)
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
    @State private var authManager = AuthManager.shared
    @State private var selectedPlan: String = "yearly"
    @State private var showLoginAlert = false

    var body: some View {
        VStack(spacing: 0) {
            if subscriptionManager.isPro {
                // Pro user view
                proUserView
            } else {
                // Upgrade view
                upgradeView
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var proUserView: some View {
        VStack(spacing: 24) {
            // Pro badge
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.yellow.opacity(0.3), .orange.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)

                Image(systemName: "crown.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.yellow)
            }

            VStack(spacing: 8) {
                Text(L10n.Settings.proBadge)
                    .font(.title2)
                    .fontWeight(.bold)

                if subscriptionManager.hasLifetimePurchase {
                    HStack(spacing: 4) {
                        Image(systemName: "infinity")
                        Text(L10n.Settings.lifetimeLicense)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(16)
                } else if let expDate = subscriptionManager.subscriptionExpirationDate {
                    Text(L10n.Settings.renewsOn.localized(with: expDate.formatted(date: .abbreviated, time: .omitted)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Features unlocked
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.Subscription.featuresUnlocked)
                    .font(.headline)
                    .padding(.bottom, 4)

                ProFeatureRow(icon: "infinity", text: L10n.ProFeature.unlimitedHistory, isUnlocked: true)
                ProFeatureRow(icon: "magnifyingglass", text: L10n.ProFeature.advancedSearch, isUnlocked: true)
                ProFeatureRow(icon: "keyboard", text: L10n.ProFeature.globalHotkey, isUnlocked: true)
                ProFeatureRow(icon: "bolt.fill", text: L10n.ProFeature.instantPaste, isUnlocked: true)
            }
            .padding(16)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(12)

            Spacer()

            // Manage subscription
            if !subscriptionManager.hasLifetimePurchase {
                Button(action: {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text(L10n.Settings.manageSubscription)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: 220)
            }
        }
    }

    private var upgradeView: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.yellow.opacity(0.2), .orange.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 70, height: 70)

                    Image(systemName: "crown.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.yellow)
                }

                Text(L10n.Settings.upgradeToPro)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(L10n.Settings.upgradeDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Features
            HStack(spacing: 16) {
                SubscriptionFeatureItem(icon: "infinity", title: "Unlimited")
                SubscriptionFeatureItem(icon: "magnifyingglass", title: "Search")
                SubscriptionFeatureItem(icon: "bolt.fill", title: "Fast")
            }
            .padding(.vertical, 8)

            // Pricing cards
            VStack(spacing: 10) {
                if subscriptionManager.products.isEmpty {
                    // Loading state - wait for real prices
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.0)

                        Text(L10n.Subscription.loadingPrices)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button(L10n.Subscription.retry) {
                            Task {
                                await subscriptionManager.loadProducts()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .frame(height: 120)
                } else {
                    ForEach(subscriptionManager.products, id: \.id) { product in
                        SettingsPricingCard(
                            title: product.displayName,
                            price: product.displayPrice,
                            period: product.subscription != nil ? "/\(product.subscription!.subscriptionPeriod.unit)" : "one-time",
                            badge: product.id.contains("yearly") ? "Save 44%" : (product.id.contains("lifetime") ? "Best Value" : nil),
                            isSelected: selectedPlan == product.id
                        ) {
                            selectedPlan = product.id
                            Task {
                                await subscriptionManager.purchase(product)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 300)

            // Restore purchases
            Button(L10n.Settings.restorePurchases) {
                Task {
                    await subscriptionManager.restorePurchases()
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.caption)

            if let error = subscriptionManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            // Legal links and subscription terms
            VStack(spacing: 4) {
                Text(L10n.Subscription.cancelAnytime)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                HStack(spacing: 12) {
                    Link(L10n.Settings.privacy, destination: URL(string: "https://www.versegates.com/cliparc/privacy")!)
                    Text("·").foregroundStyle(.tertiary)
                    Link(L10n.Settings.terms, destination: URL(string: "https://www.versegates.com/cliparc/terms")!)
                    Text("·").foregroundStyle(.tertiary)
                    Link(L10n.Settings.support, destination: URL(string: "https://www.versegates.com/cliparc/support")!)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }
    }
}

struct ProFeatureRow: View {
    let icon: String
    let text: String
    let isUnlocked: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.yellow)
                .frame(width: 20)

            Text(text)
                .font(.subheadline)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 14))
        }
    }
}

struct SubscriptionFeatureItem: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.yellow)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 70)
    }
}

struct SettingsPricingCard: View {
    let title: String
    let price: String
    let period: String
    let badge: String?
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if let badge = badge {
                            Text(badge)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(badge.contains("Save") ? Color.green : Color.orange)
                                .cornerRadius(4)
                        }
                    }
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(price)
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text(period)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            // App Icon from Assets
            Image("AppIconImage")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 128, height: 128)
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 5)

            VStack(spacing: 8) {
                Text(L10n.appName)
                    .font(.title)
                    .fontWeight(.bold)

                Text("\(L10n.Settings.version) \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(L10n.Settings.aboutDescription)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Spacer()

            // Links
            HStack(spacing: 24) {
                Link(destination: URL(string: "https://www.versegates.com/cliparc/support")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "questionmark.circle")
                        Text(L10n.Settings.support)
                    }
                }

                Link(destination: URL(string: "https://www.versegates.com/cliparc/privacy")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.raised")
                        Text(L10n.Settings.privacy)
                    }
                }

                Link(destination: URL(string: "https://www.versegates.com/cliparc/terms")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                        Text(L10n.Settings.terms)
                    }
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(L10n.About.copyright)
                .font(.caption2)
                .foregroundStyle(.quaternary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

// MARK: - Direct Paste Settings Row

struct DirectPasteSettingsRow: View {
    @State private var isAccessibilityGranted = DirectPasteCapabilityManager.shared.isAccessibilityGranted

    var body: some View {
        HStack {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.DirectPaste.title)
                        .font(.body)
                    Text(L10n.DirectPaste.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.yellow)
            }

            Spacer()

            // Status: Enabled or Enable button
            if isAccessibilityGranted {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(L10n.DirectPaste.enabled)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button(L10n.DirectPaste.enable) {
                    NotificationCenter.default.post(name: .showDirectPasteGuide, object: nil)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .onAppear {
            refreshPermissionStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissionStatus()
        }
    }

    private func refreshPermissionStatus() {
        isAccessibilityGranted = DirectPasteCapabilityManager.shared.isAccessibilityGranted
    }
}

// MARK: - Screenshot Monitor Settings Row

struct ScreenshotMonitorSettingsRow: View {
    private var screenshotMonitor = ScreenshotMonitor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.Screenshot.title)
                            .font(.body)
                        Text(L10n.Screenshot.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "camera.viewfinder")
                        .foregroundStyle(.purple)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { screenshotMonitor.isEnabled },
                    set: { newValue in
                        if newValue && !screenshotMonitor.hasFolderSelected {
                            // Turning on without folder: trigger folder selection
                            screenshotMonitor.selectFolder()
                        } else {
                            // Normal toggle behavior
                            screenshotMonitor.setEnabled(newValue)
                        }
                    }
                ))
                .toggleStyle(.switch)
            }

            // Feature highlight when not enabled
            if !screenshotMonitor.isEnabled {
                HStack(spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)

                    Text(L10n.Screenshot.tip)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.yellow.opacity(0.1))
                )
                .padding(.leading, 28)
            }

            // Only show folder path when enabled
            if screenshotMonitor.isEnabled, let path = screenshotMonitor.monitoredFolderPath {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.secondary)
                        Text(path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        Button(L10n.Screenshot.changeFolder) {
                            screenshotMonitor.selectFolder()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    // Info note about limitation
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                            .font(.caption)

                        Text(L10n.Screenshot.info)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.leading, 28)
            }
        }
    }
}

#Preview {
    SettingsView()
}
