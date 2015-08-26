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
let identityId = "IdentityID"

struct ReadPermissions {
    static let Email        = "email"
    static let UserFriends  = "user_friends"
}

class FBLoginViewController: UIViewController, FBSDKLoginButtonDelegate {

    @IBOutlet weak var loginButton: FBSDKLoginButton!

    private let loginManager = FBSDKLoginManager()
 
    // MARK: - View lifecycle
    
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
            
            // TODO: - Need animation here
            
            let credentialsProvider = initializeAWSCognitoClient()
            credentialsProvider.logins = [
                "graph.facebook.com" : FBSDKAccessToken.currentAccessToken().tokenString
            ]

//            let syncClient: AWSCognito = AWSCognito.defaultCognito()
//            let dataset: AWSCognitoDataset = syncClient.openOrCreateDataset("myDataSet")
//            dataset.setString("myValue", forKey: "myKey")
//            
//            dataset.synchronize().continueWithBlock { (task: AWSTask!) -> AnyObject! in
//                
//                // Do something here
//                return nil
//            }
            
            performSegueWithIdentifier("TabBarSegue", sender: self)
        }
    }
    
    func loginButtonDidLogOut(loginButton: FBSDKLoginButton!) {  }
    
    // MARK: - Actions
    
    @IBAction func useAppAsGuest(sender: UIButton) {
        performSegueWithIdentifier("TabBarSegue", sender: self)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "TabBarSegue" {
            initializeAWSCognitoClient()
        }
    }
    
    // MARK: - Helpers
    
    func initializeAWSCognitoClient() -> AWSCognitoCredentialsProvider {
        let credentialsProvider = AWSCognitoCredentialsProvider(
            regionType: DefaultServiceRegionType,
            identityPoolId: CognitoIdentityPoolId
        )
        
        let defaultServiceConfiguration = AWSServiceConfiguration(
            region: AWSRegionType.EUWest1,
            credentialsProvider: credentialsProvider
        )
        AWSServiceManager.defaultServiceManager().defaultServiceConfiguration = defaultServiceConfiguration
        
        return credentialsProvider
    }
}
