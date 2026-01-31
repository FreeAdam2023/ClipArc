//
//  OnboardingView.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import AuthenticationServices
import StoreKit
import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case permissions
    // case login  // TODO: Re-enable when cloud sync feature is implemented
    case subscription
    case complete
}

struct OnboardingView: View {
    @Bindable var appState: AppState
    @State private var currentStep: OnboardingStep = .welcome
    var onComplete: () -> Void

    var body: some View {
        VStack {
            switch currentStep {
            case .welcome:
                WelcomeStepView(onNext: { currentStep = .permissions })

            case .permissions:
                // Skip directly to subscription (login removed for now)
                PermissionsStepView(onNext: { currentStep = .subscription }, onSkip: { currentStep = .subscription })

            // TODO: Re-enable when cloud sync feature is implemented
            // case .login:
            //     LoginStepView(
            //         authManager: appState.authManager,
            //         onNext: { currentStep = .subscription },
            //         onSkip: { currentStep = .subscription }
            //     )

            case .subscription:
                SubscriptionStepView(
                    subscriptionManager: appState.subscriptionManager,
                    onNext: { currentStep = .complete },
                    onSkip: { currentStep = .complete }
                )

            case .complete:
                CompleteStepView(onFinish: {
                    appState.completeOnboarding()
                    onComplete()
                })
            }
        }
        .frame(width: 500, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Welcome Step

struct WelcomeStepView: View {
    var onNext: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "clipboard")
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 12) {
                Text(L10n.Onboarding.welcomeTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(L10n.Onboarding.welcomeSubtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                FeatureItem(icon: "clock.arrow.circlepath", title: L10n.Onboarding.featureHistoryTitle, description: L10n.Onboarding.featureHistoryDesc)
                FeatureItem(icon: "magnifyingglass", title: L10n.Onboarding.featureSearchTitle, description: L10n.Onboarding.featureSearchDesc)
                FeatureItem(icon: "keyboard", title: L10n.Onboarding.featureHotkeyTitle, description: L10n.Onboarding.featureHotkeyDesc)
                FeatureItem(icon: "camera.viewfinder", title: "Auto-capture Screenshots", description: "Save screenshots to history automatically")
            }
            .frame(maxWidth: 320)

            Spacer()

            Button(L10n.Onboarding.getStarted) {
                onNext()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer().frame(height: 40)
        }
    }
}

struct FeatureItem: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Permissions Step

struct PermissionsStepView: View {
    @State private var permissionsManager = PermissionsManager.shared
    @State private var hasLaunchAtLogin = PermissionsManager.shared.isLaunchAtLoginEnabled
    @State private var refreshTimer: Timer?
    var onNext: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "gearshape.2")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 12) {
                Text(L10n.Onboarding.permissionsTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(L10n.Onboarding.permissionsSubtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                PermissionRow(
                    icon: "power",
                    title: L10n.Onboarding.launchAtLoginTitle,
                    description: L10n.Onboarding.launchAtLoginDesc,
                    isGranted: hasLaunchAtLogin,
                    action: {
                        permissionsManager.isLaunchAtLoginEnabled = true
                        hasLaunchAtLogin = true
                    }
                )
            }
            .padding(.horizontal, 40)
            .onAppear {
                startPermissionPolling()
            }
            .onDisappear {
                stopPermissionPolling()
            }

            Spacer()

            VStack(spacing: 12) {
                Button(L10n.continue_) {
                    onNext()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(L10n.skipForNow) {
                    onSkip()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.footnote)
            }

            Spacer().frame(height: 40)
        }
    }

    private func startPermissionPolling() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                hasLaunchAtLogin = permissionsManager.isLaunchAtLoginEnabled
            }
        }
    }

    private func stopPermissionPolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(isGranted ? .green : .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button(L10n.enable) {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.05))
        )
    }
}

// MARK: - Login Step

