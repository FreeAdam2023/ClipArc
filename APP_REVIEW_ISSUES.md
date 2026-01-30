# App Review Issues - ClipArc

**Submission ID:** e5a4a99b-3f72-47c6-91b2-b7340452d535
**Review Date:** January 23, 2026
**Version:** 26.0.0

---

## Issue 1: Guideline 2.4.5 - Accessibility Misuse

**Status:** ❌ Not Resolved

**Apple's Feedback:**
> The app requests access to Accessibility features on macOS but does not use these features for accessibility purposes. Specifically, the app uses Accessibility features for automation purposes.

**Affected Code:**
- `ClipArc/Core/Services/PasteService.swift:106` - `AXIsProcessTrusted()`
- `ClipArc/Core/Services/PasteService.swift:127-157` - `simulatePaste()` using CGEvent
- `ClipArc/UI/Components/AccessibilitySetupView.swift` - Accessibility setup UI

**Root Cause:**
The app uses Accessibility API to simulate Cmd+V keystrokes for "direct paste" functionality. Apple does not allow this in Mac App Store apps.

**Resolution Options:**
1. **Remove direct paste feature** - Keep only "copy to clipboard", user manually pastes
2. **Distribute outside Mac App Store** - Direct distribution can use these APIs
3. **Submit Feedback Assistant** - Request new API from Apple (unlikely to succeed)

**Chosen Solution:** TBD

---

## Issue 2: Guideline 2.1 - IAP Products Not Submitted

**Status:** 🔄 In Progress

**Apple's Feedback:**
> The app includes references to Pro Subscription but the associated in-app purchase products have not been submitted for review.

**Affected Code:**
- `ClipArc/Core/Subscription/SubscriptionManager.swift` - Product IDs defined
- `ClipArc/UI/Subscription/SubscriptionView.swift` - Subscription UI

**Chosen Solution:** Create IAP products in App Store Connect

---

### App Store Connect IAP Setup Guide

#### Products to Create:

| Product ID | Type | Price | Duration |
|------------|------|-------|----------|
| `com.versegates.cliparc.pro.monthly` | Auto-Renewable Subscription | $2.99 | 1 Month |
| `com.versegates.cliparc.pro.yearly` | Auto-Renewable Subscription | $19.99 | 1 Year |
| `com.versegates.cliparc.lifetime` | Non-Consumable | $59.99 | Lifetime |

#### Step 1: Create Subscription Group (for monthly & yearly)

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select **ClipArc** app → **Monetization** → **Subscriptions**
3. Click **Create** to create a Subscription Group
4. Group name: `ClipArc Pro`
5. Reference name: `cliparc_pro_subscriptions`

#### Step 2: Create Monthly Subscription

1. In the subscription group, click **Create** → **Subscription**
2. Fill in:
   - **Reference Name:** `Pro Monthly`
   - **Product ID:** `com.versegates.cliparc.pro.monthly`
3. Set subscription duration: **1 Month**
4. Add pricing: **$2.99 USD** (Tier 3)
5. Add localization:
   - **Display Name:** `ClipArc Pro Monthly`
   - **Description:** `Unlimited clipboard history, advanced search, and instant paste. Billed monthly.`
6. Add **App Store Review Screenshot** (required)
7. Save

#### Step 3: Create Yearly Subscription

1. In the same subscription group, click **Create** → **Subscription**
2. Fill in:
   - **Reference Name:** `Pro Yearly`
   - **Product ID:** `com.versegates.cliparc.pro.yearly`
3. Set subscription duration: **1 Year**
4. Add pricing: **$19.99 USD** (Tier 30)
5. Add localization:
   - **Display Name:** `ClipArc Pro Yearly`
   - **Description:** `Unlimited clipboard history, advanced search, and instant paste. Billed annually. Save 44%!`
6. Add **App Store Review Screenshot** (required)
7. Save

#### Step 4: Create Lifetime Purchase (Non-Consumable)

1. Go to **Monetization** → **In-App Purchases**
2. Click **Create** → **Non-Consumable**
3. Fill in:
   - **Reference Name:** `Lifetime License`
   - **Product ID:** `com.versegates.cliparc.lifetime`
4. Add pricing: **$59.99 USD** (Tier 60)
5. Add localization:
   - **Display Name:** `ClipArc Pro Lifetime`
   - **Description:** `Unlock all Pro features forever with a one-time purchase. No subscription required.`
6. Add **App Store Review Screenshot** (required)
7. Save

#### Step 5: Configure Free Trial (Optional)

1. For each subscription, go to **Subscription Prices** → **Introductory Offers**
2. Create offer:
   - **Type:** Free Trial
   - **Duration:** 14 days
   - **Eligibility:** New subscribers only

#### Step 6: Submit for Review

1. Ensure all products show **Ready to Submit** status
2. When submitting app update, select all IAP products to include
3. Make sure screenshots are provided for each product

#### Checklist

- [ ] Subscription group created: `ClipArc Pro`
- [ ] Monthly subscription created with screenshot
- [ ] Yearly subscription created with screenshot
- [ ] Lifetime purchase created with screenshot
- [ ] Free trials configured (optional)
- [ ] All products in "Ready to Submit" status
- [ ] IAP products selected when submitting app

---

## Action Items

- [ ] Resolve Issue 2 (IAP)
- [ ] Resolve Issue 1 (Accessibility)
- [ ] Resubmit to App Review

---

*Last Updated: January 30, 2026*
