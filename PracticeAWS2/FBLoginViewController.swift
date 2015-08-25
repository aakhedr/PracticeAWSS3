//
//  FBLoginViewController.swift
//  PracticeAWS2
//
//  Created by Ahmed Khedr on 8/25/15.
//  Copyright (c) 2015 Ahmed Khedr. All rights reserved.
//

import UIKit
import FBSDKCoreKit
import FBSDKLoginKit

let userDefaults = NSUserDefaults.standardUserDefaults()
let FBAccessToken = "FBAccessToken"

struct ReadPermissions {
    static let Email        = "email"
    static let UserFriends  = "user_friends"
}

class FBLoginViewController: UIViewController, FBSDKLoginButtonDelegate {

    @IBOutlet weak var loginButton: FBSDKLoginButton!

    private let loginManager = FBSDKLoginManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loginButton.delegate = self
        loginButton.readPermissions = [ReadPermissions.Email, ReadPermissions.UserFriends]
    }
    
    // MARK: - Facebook Login Button Delegate
    
    func loginButton(loginButton: FBSDKLoginButton!, didCompleteWithResult result: FBSDKLoginManagerLoginResult!, error: NSError!) {
        if let error = error {
            println("error logging in to Facebook: \(error)")
        } else if result.isCancelled {
            
            // TODO: -
            

        } else {
            userDefaults.setObject(FBSDKAccessToken.currentAccessToken().tokenString, forKey: FBAccessToken)
            
            // TODO: - Need animation here
            performSegueWithIdentifier("TabBarSegue", sender: self)
        }
    }
    
    func loginButtonDidLogOut(loginButton: FBSDKLoginButton!) {  }
}
