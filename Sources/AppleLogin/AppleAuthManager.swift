//
//  AppleAuthManager.swift
//  
//
//  Created by bemohansingh on 9/15/20.
//

import Foundation
import Foundation
import AuthenticationServices
import Combine

public enum AppleAuthError: LocalizedError {
    case canceled
    case other(Error)
    case custom(String)
    
   public var errorDescription: String? {
        switch self {
        case .other( let error):
            return error.localizedDescription
        case .custom(let errorText):
            return errorText
        default:
            return ""
        }
    }
}

public final class AppleAuthManager: NSObject {
    
    /// The apple ID Provider
    private let appleIDProvider: ASAuthorizationAppleIDProvider
    
    /// The request with provider
    private let request: ASAuthorizationAppleIDRequest
    
    /// auth instance for the request
    private let authorizationController: ASAuthorizationController
    
    /// The publisher for apple auth
    public let appleResponse = PassthroughSubject<Result<AppleUser, AppleAuthError>, Never>()
    
    /// Initializer
    public init(appleIDProvider: ASAuthorizationAppleIDProvider = ASAuthorizationAppleIDProvider()) {
        self.appleIDProvider = appleIDProvider
        self.request = appleIDProvider.createRequest()
        self.authorizationController = ASAuthorizationController(authorizationRequests: [request])
    }
    
    /// performs login
    /// - Parameter provider: ASAuthorizationControllerPresentationContextProviding
    public func performLogin(from provider: ASAuthorizationControllerPresentationContextProviding) {
        
        // set the request operation
        request.requestedOperation = .operationLogin
        
        //set the scopes
        request.requestedScopes = [.fullName, .email]
        
        // start the auth flow
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = provider
        authorizationController.performRequests()
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AppleAuthManager : ASAuthorizationControllerDelegate {
    
    /// when authorization completes with error
    /// - Parameters:
    ///   - controller: ASAuthorizationController
    ///   - error: Error
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        var applAuthError: AppleAuthError = .other(error)
        if let authError = error as? ASAuthorizationError,
        authError.code == ASAuthorizationError.canceled || authError.code == ASAuthorizationError.unknown {
            applAuthError = .canceled
        }
        appleResponse.send(.failure(applAuthError))
    }
    
    /// when authorization completes with success
    /// - Parameters:
    ///   - controller: ASAuthorizationController
    ///   - authorization: ASAuthorization
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            
            /// check if we have proper login token
            guard let token = appleIDCredential.identityToken,
                let identityTokenString = String(data: token, encoding: .utf8),
                let authData = appleIDCredential.authorizationCode,
                let authToken = String(data: authData, encoding: .utf8)  else {
                    appleResponse.send(.failure(.custom("Unable to verify identity for your apple account. Please try again later")))
                    return
            }
            
            //set the result if we have info
            let firstName = appleIDCredential.fullName?.givenName ?? ""
            let email = appleIDCredential.email
            let lastName = appleIDCredential.fullName?.familyName ?? ""
            
            // set the credential info
            let credentialInfo = ["userId": appleIDCredential.user,
                                  "authToken": authToken,
                                  "idToken": identityTokenString,
                                  "firstName": firstName ,
                                  "lastName": lastName,
                                  "email": email]
            
            // create the apple user data
            do {
                let data = try JSONSerialization.data(withJSONObject: credentialInfo, options: .prettyPrinted)
                let appleUser = try JSONDecoder().decode(AppleUser.self, from: data)
                
                //trigger the user data to listener
                appleResponse.send(.success(appleUser))
            } catch {
                appleResponse.send(.failure(.custom("Unable to verify identity for your apple account. Please try again later")))
            }
        } else {
            appleResponse.send(.failure(.custom("Unable to use apple id for authorization at the moment. Please try again later")))
        }
    }
}
