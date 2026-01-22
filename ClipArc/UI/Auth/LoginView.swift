//
//  LoginView.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @Bindable var authManager: AuthManager
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "clipboard")
                    .font(.system(size: 72))
                    .foregroundStyle(Color.accentColor)

                Text("ClipArc")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Your Smart Clipboard Manager")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 16) {
                Text("Sign in to sync your clipboard history and unlock all features")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                SignInWithAppleButton(.signIn, onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                }, onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        handleAuthorization(authorization)
                    case .failure(let error):
                        authManager.errorMessage = error.localizedDescription
                    }
                })
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .frame(maxWidth: 280)
                .cornerRadius(8)

                if authManager.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                }

                if let error = authManager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            VStack(spacing: 8) {
                Button("Continue without signing in") {
                    onComplete()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.footnote)

                Text("Some features require subscription")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.bottom, 20)
        }
        .frame(minWidth: 400, minHeight: 500)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func handleAuthorization(_ authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userID = credential.user
            let email = credential.email
            let fullName = credential.fullName
            let name = [fullName?.givenName, fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            Task { @MainActor in
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

                onComplete()
            }
        }
    }
}

#Preview {
    LoginView(authManager: AuthManager.shared, onComplete: {})
}
