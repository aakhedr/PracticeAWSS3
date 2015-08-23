//
//  UploadViewController.swift
//  PracticeAWS2
//
//  Created by Ahmed Khedr on 8/20/15.
//  Copyright (c) 2015 Ahmed Khedr. All rights reserved.
//

import UIKit

class UploadViewController: UIViewController {
    
    @IBOutlet weak var uploadedImagesCollectionView: UICollectionView!

    var uploadReqeusts      = [AWSS3TransferManagerUploadRequest?]()
    var uploadFileURLs      = [NSURL?]()
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        uploadedImagesCollectionView.dataSource = self
        uploadedImagesCollectionView.delegate = self
        
        // Create a local upload directory
        var error = NSErrorPointer()
        
        if !NSFileManager.defaultManager().createDirectoryAtPath(
        NSTemporaryDirectory().stringByAppendingPathComponent("upload"),
        withIntermediateDirectories: true,
        attributes: nil,
        error: error) {
            println("Creating 'upload' directory failed with error: \(error)")
        }
    }
    
    // MARK: - Actions
    
    @IBAction func showAlertController(sender: UIBarButtonItem) {
        let alertController = UIAlertController(
            title: "Available Actions",
            message: "Choose your action!",
            preferredStyle: .ActionSheet)
        
        let selectPictureAction = UIAlertAction(
            title: "Select a Picture",
            style: .Default) { (action: UIAlertAction!) -> Void in
            self.selectPicture()
        }
        alertController.addAction(selectPictureAction)
        
        let cancelAllUploadsAction = UIAlertAction(
            title: "Cancel All Uploads",
            style: .Default) { (action: UIAlertAction!) -> Void in
            self.cancelAllUploads()
        }
        alertController.addAction(cancelAllUploadsAction)
        
        let cancelAction = UIAlertAction(
            title: "Cancel",
            style: .Cancel,
            handler: nil)
        alertController.addAction(cancelAction)
        
        presentViewController(alertController, animated: true, completion: nil)
    }
    
    // MARK: - Helpers
    
    func selectPicture() {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = UIImagePickerControllerSourceType.PhotoLibrary
        
        presentViewController(imagePicker, animated: true, completion: nil)
    }
    
    func cancelAllUploads() {
        for (index, value) in enumerate(uploadReqeusts) {
            if let uploadRequest = value {
                uploadRequest.cancel().continueWithBlock { (task: AWSTask!) -> AnyObject! in
                    if let error = task.error {
                        println("cancelAllUploads failed with error: \(error)")
                    } else if let exception = task.exception {
                        println("cancelAllUploads failed with exception: \(exception)")
                    }
                    return nil
                }
            }
        }
    }
    
    func upload(uploadRequest: AWSS3TransferManagerUploadRequest) {
        let transferManager = AWSS3TransferManager.defaultS3TransferManager()
        
        transferManager.upload(uploadRequest).continueWithBlock { (task: AWSTask!) -> AnyObject! in
            if let error = task.error {
                if error.domain == AWSS3TransferManagerErrorDomain as String {
                    if let errorCode = AWSS3TransferManagerErrorType(rawValue: error.code) {
                        switch (errorCode) {
                            
                        case .Cancelled, .Paused:
                            dispatch_async(dispatch_get_main_queue()) {
                                self.uploadedImagesCollectionView.reloadData()
                            }
                            break
                            
                        default:
                            println("upload() failed with error: \(error.localizedDescription)")
                            break
                        }
                    } else {
                        println("upload() failed with error: \(error)")
                    }
                } else {
                    println("upload() failed with error: \(error)")
                }
            }
            
            if let exception = task.exception {
                println("upload() failed with exception: \(exception)")
            }
            
            if task.result != nil {
                if let index = self.indexOfUploadRequest(self.uploadReqeusts, uploadRequest: uploadRequest) {
                    dispatch_async(dispatch_get_main_queue()) {
                        self.uploadReqeusts[index] = nil
                        self.uploadFileURLs[index] = uploadRequest.body
                        let indexPath = NSIndexPath(forRow: index, inSection: 0)
                        self.uploadedImagesCollectionView.reloadItemsAtIndexPaths([indexPath])
                    }
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

// MARK: - Image Picker Controller Delegate

extension UploadViewController: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [NSObject : AnyObject]) {

        dismissViewControllerAnimated(true, completion: nil)
        
        if let originalImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            let fileName = NSProcessInfo.processInfo().globallyUniqueString.stringByAppendingString(".png")
            let filePAth = NSTemporaryDirectory().stringByAppendingPathComponent("upload").stringByAppendingPathComponent(fileName)
            let imageData = UIImagePNGRepresentation(originalImage)
            imageData.writeToFile(filePAth, atomically: true)
            
            let uploadRequest = AWSS3TransferManagerUploadRequest()
            uploadRequest.body = NSURL(fileURLWithPath: filePAth)!
            uploadRequest.key = fileName
            uploadRequest.bucket = S3BucketName
            
            self.uploadReqeusts.append(uploadRequest)
            self.uploadFileURLs.append(nil)
            
            self.upload(uploadRequest)
        }
        uploadedImagesCollectionView.reloadData()
    }
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        dismissViewControllerAnimated(true, completion: nil)
    }
}

extension UploadViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    // MARK: - Collection View Data Source
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return uploadReqeusts.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("UploadCollectionViewCell", forIndexPath: indexPath) as! UploadCollectionViewCell
        
        if let uploadRequest = uploadReqeusts[indexPath.row] {
            switch uploadRequest.state {
                
            case .Running:
                if let data = NSData(contentsOfURL: uploadRequest.body) {
                    cell.imageView.image = UIImage(data: data)
                    cell.label.hidden = true
                }

                uploadRequest.uploadProgress = { (bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) -> Void in
                    dispatch_async(dispatch_get_main_queue()) {
                        if totalBytesExpectedToSend > 0 {
                            cell.progressView.progress = Float(Double(totalBytesSent) / Double(totalBytesExpectedToSend))
                        }
                    }
                }
                break
                
            case .Canceling:
                cell.imageView.image = nil
                cell.label.hidden = false
                cell.label.text = "Cancelled"
                break
                
            case .Paused:
                cell.imageView.image = nil
                cell.label.hidden = false
                cell.label.text = "Paused"
                
            default:
                break
            }
        }
        
        if let uploadFileURL = uploadFileURLs[indexPath.row] {
            if let data = NSData(contentsOfURL: uploadFileURL) {
                cell.imageView.image = UIImage(data: data)
                cell.label.hidden = false
                cell.label.text = "Uploaded"
                cell.progressView.progress = 1.0
            }
        }
        return cell
    }
    
    // MARK: - Collection View Delegate
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        if let uploadRequest = uploadReqeusts[indexPath.row] {
            switch uploadRequest.state {
                
            case .Running:
                uploadRequest.pause().continueWithBlock { (task: AWSTask!) -> AnyObject! in
                    if let error = task.error {
                        println("pause() failed with error: \(error)")
                    }
                    
                    if let exception = task.exception {
                        println("pause() failed with exception: \(exception)")
                    }
                    return nil
                }
                break
                
            case .Paused:
                upload(uploadRequest)
                collectionView.reloadItemsAtIndexPaths([indexPath])
                break
                
            default:
                break
            }
        }
    }
}

// MARK: - Upload Collection View Cell

class UploadCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var label: UILabel!
}