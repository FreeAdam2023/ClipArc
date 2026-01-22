//
//  AuthManager.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import AuthenticationServices
import Foundation

@MainActor
@Observable
final class AuthManager: NSObject {
    static let shared = AuthManager()

    var isAuthenticated = false
    var userID: String?
    var userEmail: String?
    var userName: String?
    var isLoading = false
    var errorMessage: String?

    private let userIDKey = "appleUserID"
    private let userEmailKey = "appleUserEmail"
    private let userNameKey = "appleUserName"

    private override init() {
        super.init()
        loadStoredCredentials()
    }

    private func loadStoredCredentials() {
        if let storedUserID = UserDefaults.standard.string(forKey: userIDKey) {
            userID = storedUserID
            userEmail = UserDefaults.standard.string(forKey: userEmailKey)
            userName = UserDefaults.standard.string(forKey: userNameKey)
            isAuthenticated = true

            Task {
                await checkCredentialState()
            }
        }
    }

    func checkCredentialState() async {
        guard let userID = userID else { return }

        let provider = ASAuthorizationAppleIDProvider()
        do {
            let state = try await provider.credentialState(forUserID: userID)
            switch state {
            case .authorized:
                isAuthenticated = true
            case .revoked, .notFound:
                signOut()
            case .transferred:
                break
            @unknown default:
                break
            }
        } catch {
            print("Credential state check failed: \(error)")
        }
    }

    func signInWithApple() {
        isLoading = true
        errorMessage = nil

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.performRequests()
    }

    func signOut() {
        isAuthenticated = false
        userID = nil
        userEmail = nil
        userName = nil

        UserDefaults.standard.removeObject(forKey: userIDKey)
        UserDefaults.standard.removeObject(forKey: userEmailKey)
        UserDefaults.standard.removeObject(forKey: userNameKey)
    }

    private func saveCredentials(userID: String, email: String?, name: String?) {
        self.userID = userID
        self.userEmail = email
        self.userName = name
        self.isAuthenticated = true

        UserDefaults.standard.set(userID, forKey: userIDKey)
        if let email = email {
            UserDefaults.standard.set(email, forKey: userEmailKey)
        }
        if let name = name {
            UserDefaults.standard.set(name, forKey: userNameKey)
        }
    }
}

extension AuthManager: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            isLoading = false

            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userID = credential.user
                let email = credential.email
                let fullName = credential.fullName
                let name = [fullName?.givenName, fullName?.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")

                saveCredentials(
                    userID: userID,
                    email: email ?? self.userEmail,
                    name: name.isEmpty ? self.userName : name
                )
            }
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            isLoading = false

            if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .canceled:
                    errorMessage = nil
                case .failed:
                    errorMessage = "Authorization failed. Please try again."
                case .invalidResponse:
                    errorMessage = "Invalid response from Apple."
                case .notHandled:
                    errorMessage = "Authorization not handled."
                case .unknown:
                    errorMessage = "An unknown error occurred."
                case .notInteractive:
                    errorMessage = "Not interactive."
                @unknown default:
                    errorMessage = "An error occurred."
                }
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
}
