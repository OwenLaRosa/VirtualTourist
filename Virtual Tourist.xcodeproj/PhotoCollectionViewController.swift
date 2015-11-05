//
//  PhotoCollectionViewController.swift
//  Virtual Tourist
//
//  Created by Owen LaRosa on 7/6/15.
//  Copyright (c) 2015 Owen LaRosa. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import MapKit

class PhotoCollectionViewController: UIViewController, NSFetchedResultsControllerDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var collectionButton: UIBarButtonItem!
    
    var selectedIndexes = [NSIndexPath]()
    var insertedIndexPaths = [NSIndexPath]()
    var deletedIndexPaths = [NSIndexPath]()
    var pin: Pin!
    
    var context: NSManagedObjectContext {
        let delegate = UIApplication.sharedApplication().delegate as! AppDelegate
        return delegate.managedObjectContext!
    }
    
    override func viewDidLoad() {
        var error: NSError?
        // fetch the photo objects associated with the pin
        fetchedResultsController.delegate = self
        do {
            try fetchedResultsController.performFetch()
        } catch let error1 as NSError {
            error = error1
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // set the location and zoom level for the map
        let center = CLLocationCoordinate2DMake(pin.latitude as Double, pin.longitude as Double)
        let span = MKCoordinateSpanMake(5.0, 5.0)
        let region = MKCoordinateRegionMake(center, span)
        mapView.setRegion(region, animated: false)
        
        // create an annotation to be displayed at the center
        let annotation = MKPointAnnotation()
        annotation.coordinate = center
        mapView.addAnnotation(annotation)
        
        // hide collection button until all images are available
        collectionButton.enabled = false
    }
    
    override func viewDidLayoutSubviews() {
        let layout : UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        layout.minimumLineSpacing = 4
        layout.minimumInteritemSpacing = 4
        
        let sideLength = floor((self.collectionView.frame.size.width - 16) / 3)
        layout.itemSize = CGSize(width: sideLength, height: sideLength)
        collectionView.collectionViewLayout = layout
    }
    
    @IBAction func collectionButtonTapped(sender: UIBarButtonItem) {
        var photosToDelete = [Photo]()
        
        if selectedIndexes.count == 0 {
            // delete the existing images
            for i in fetchedResultsController.fetchedObjects! {
                photosToDelete.append(i as! Photo)
            }
            for i in photosToDelete {
                context.deleteObject(i)
            }
            collectionButton.title = "New Collection"
            // prevent the user from starting multiple downloads at once
            collectionButton.enabled = false
            // fetch a new set of images
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                var isFirstSearch = false
                Helpers().getImages(self.pin) {error in
                    if error != nil { // download was unsuccessful
                        if error == "1" { // error code 1: page had no images
                            // retry download from first page of results
                            Helpers().getImages(self.pin) {error in
                                if error != nil {
                                    // download failed again, allow the user to try again
                                    self.collectionButton.enabled = true
                                }
                            }
                        }
                    }
                }
            })
        } else {
            // remove the selected images
            for i in selectedIndexes {
                photosToDelete.append(fetchedResultsController.objectAtIndexPath(i) as! Photo)
            }
            for i in photosToDelete {
                context.deleteObject(i)
            }
            selectedIndexes = [NSIndexPath]()
            collectionButton.title = "New Collection"
        }
    }
    
    // MARK: - UICollectionViewDataSource
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return self.fetchedResultsController.sections?.count ?? 0
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section] 
        return sectionInfo.numberOfObjects
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoCollectionViewCell", forIndexPath: indexPath) as! PhotoCollectionViewCell
        
        configureCell(cell, atIndexPath: indexPath)
        
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let cell = collectionView.cellForItemAtIndexPath(indexPath) as! PhotoCollectionViewCell
        
        // toggle the selection state of the cell
        if let index = selectedIndexes.indexOf(indexPath) {
            selectedIndexes.removeAtIndex(index)
            cell.imageView.alpha = 1.0
            if selectedIndexes.count == 0 {
                collectionButton.title = "New Collection"
            } else {
                // update the collection button title
                collectionButton.title = "Delete \(selectedIndexes.count) photo\(Helpers().isPlural(selectedIndexes.count))"
            }
        } else {
            selectedIndexes.append(indexPath)
            cell.imageView.alpha = 0.5
            // update the collection button title
            collectionButton.title = "Delete \(selectedIndexes.count) photo\(Helpers().isPlural(selectedIndexes.count))"
        }
    }
    
    /// Configures the custom cell with the correct image.
    func configureCell(cell: PhotoCollectionViewCell, atIndexPath indexPath: NSIndexPath) {
        let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        
        let filePath = Constants.documentsDirectory+photo.imagePath
        
        // when quickly scrolling through collection views, sometimes the cells will show the wrong image
        // make sure the correct image is shown
        if let data = NSFileManager.defaultManager().contentsAtPath(filePath) {
            let image = UIImage(data: data)
            cell.imageView.image = image
            
            cell.activityIndicator.stopAnimating()
            cell.activityIndicator.hidden = true
            cell.imageView.image = image
            cell.userInteractionEnabled = true
            
            // check if all the images have been downloaded so the collection button can be enabled
            if Helpers().allImagesDownloaded(forPin: pin) {
                collectionButton.enabled = true
                cell.userInteractionEnabled = true
            }
        } else {
            // if no image is available, then initiate a new download from Flickr
            photo.isDownloading = true
            cell.imageView.image = UIImage(named: "Placeholder")
            cell.userInteractionEnabled = false
            cell.activityIndicator.hidden = false
            cell.activityIndicator.startAnimating()
            
            let fileUrl = photo.pathInfo.getPath()
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                let task = FlickrClient.sharedInstance().downloadPhotoAtUrl(photo.pathInfo.getPath()) {data, error in
                    if error != nil {
                        // download error, can be resumed later by reopening the view
                    } else {
                        data?.writeToFile(filePath, atomically: true)
                        photo.isDownloading = false
                        // update the UI on the main thread
                        dispatch_async(dispatch_get_main_queue(), {
                            cell.activityIndicator.stopAnimating()
                            cell.activityIndicator.hidden = true
                            cell.imageView.image = UIImage(data: data!)
                            cell.userInteractionEnabled = true
                            
                            // same as above, enable the button once all images have downloaded
                            if Helpers().allImagesDownloaded(forPin: self.pin) {
                                self.collectionButton.enabled = true
                                cell.userInteractionEnabled = true
                            }
                        })
                    }
                }
                cell.taskToCancelifCellIsReused = task
            }
        }
        
        // because of the same issue with scrolling, update the selection state of the cell to the correct value
        if let index = selectedIndexes.indexOf(indexPath) {
            cell.imageView.alpha = 0.5
        } else {
            cell.imageView.alpha = 1.0
        }
    }
    
    // MARK: - NSFetchedResultsControllerDelegate
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        // Create the fetch request
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        
        fetchRequest.sortDescriptors = []
        
        // limit the fetch to photos associated with the pin
        fetchRequest.predicate = NSPredicate(format: "location == %@", self.pin);
        
        // Create the Fetched Results Controller
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.context, sectionNameKeyPath: nil, cacheName: nil)
        
        // Return the fetched results controller. It will be the value of the lazy variable
        return fetchedResultsController
        }()
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        insertedIndexPaths = [NSIndexPath]()
        deletedIndexPaths = [NSIndexPath]()
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
        case .Insert:
            insertedIndexPaths.append(newIndexPath!)
            break
        case .Delete:
            deletedIndexPaths.append(indexPath!)
            break
        default:
            return
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        collectionView.performBatchUpdates({() -> Void in
            self.collectionView.insertItemsAtIndexPaths(self.insertedIndexPaths)
            self.collectionView.deleteItemsAtIndexPaths(self.deletedIndexPaths)
        }, completion: nil)
    }
    
}
