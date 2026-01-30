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

            Text("Upgrade to Pro")
                .font(.title)
                .fontWeight(.bold)

            Text("Unlock the full power of ClipArc")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            FeatureRow(icon: "infinity", title: "Unlimited History", description: "Keep all your clipboard items forever")
            FeatureRow(icon: "magnifyingglass", title: "Advanced Search", description: "Fuzzy search across all history")
            FeatureRow(icon: "keyboard", title: "Global Hotkey", description: "Quick access from anywhere")
            FeatureRow(icon: "bolt.fill", title: "Instant Paste", description: "Auto-paste to active app")
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

                    Text("Loading prices from App Store...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button("Retry") {
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
                Text("Subscribe")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(subscriptionManager.subscriptionProducts, id: \.id) { product in
                    PricingCard(
                        product: product,
                        isSelected: selectedProduct?.id == product.id,
                        isBestValue: product.id == SubscriptionProduct.yearly.rawValue,
                        badge: "14-day free trial"
                    ) {
                        selectedProduct = product
                    }
                }

                // Lifetime option
                if let lifetime = subscriptionManager.lifetimeProduct {
                    Divider()
                        .padding(.vertical, 4)

                    Text("One-time Purchase")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    PricingCard(
                        product: lifetime,
                        isSelected: selectedProduct?.id == lifetime.id,
                        isBestValue: false,
                        badge: "Pay once, own forever"
                    ) {
                        selectedProduct = lifetime
                    }
                }
            }
        }
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

            Button("Restore Purchases") {
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
        guard let product = selectedProduct else { return "Select a Plan" }
        if product.id == SubscriptionProduct.lifetime.rawValue {
            return "Purchase Lifetime"
        } else {
            return "Start Free Trial"
        }
    }

    private var footerSection: some View {
        VStack(spacing: 4) {
            Text("Cancel anytime. Subscription auto-renews.")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            HStack(spacing: 16) {
                Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
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
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(product.displayName)
                            .font(.headline)

                        if isBestValue {
                            Text("BEST VALUE")
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
                        Text("one-time")
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
        case .month: return "per month"
        case .year: return "per year"
        case .week: return "per week"
        case .day: return "per day"
        @unknown default: return ""
        }
    }
}

#Preview {
    SubscriptionView(subscriptionManager: SubscriptionManager.shared)
}
