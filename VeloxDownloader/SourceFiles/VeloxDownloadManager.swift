//
//  VeloxDownloadManager.swift
//  VeloxDownloader
//
//  Created by Nitin Sharma on 11/28/16.
//  Copyright © 2016 Nitin Sharma. All rights reserved.
//

import Foundation
import CoreGraphics
import UserNotifications


protocol DownloadManagerDelegate {
    func downloadItemAdded(downloadInstance : VeloxDownloadInstance)
    func downloadItemRemoved(downloadInstance : VeloxDownloadInstance)

}

class VeloxDownloadManager : NSObject,URLSessionDelegate,URLSessionDownloadDelegate,UNUserNotificationCenterDelegate

{
    
    var currentDownloads : Array<String>?
    var backgroundTransferCompletionHandler :( () -> ())?
    var session : URLSession?
    var backgroundSession : URLSession?
    static var downloadInstanceDictionary : Dictionary<String, VeloxDownloadInstance>?
    
    var delegate : DownloadManagerDelegate?
    
    static let sharedInstance = VeloxDownloadManager()
    
    override private init() {
        
        super.init()
        let configuration = URLSessionConfiguration.default
        self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        
        let backgroundConfiguration  = URLSessionConfiguration.background(withIdentifier: "com.sharmanitin.VeloxDownloader")
        self.backgroundSession = URLSession(configuration: backgroundConfiguration, delegate: self, delegateQueue: nil)
        self.currentDownloads = Array<String>()
        VeloxCacheManagement.cleanTempDirectory()
        UNUserNotificationCenter.current().delegate = self

    }
    
    
    func downloadFileWithVeloxDownloader(
        withURL: URL,
        name : String,
        directoryName:String?,
        friendlyName : String?,
        backgroundingMode :Bool
        
        ) -> Void {
        
        if(VeloxDownloadManager.downloadInstanceDictionary == nil)
        {
            VeloxDownloadManager.downloadInstanceDictionary = Dictionary<String,VeloxDownloadInstance>()
        }
        
        if(VeloxCacheManagement.fileExistForURL(url: withURL))
        {
            let result =  VeloxCacheManagement.deleteFileForURL(url: withURL)
            print("file1 got deleted : \(result)")
        }

        //Do the Session networking here
        var fileName  = name
        let url  = withURL
        var friendlyName = friendlyName
        var directoryName = directoryName

        if (fileName.isEmpty) {
            fileName = withURL.lastPathComponent
        }
        
        if (friendlyName == nil) {
            friendlyName = fileName;
        }
        
        if (directoryName == nil)
        {
            directoryName = VeloxCacheManagement.cachesDirectoryURlPath().appendingPathComponent(name).absoluteString
        }
        
        if(VeloxCacheManagement.fileDownloadCompletedForURL(url: url))
        {
            print("file is finished downloading")
        }
        else if(!(VeloxCacheManagement.fileExistForURL(url: url, directory: directoryName)))
        {
            
            let request = URLRequest(url: url)
            let downloadTask : URLSessionDownloadTask
            if(backgroundingMode)
            {
                 downloadTask = self.backgroundSession!.downloadTask(with: request)
            }
            else
            {
                 downloadTask  = self.session!.downloadTask(with: request)
            }
            
            let downloadInstance = VeloxDownloadInstance(withDownloadTask: downloadTask, remainingTime: nil, progess: nil, status: nil, name: fileName, friendlyName: friendlyName!, path: directoryName!, date: Date())

            VeloxDownloadManager.downloadInstanceDictionary![url.lastPathComponent] = downloadInstance
            if(delegate != nil)
            {
            delegate?.downloadItemAdded(downloadInstance: downloadInstance)
            }

                downloadTask.resume()

            
        }
        else
        {
            print("file already exists")

        }

    }
    
