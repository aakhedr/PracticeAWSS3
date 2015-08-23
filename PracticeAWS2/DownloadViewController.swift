//
//  DownloadUploadViewController.swift
//  PracticeAWS2
//
//  Created by Ahmed Khedr on 8/20/15.
//  Copyright (c) 2015 Ahmed Khedr. All rights reserved.
//

import UIKit

class DownloadViewController: UIViewController {

    @IBOutlet weak var downloadedImagesCollectionView: UICollectionView!    

    var downloadRequests = [AWSS3TransferManagerDownloadRequest?]()
    var downloadFileURLs = [NSURL?]()

    // MARK: - View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        downloadedImagesCollectionView.delegate = self
        downloadedImagesCollectionView.dataSource = self
        
        listObjects()
        
        /* Create a local directory for the downloaded objects from the S3 bucket */
        var error = NSErrorPointer()
        
        if !NSFileManager.defaultManager().createDirectoryAtPath(
            NSTemporaryDirectory().stringByAppendingPathComponent("download"),
            withIntermediateDirectories: true,
            attributes: nil,
            error: error) {
                println("Creating 'download' directory failed with error: \(error)")
        }
    }
    
    // MARK: - Actions
    
    /* Show an alert view with actions:
    1) refresh: reloads collection view data all over
    2) downloadAll: downloads all objects in the S3 cicket
    3) cancel: dismisses the alert view
    */
    @IBAction func showAlertController(sender: UIBarButtonItem) {
        let alertController = UIAlertController(
            title: "Available Actions",
            message: "Choose your action!",
            preferredStyle: .ActionSheet)
        
        let refreshAction = UIAlertAction(
            title: "Refresh",
            style: .Default) { (action: UIAlertAction!) -> Void in
                self.downloadRequests.removeAll(keepCapacity: false)
                self.downloadFileURLs.removeAll(keepCapacity: false)
                self.downloadedImagesCollectionView.reloadData()
                self.listObjects()
        }
        alertController.addAction(refreshAction)
        
        let downloadAllAction = UIAlertAction(
            title: "Download All",
            style: .Default) { (action: UIAlertAction!) -> Void in
                self.downloadAll()
        }
        alertController.addAction(downloadAllAction)
        
        let cancelAction = UIAlertAction(
            title: "Cancel",
            style: .Cancel,
            handler: nil)
        alertController.addAction(cancelAction)
        
        presentViewController(alertController, animated: true, completion: nil)
    }
    
    // MARK: - Helpers
    
    /* Connect to the S3 bucket:
    1) to get the number of objects stored
    2) makes a temp file for each object
    3) populate downloadRequests and downloadFileURLs
    4) Eventually reloads collection view data
    */
    func listObjects() {
        let s3 = AWSS3.defaultS3()
        
        let listObjectsRequest = AWSS3ListObjectsRequest()
        listObjectsRequest.bucket = S3BucketName
        s3.listObjects(listObjectsRequest).continueWithBlock { (task: AWSTask!) -> AnyObject! in
            if let error = task.error {
                println("listObjects failed with error: \(error)")
            }
            
            if let exception = task.exception {
                println("listObjects failed with exception: \(exception)")
            }
            
            if let listObjectsOutput = task.result as? AWSS3ListObjectsOutput {
                if let contents = listObjectsOutput.contents as? [AWSS3Object] {
                    for s3object in contents {
                        let downloadFilePath = NSTemporaryDirectory().stringByAppendingPathComponent("download").stringByAppendingString(s3object.key)
                        let downloadFileURL = NSURL(fileURLWithPath: downloadFilePath)
                        
                        if NSFileManager.defaultManager().fileExistsAtPath(downloadFilePath) {
                            self.downloadRequests.append(nil)
                            self.downloadFileURLs.append(downloadFileURL)
                        } else {
                            let downloadRequest = AWSS3TransferManagerDownloadRequest()
                            downloadRequest.bucket = S3BucketName
                            downloadRequest.key = s3object.key
                            downloadRequest.downloadingFileURL = downloadFileURL
                            
                            self.downloadRequests.append(downloadRequest)
                            self.downloadFileURLs.append(nil)
                        }
                        
                        dispatch_async(dispatch_get_main_queue()) {
                            self.downloadedImagesCollectionView.reloadData()
                        }
                    }
                }
            }
            return nil
        }
    }
    
    func download(downloadRequest: AWSS3TransferManagerDownloadRequest) {
        switch downloadRequest.state {
            
        case .NotStarted, .Paused:
            let transferManager = AWSS3TransferManager.defaultS3TransferManager()
            transferManager.download(downloadRequest).continueWithBlock { (task: AWSTask!) -> AnyObject! in
                if let error = task.error {
                    if error.domain == AWSS3TransferManagerErrorDomain as String && AWSS3TransferManagerErrorType(rawValue: error.code) == AWSS3TransferManagerErrorType.Paused {
                        println("Download paused")
                    } else {
                        println("download() failed with error: \(error)")
                    }
                } else if let exception = task.exception {
                    println("download() failed with exception: \(exception)")
                } else {
                    dispatch_async(dispatch_get_main_queue()) {
                        if let index = self.indexOfDownloadRequest(self.downloadRequests, downloadRequest: downloadRequest) {
                            self.downloadRequests[index] = nil
                            self.downloadFileURLs[index] = downloadRequest.downloadingFileURL
                            
                            let indexPath = NSIndexPath(forRow: index, inSection: 0)
                            self.downloadedImagesCollectionView.reloadItemsAtIndexPaths([indexPath])
                        }
                    }
                }
                return nil
            }
            break
            
        default:
            break
        }
    }
    
    func indexOfDownloadRequest(array: [AWSS3TransferManagerDownloadRequest?], downloadRequest: AWSS3TransferManagerDownloadRequest?) -> Int? {
        for (index, object) in enumerate(array) {
            if object == downloadRequest {
                return index
            }
        }
        return nil
    }
    
    func downloadAll() {
        for (index, value) in enumerate(downloadRequests) {
            if let downloadRequest = value {
                if downloadRequest.state == .NotStarted || downloadRequest.state == .Paused {
                    download(downloadRequest)
                }
            }
        }
        downloadedImagesCollectionView.reloadData()
    }
    
    func cancelAllDownloads() {
        for (index, value) in enumerate(downloadRequests) {
            if let downloadRequest = value {
                if downloadRequest.state == .Running || downloadRequest.state == .Paused {
                    downloadRequest.cancel().continueWithBlock { (task: AWSTask!) -> AnyObject! in
                        if let error = task.error {
                            println("error in cancelAllDownloads(): \(error)")
                        } else if let exception = task.exception {
                            println("exception in cancelAllDownloads() :\(exception)")
                        }
                        return nil
                    }
                }
            }
        }
        downloadedImagesCollectionView.reloadData()
    }
}

