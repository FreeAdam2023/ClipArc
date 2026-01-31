//
//  SubscriptionView.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import StoreKit
import SwiftUI

struct SubscriptionView: View {
    @Bindable var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    var onSubscribed: (() -> Void)?

    @State private var selectedProduct: Product?

    var body: some View {
        VStack(spacing: 20) {
            headerSection

            Divider()

            featuresSection

            Divider()

            pricingSection

            actionButtons

            footerSection
        }
        .padding(24)
        .frame(width: 450, height: 650)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            selectedProduct = subscriptionManager.yearlyProduct
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)

            Text(L10n.Subscription.upgradeToPro)
                .font(.title)
                .fontWeight(.bold)

            Text(L10n.Subscription.unlockFullPower)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            FeatureRow(icon: "infinity", title: L10n.Subscription.featureUnlimitedHistory, description: L10n.Subscription.featureUnlimitedHistoryDesc)
            FeatureRow(icon: "magnifyingglass", title: L10n.Subscription.featureAdvancedSearch, description: L10n.Subscription.featureAdvancedSearchDesc)
            FeatureRow(icon: "keyboard", title: L10n.Subscription.featureGlobalHotkey, description: L10n.Subscription.featureGlobalHotkeyDesc)
            FeatureRow(icon: "bolt.fill", title: L10n.Subscription.featureInstantPaste, description: L10n.Subscription.featureInstantPasteDesc)
        }
        .padding(.horizontal, 8)
    }

    private var pricingSection: some View {
        VStack(spacing: 12) {
            if subscriptionManager.products.isEmpty {
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
                .frame(height: 150)
            } else {
                // Subscription options
                Text(L10n.Subscription.subscribe)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(subscriptionManager.subscriptionProducts, id: \.id) { product in
                    PricingCard(
                        product: product,
                        isSelected: selectedProduct?.id == product.id,
                        isBestValue: product.id == SubscriptionProduct.yearly.rawValue,
                        badge: L10n.Subscription.freeTrialBadge
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedProduct = product
                        }
                    }
                }

                // Lifetime option
                if let lifetime = subscriptionManager.lifetimeProduct {
                    Divider()
                        .padding(.vertical, 4)

                    Text(L10n.Subscription.oneTimePurchase)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    PricingCard(
                        product: lifetime,
                        isSelected: selectedProduct?.id == lifetime.id,
                        isBestValue: false,
                        badge: L10n.Subscription.payOnce
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedProduct = lifetime
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: selectedProduct?.id)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                Task {
                    if let product = selectedProduct {
                        let success = await subscriptionManager.purchase(product)
                        if success {
                            onSubscribed?()
                            dismiss()
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
                    Text(buttonTitle)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedProduct == nil || subscriptionManager.isLoading)

            Button(L10n.Subscription.restorePurchases) {
                Task {
                    await subscriptionManager.restorePurchases()
                    if subscriptionManager.isPro {
                        onSubscribed?()
                        dismiss()
                    }
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.footnote)

            if let error = subscriptionManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var buttonTitle: String {
        guard let product = selectedProduct else { return L10n.Subscription.selectPlan }
        if product.id == SubscriptionProduct.lifetime.rawValue {
            return L10n.Subscription.purchaseLifetime
        } else {
            return L10n.Subscription.startFreeTrial
        }
    }

    private var footerSection: some View {
        VStack(spacing: 4) {
            Text(L10n.Subscription.cancelAnytime)
                .font(.caption2)
                .foregroundStyle(.tertiary)

            HStack(spacing: 16) {
                Link(L10n.Subscription.termsOfService, destination: URL(string: "https://www.versegates.com/cliparc/terms")!)
                Link(L10n.Subscription.privacyPolicy, destination: URL(string: "https://www.versegates.com/cliparc/privacy")!)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Pricing Card (with actual StoreKit Product)

struct PricingCard: View {
    let product: Product
    let isSelected: Bool
    let isBestValue: Bool
    let badge: String?
    let onSelect: () -> Void

    init(product: Product, isSelected: Bool, isBestValue: Bool, badge: String? = nil, onSelect: @escaping () -> Void) {
        self.product = product
        self.isSelected = isSelected
        self.isBestValue = isBestValue
        self.badge = badge
        self.onSelect = onSelect
    }

    var body: some View {
        Button(action: {
            // Dispatch to next run loop to avoid StoreKit view hierarchy issues
            DispatchQueue.main.async {
                onSelect()
            }
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(product.displayName)
                            .font(.headline)

                        if isBestValue {
                            Text(L10n.Subscription.bestValue)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                    }

                    if let badge = badge {
                        Text(badge)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.title3)
                        .fontWeight(.semibold)

                    if let subscription = product.subscription {
                        Text(periodText(subscription.subscriptionPeriod))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(L10n.Subscription.oneTime)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func periodText(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .month: return L10n.Subscription.perMonth
        case .year: return L10n.Subscription.perYear
        case .week: return L10n.Subscription.perWeek
        case .day: return L10n.Subscription.perDay
        @unknown default: return ""
        }
    }
}

#Preview {
    SubscriptionView(subscriptionManager: SubscriptionManager.shared)
}
