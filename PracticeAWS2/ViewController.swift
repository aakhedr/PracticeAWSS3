//
//  ViewController.swift
//  PracticeAWS2
//
//  Created by Ahmed Khedr on 8/20/15.
//  Copyright (c) 2015 Ahmed Khedr. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var actionButton: UIBarButtonItem!
    
    var uploadReqeusts      = [AWSS3TransferManagerUploadRequest?]()
    var uploadFileURLs      = [NSURL?]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create a local temp upload directory
        var error = NSErrorPointer()
        
        if !NSFileManager.defaultManager().createDirectoryAtPath(
        NSTemporaryDirectory().stringByAppendingPathComponent("upload"),
        withIntermediateDirectories: true,
        attributes: nil,
        error: error) {
            println("Creating 'upload' directory failed with error: \(error)")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func showImagePicker(sender: UIBarButtonItem) {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = UIImagePickerControllerSourceType.PhotoLibrary
        imagePicker.delegate = self
        
        presentViewController(imagePicker, animated: true, completion: nil)
    }
    
    // MARK: - Image Picker Controller Delegate
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [NSObject : AnyObject]) {
        
        dismissViewControllerAnimated(true, completion: nil)
        spinner.startAnimating()
        
        if let originalImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            let fileName = NSProcessInfo.processInfo().globallyUniqueString.stringByAppendingString(".png")
            let filePAth = NSTemporaryDirectory().stringByAppendingPathComponent("upload").stringByAppendingPathComponent(fileName)
            let imageData = UIImagePNGRepresentation(originalImage)
            imageData.writeToFile(filePAth, atomically: true)
            
            // Configure S3 Upload Request
            
            let uploadRequest = AWSS3TransferManagerUploadRequest()
            uploadRequest.body = NSURL(fileURLWithPath: filePAth)!
            uploadRequest.key = fileName
            uploadRequest.bucket = S3BucketName
            
            self.uploadReqeusts.append(uploadRequest)
            self.uploadFileURLs.append(nil)
            
            // Start AWS upload task
            self.upload(uploadRequest)
        }
        
    }
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    // MARK: - Save to Amazon S3 Bucket
    func upload(uploadRequest: AWSS3TransferManagerUploadRequest) {
        let transferManager = AWSS3TransferManager.defaultS3TransferManager()
        actionButton.enabled = false
        
        transferManager.upload(uploadRequest).continueWithBlock { (task) -> AnyObject! in
            if let error = task.error {
                if error.domain == AWSS3TransferManagerErrorDomain as String {
                    if let errorCode = AWSS3TransferManagerErrorType(rawValue: error.code) {
                        switch (errorCode) {
                            
                        case .Cancelled, .Paused:
                            println("Upload request cancelled or paused: \(error.domain)")
                            
                        default:
                            println("upload() failed with error: \(error.localizedDescription)")
                        }
                    } else {
                        println("upload() failed with error: \(error.localizedDescription)")
                    }
                } else {
                    println("upload() failed with error: \(error.localizedDescription)")
                }
            }
            
            if let exception = task.exception {
                println("upload() failed with exception: \(exception)")
            }
            
            if task.result != nil {
                if let index = self.indexOfUploadRequest(self.uploadReqeusts, uploadRequest: uploadRequest) {
                    self.uploadReqeusts[index] = nil
                    self.uploadFileURLs[index] = uploadRequest.body
                    
                    dispatch_async(dispatch_get_main_queue()) {
                        self.spinner.stopAnimating()
                        self.actionButton.enabled = true
                    }
                    
                    println("Image should now be saved! to S3 bucket")
                    println("uploadFileURLs: \(self.uploadFileURLs)")
                    println()
                    println("self.uploadRequests: \(self.uploadReqeusts)")
                }
            }
            
            return nil
        }
    }

    func indexOfUploadRequest(array: [AWSS3TransferManagerUploadRequest?], uploadRequest: AWSS3TransferManagerUploadRequest?) -> Int? {
        for (index, object) in enumerate(array) {
            if object == uploadRequest {
                return index
            }
        }
        
        return nil
    }

}