extension DownloadViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    // MARK: - Collection View Data Source
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return downloadRequests.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("DownloadCollectionViewCell", forIndexPath: indexPath) as! DownloadCollectionViewCell
        
        if let downloadRequest = downloadRequests[indexPath.row] {
            downloadRequest.downloadProgress = { (bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) -> Void in
                if totalBytesExpectedToWrite > 0 {
                    dispatch_async(dispatch_get_main_queue()) {
                        cell.progressView.progress = Float(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
                    }
                }
            }
            cell.label.hidden = true
            cell.imageView.image = nil
            
            switch downloadRequest.state {
            case .NotStarted, .Paused:
                cell.progressView.progress = 0.0
                cell.label.hidden = false
                cell.label.text = "Download"
                break
                
            case .Running:
                cell.label.hidden = false
                cell.label.text = "Pause"
                break
                
            case .Canceling:
                cell.progressView.progress = 1.0
                cell.label.hidden = false
                cell.label.text = "Cancelled"
                break
                
            default:
                break
            }
        }
        
        if let downloadFileURL = downloadFileURLs[indexPath.row] {
            cell.label.hidden = true
            cell.progressView.progress = 1.0
            if let data = NSData(contentsOfURL: downloadFileURL) {
                cell.imageView.image = UIImage(data: data)
            }
        }
        return cell
    }
    
    // Collection View Delegate
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        collectionView.deselectItemAtIndexPath(indexPath, animated: true)
        if let downloadRequest = downloadRequests[indexPath.row] {
            switch downloadRequest.state {
                
            case .NotStarted, .Paused:
                download(downloadRequest)
                break
                
            case .Running:
                downloadRequest.pause().continueWithBlock { (task: AWSTask!) -> AnyObject! in
                    if let error = task.error {
                        println("pause() failed with error: \(error)")
                    } else if let exception = task.exception {
                        println("pause() failed with exception: \(exception)")
                    } else {
                        dispatch_async(dispatch_get_main_queue()) {
                            collectionView.reloadItemsAtIndexPaths([indexPath])
                        }
                    }
                    return nil
                }
                break
                
            default:
                break
            }
            collectionView.reloadData()
        }
        
        if let downloadFileURL = downloadFileURLs[indexPath.row] {
            
            // TODO: - Show image in a detail view
            println("Did not implement a detail view")
        }
    }
}

// MARK: - Download Collection View Cell

class DownloadCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var label: UILabel!
}