struct LoginStepView: View {
    @Bindable var authManager: AuthManager
    var onNext: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "person.crop.circle")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 12) {
                Text(L10n.Onboarding.signInTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(L10n.Onboarding.signInSubtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if authManager.isAuthenticated {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)

                    Text(L10n.Onboarding.signedInAs)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(authManager.userName ?? authManager.userEmail ?? "Apple User")
                        .font(.headline)
                }
                .padding()
            } else {
                SignInWithAppleButton(.signIn, onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                }, onCompletion: { result in
                    handleSignIn(result)
                })
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .frame(maxWidth: 280)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if authManager.isLoading {
                    ProgressView()
                }

                if let error = authManager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            VStack(spacing: 12) {
                Button(authManager.isAuthenticated ? L10n.continue_ : L10n.skip) {
                    if authManager.isAuthenticated {
                        onNext()
                    } else {
                        onSkip()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if !authManager.isAuthenticated {
                    Text(L10n.Onboarding.signInLater)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer().frame(height: 40)
        }
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
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                authManager.errorMessage = nil
            } else {
                authManager.errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Subscription Step

struct SubscriptionStepView: View {
    @Bindable var subscriptionManager: SubscriptionManager
    var onNext: () -> Void
    var onSkip: () -> Void

    @State private var selectedProduct: Product?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)

            VStack(spacing: 8) {
                Text(L10n.Onboarding.subscriptionTitle)
                    .font(.title)
                    .fontWeight(.bold)

                Text(L10n.Onboarding.subscriptionSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Benefits list
            VStack(alignment: .leading, spacing: 8) {
                BenefitRow(text: L10n.Onboarding.benefit1)
                BenefitRow(text: L10n.Onboarding.benefit2)
                BenefitRow(text: L10n.Onboarding.benefit3)
                BenefitRow(text: L10n.Onboarding.benefit4)
            }
            .padding(.horizontal, 48)

            if subscriptionManager.isSubscribed {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)

                    Text(L10n.Onboarding.youArePro)
                        .font(.headline)
                }
            } else if subscriptionManager.products.isEmpty {
                // Loading state - wait for real prices
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)

                    Text(L10n.Subscription.loadingPrices)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button(L10n.Subscription.retry) {
                        Task {
                            await subscriptionManager.loadProducts()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.vertical, 32)
            } else {
                // Real products loaded
                VStack(spacing: 10) {
                    ForEach(subscriptionManager.products, id: \.id) { product in
                        CompactPricingCard(
                            product: product,
                            isSelected: selectedProduct?.id == product.id,
                            isBestValue: product.id == SubscriptionProduct.yearly.rawValue
                        ) {
                            selectedProduct = product
                        }
                    }
                }
                .padding(.horizontal, 32)

                Button(action: {
                    Task {
                        if let product = selectedProduct {
                            let success = await subscriptionManager.purchase(product)
                            if success {
                                onNext()
                            }
                        }
                    }
                }) {
                    HStack {
                        if subscriptionManager.isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                        }
                        Text(L10n.Onboarding.subscribe)
                            .fontWeight(.semibold)
                    }
                    .frame(width: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selectedProduct == nil || subscriptionManager.isLoading)
            }

            if let error = subscriptionManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()

            VStack(spacing: 8) {
                if subscriptionManager.isSubscribed {
                    Button(L10n.continue_) {
                        onNext()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button(L10n.Subscription.continueFree) {
                        onSkip()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    // Restore purchases
                    Button(L10n.Subscription.restorePurchases) {
                        Task {
                            await subscriptionManager.restorePurchases()
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            // Legal links and subscription terms
            VStack(spacing: 6) {
                Text(L10n.OnboardingExtra.subscriptionNote)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    Link(L10n.Subscription.privacyPolicy, destination: URL(string: "https://www.versegates.com/cliparc/privacy")!)
                    Text("·").foregroundStyle(.tertiary)
                    Link(L10n.Subscription.termsOfService, destination: URL(string: "https://www.versegates.com/cliparc/terms")!)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)

            Spacer().frame(height: 20)
        }
        .onAppear {
            selectedProduct = subscriptionManager.yearlyProduct
            if subscriptionManager.products.isEmpty {
                Task {
                    await subscriptionManager.loadProducts()
                }
            }
        }
    }
}

struct CompactPricingCard: View {
    let product: Product
    let isSelected: Bool
    let isBestValue: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(.headline)

                        if isBestValue {
                            Text(L10n.Onboarding.save44)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                    }

                    Text(periodDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var periodDescription: String {
        if product.id == SubscriptionProduct.monthly.rawValue {
            return "per month"
        } else if product.id == SubscriptionProduct.yearly.rawValue {
            return "per year"
        } else {
            return "one-time purchase"
        }
    }
}

// MARK: - Complete Step

struct CompleteStepView: View {
    var onFinish: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            VStack(spacing: 12) {
                Text(L10n.Onboarding.completeTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(L10n.Onboarding.completeSubtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                TipItem(shortcut: "⇧⌘V", description: L10n.Onboarding.tipOpen)
                TipItem(shortcut: "← →", description: L10n.Onboarding.tipNavigate)
                TipItem(shortcut: "Enter", description: L10n.Onboarding.tipPaste)
                TipItem(shortcut: "Esc", description: L10n.Onboarding.tipClose)
            }
            .padding(.horizontal, 60)

            Spacer()

            Button(L10n.Onboarding.startUsing) {
                onFinish()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer().frame(height: 40)
        }
    }
}

struct TipItem: View {
    let shortcut: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .frame(width: 60, alignment: .trailing)

            Text(description)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }
}

struct BenefitRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.green)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()
        }
    }
}

#Preview {
    OnboardingView(appState: AppState(), onComplete: {})
}