    func downloadFile(
        withURL: URL,
        name : String,
        directoryName:String?,
        friendlyName : String?,
        progressClosure : @escaping ((CGFloat,VeloxDownloadInstance)->(Void)),
        remainigtTimeClosure : @escaping ((CGFloat)->(Void)),
        completionClosure : @escaping ((Bool)->(Void)),
        backgroundingMode :Bool
        
        ) -> Void {
        
        if(VeloxDownloadManager.downloadInstanceDictionary == nil)
        {
            VeloxDownloadManager.downloadInstanceDictionary = Dictionary<String,VeloxDownloadInstance>()
        }
        
        if(VeloxCacheManagement.fileExistForURL(url: withURL))
        {
            let result =  VeloxCacheManagement.deleteFileForURL(url: withURL)
            print("file1 got deleted : \(result)")
        }
        
        //Do the Session networking here
        var fileName  = name
        let url  = withURL
        var friendlyName = friendlyName
        var directoryName = directoryName
        
        if (fileName.isEmpty) {
            fileName = withURL.lastPathComponent
        }
        
        if (friendlyName == nil) {
            friendlyName = fileName;
        }
        
        if (directoryName == nil)
        {
            directoryName = VeloxCacheManagement.cachesDirectoryURlPath().appendingPathComponent(name).absoluteString
        }
        
        if(VeloxCacheManagement.fileDownloadCompletedForURL(url: url))
        {
            print("file is finished downloading")
        }
        else if(!(VeloxCacheManagement.fileExistForURL(url: url, directory: directoryName)))
        {
            
            let request = URLRequest(url: url)
            let downloadTask : URLSessionDownloadTask
            if(backgroundingMode)
            {
                downloadTask = self.backgroundSession!.downloadTask(with: request)
            }
            else
            {
                downloadTask  = self.session!.downloadTask(with: request)
            }
            
            let downloadInstance = VeloxDownloadInstance(withDownloadTask: downloadTask, remainingTime: remainigtTimeClosure, progess: progressClosure, status: completionClosure, name: fileName, friendlyName: friendlyName!, path: directoryName!, date: Date())
            
            VeloxDownloadManager.downloadInstanceDictionary![url.lastPathComponent] = downloadInstance
            
            
            downloadTask.resume()
            
            
        }
        else
        {
            print("file already exists")
            
        }
        
    }
    
    
    
    //MARK : Session
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        
        //print("data written \(totalBytesWritten)")
        let fileIdentifier  = downloadTask.originalRequest!.url!.lastPathComponent
        let dowloadInstace = VeloxDownloadManager.downloadInstanceDictionary![fileIdentifier]
        let  progress = CGFloat.init(totalBytesWritten) / CGFloat.init(totalBytesExpectedToWrite)
        
        //print("progress is   \(progress)")

        DispatchQueue.main.async {
            dowloadInstace!.currentProgressClosure!(CGFloat(progress),dowloadInstace!)
        }
        
        let remainingTime = self.remainingTimeForDownload(downloadInstace: dowloadInstace!, totalBytesTransferred: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
        
        
        DispatchQueue.main.async {
            dowloadInstace!.remainingTimeClosure! (remainingTime)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
        
        
        let fileIdentifier  = downloadTask.originalRequest!.url!.lastPathComponent
        let dowloadInstace = VeloxDownloadManager.downloadInstanceDictionary![fileIdentifier]
        var destinationLocation : URL  = VeloxCacheManagement.cachesDirectoryURlPath()
        
        if(dowloadInstace!.filePath.isEmpty){
            destinationLocation = destinationLocation.appendingPathComponent(fileIdentifier)
        }
        else{
            
            destinationLocation = URL(string: dowloadInstace!.filePath)!
        }
        
        var success = true

        let response  = downloadTask.response! as! HTTPURLResponse
        let statusCode = response.statusCode
      
            if (statusCode >= 400) {
                success = false
            }
        
        
        if (success) {
            
           
            if(delegate != nil)
            {
                delegate?.downloadItemRemoved(downloadInstance: dowloadInstace!)
            }
            do
            {
          if(VeloxCacheManagement.fileExistWithName(name: dowloadInstace!.filename))
                
                {
                    try  FileManager.default.removeItem(at: destinationLocation)

                }
                try  FileManager.default.moveItem(at: location, to: destinationLocation)

            }
            catch let error as NSError
            {
                print("error occured \(error.localizedDescription)")
            }
        }
        
        
       //do a local notification
    }
    
 


    
    func remainingTimeForDownload(downloadInstace : VeloxDownloadInstance, totalBytesTransferred : Int64,totalBytesExpectedToWrite : Int64) -> CGFloat {
        
        let timeInterval : TimeInterval  = Date().timeIntervalSince(downloadInstace.downloadDate)
        
        let speed  = CGFloat.init(totalBytesTransferred) / CGFloat.init(timeInterval)
        let remainingBytes = totalBytesExpectedToWrite - totalBytesTransferred
        let remainingTime = CGFloat.init(remainingBytes) / CGFloat.init(speed)
        return  remainingTime
    }
    
   


    
  
  
    //MARK : Finish Session
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        session.getAllTasks { (taskArray) in
            if(taskArray.count == 0)
            {
                if(self.backgroundTransferCompletionHandler != nil)
                {
                    let completer = self.backgroundTransferCompletionHandler
                    
                    OperationQueue().addOperation(
                        completer!
                    )
                    
                    self.backgroundTransferCompletionHandler = nil;

                }
            }
        }
    }
    
    
 


   
}
