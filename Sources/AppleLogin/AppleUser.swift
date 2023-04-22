//
//  AppleUser.swift
//  
//
//  Created by bemohansingh on 9/15/20.
//

import Foundation

/// The structure of the data we get from doing apple login
public struct AppleUser: Codable {
    
    /// The userId
    public var userId: String
    
    /// The authorization token
    public var authToken: String
    
    /// the idToken for apple login
    public var idToken: String
    
    /// FirstName of the user
    public var firstName: String
    
    /// LastName of the user
    public var lastName: String
    
    /// The email of the user
    public var email: String?
    
}
