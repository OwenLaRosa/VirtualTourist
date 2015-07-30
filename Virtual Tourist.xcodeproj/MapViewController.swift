//
//  MapViewController.swift
//  Virtual Tourist
//
//  Created by Owen LaRosa on 6/30/15.
//  Copyright (c) 2015 Owen LaRosa. All rights reserved.
//

import Foundation
import MapKit
import CoreData

class MapViewController: UIViewController, MKMapViewDelegate, NSFetchedResultsControllerDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var deleteInstructionView: UIView!
    
    /// gesture recognizer for adding new pins to the map view
    @IBOutlet var longPressGestureRecognizer: UILongPressGestureRecognizer!
    
    // determines if the editing mode is on (true) or off (false)
    var userIsEditing = false 
    /// temporary value that holds a reference to the pin currently being dragged and dropped
    var currentPin: Pin? = nil 
    
    // these will be used by the fetched results controller to keep track of any updates to the data
    var insertedIndexPaths: [NSIndexPath]!
    var deletedIndexPaths: [NSIndexPath]!
    var updatedIndexPaths: [NSIndexPath]!
    
    /// All download tasks created within the class
    var downloadTasks = [NSURLSessionTask]()
    
    let userDefaults = NSUserDefaults.standardUserDefaults()
    
    /// Keys for storing user defaults including center coordinate and span
    struct UserDefaultKeys {
        static let centerLatitude = "centerLatitude"
        static let centerLongitude = "centerLongitude"
        static let latitudeDelta = "latitudeDelta"
        static let longitudeDelta = "longitudeDelta"
    }
    
    var context: NSManagedObjectContext {
        let delegate = UIApplication.sharedApplication().delegate as! AppDelegate
        return delegate.managedObjectContext!
    }
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        // get all pin instances from CoreData
        var error: NSError?
        fetchedResultsController.delegate = self
        fetchedResultsController.performFetch(&error)
        
        // create point annotations for each of the resulting objects
        for i in fetchedResultsController.fetchedObjects! {
            let pin = i as! Pin
            let annotation = MKPointAnnotation()
            annotation.pin = pin
            annotation.coordinate = CLLocationCoordinate2D(latitude: pin.latitude as Double, longitude: pin.longitude as Double)
            mapView.addAnnotation(annotation)
        }
        
        // get the previous map center and span from the user defaults
        let latitude = userDefaults.objectForKey(UserDefaultKeys.centerLatitude) as! Double?
        let longitude = userDefaults.objectForKey(UserDefaultKeys.centerLongitude) as! Double?
        let latitudeDelta = userDefaults.objectForKey(UserDefaultKeys.latitudeDelta) as! Double?
        let longitudeDelta = userDefaults.objectForKey(UserDefaultKeys.latitudeDelta) as! Double?
        
        // check if none of the values are nil (have yet to be assigned)
        if latitude != nil && longitude != nil && latitudeDelta != nil && longitudeDelta != nil {
            // restore the map's previous center and zoom level
            let region = MKCoordinateRegionMake(CLLocationCoordinate2DMake(latitude!, longitude!), MKCoordinateSpanMake(latitudeDelta!, longitudeDelta!))
            mapView.setRegion(region, animated: true)
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        // reset the view controller's title
        self.title = "Virtual Tourist"
    }
    
    override func viewWillDisappear(animated: Bool) {
        // configure the title to specify the back button text on the photo collection view
        self.title = "Back"
    }
    
    // MARK: - IBActions
    
    /// Handler for long press. Drops a new pin on the map and updates its location when the user drags it.
    @IBAction func onLongPress(sender: UILongPressGestureRecognizer) {
        // get location of long press and convert it to usable map coordinates
        let location = mapView.convertPoint(sender.locationInView(mapView), toCoordinateFromView: mapView)
        switch sender.state {
        case .Began:
            let pin = Pin(location: location, context: context)
            // assign a temporary reference to the pin so it can be used later
            currentPin = pin
            currentPin?.latitude = location.latitude
            currentPin?.longitude = location.longitude
            //let view = annotationForPin(currentPin!)
            //view.setSelected(true, animated: true)
            break
        case .Changed:
            // update the pin's location based on drag gesture
            currentPin?.latitude = location.latitude
            currentPin?.longitude = location.longitude
        case .Ended:
            Helpers().getImages(self.currentPin!) {error in
                if error != nil {
                    // no error handling needed here yet, image search can be performed later
                }
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                    for i in self.currentPin!.photos {
                        self.downloadAndSaveImage(i)
                    }
                })
            }
            break
        default:
            return
        }
    }
    
    /// Toggles the editing (deleting) state of the view.
    @IBAction func editButtonTapped(sender: UIBarButtonItem) {
        if let title = sender.title {
            switch title {
            case "Edit":
                userIsEditing = true
                longPressGestureRecognizer.enabled = false
                sender.title = "Done"
                UIView.animateWithDuration(0.5, animations: {
                    self.mapView.frame.origin.y -= self.deleteInstructionView.bounds.height
                })
                self.deleteInstructionView.hidden = false
                break
            case "Done":
                userIsEditing = false
                longPressGestureRecognizer.enabled = true
                sender.title = "Edit"
                UIView.animateWithDuration(0.5, animations: {
                    self.mapView.frame.origin.y = 0
                })
                deleteInstructionView.hidden = true
                break
            default:
                return
            }
        }
    }
    
    
    
    // MARK: - Map View Delegate
    
    func mapView(mapView: MKMapView!, regionDidChangeAnimated animated: Bool) {
        // persist region change
        userDefaults.setObject(NSNumber(double: mapView.region.center.latitude), forKey: UserDefaultKeys.centerLatitude)
        userDefaults.setObject(NSNumber(double: mapView.region.center.longitude), forKey: UserDefaultKeys.centerLongitude)
        userDefaults.setObject(NSNumber(double: mapView.region.span.latitudeDelta), forKey: UserDefaultKeys.latitudeDelta)
        userDefaults.setObject(NSNumber(double: mapView.region.span.longitudeDelta), forKey: UserDefaultKeys.longitudeDelta)
    }
    
    func mapView(mapView: MKMapView!, didSelectAnnotationView view: MKAnnotationView!) {
        view.selected = false
        if userIsEditing {
            // editing mode is on, delete selected pins
            let pin = (view.annotation as! MKPointAnnotation).pin
            let annotation = annotationForPin(pin)
            context.deleteObject(pin)
            mapView.removeAnnotation(annotation as MKAnnotation)
        } else { // editing mode is off, navigate to the photo album view
            // make sure no pins stay selected for longer than they're supposed to
            mapView.selectAnnotation(nil, animated: false)
            // cancel any ongoing download tasks
            for i in downloadTasks {
                i.cancel()
            }
            // specify the sender and perform the segue
            let pin = (view.annotation as! MKPointAnnotation).pin
            performSegueWithIdentifier("showImages", sender: pin)
        }
    }
    
    // MARK: - Segues
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showImages" {
            let photoCollectionVC: PhotoCollectionViewController = segue.destinationViewController as! PhotoCollectionViewController
            photoCollectionVC.pin = sender as! Pin
        }
    }
    
    // MARK: - NSFetchedResultsControllerDelegate
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        // Create the fetch request
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        
        // Add a sort descriptor.
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "longitude", ascending: false)]
        
        // Create the Fetched Results Controller
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.context, sectionNameKeyPath: nil, cacheName: nil)
        
        // Return the fetched results controller. It will be the value of the lazy variable
        return fetchedResultsController
        } ()
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        // reset contents of path arrays before adding new values
        insertedIndexPaths = [NSIndexPath]()
        deletedIndexPaths = [NSIndexPath]()
        updatedIndexPaths = [NSIndexPath]()
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        
        switch type {
        case .Insert:
            insertedIndexPaths.append(newIndexPath!)
            break
        case .Delete:
            deletedIndexPaths.append(indexPath!)
            break
        case .Update:
            updatedIndexPaths.append(indexPath!)
        default:
            break
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        
        for i in insertedIndexPaths {
            // create a point annotation and add it to the map view
            let pin = fetchedResultsController.objectAtIndexPath(i) as! Pin
            let annotation = MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2DMake(pin.latitude as Double, pin.longitude as Double)
            annotation.pin = pin
            mapView.addAnnotation(annotation)
        }
        
        for i in deletedIndexPaths {
            // currently all deleting events are handled by CoreData, but if any new functionality is needed, it will be added here
        }
        
        for i in updatedIndexPaths {
            let pin = fetchedResultsController.objectAtIndexPath(i) as! Pin
            let annotation = annotationForPin(pin)
            annotation.coordinate = CLLocationCoordinate2D(latitude: pin.latitude as Double, longitude: pin.longitude as Double)
        }
        
        context.save(nil)
    }
    
    // MARK: - Helper Methods
        
    /// Downloads an image for the Photo object and saves it to the app's sandbox.
    func downloadAndSaveImage(photo: Photo) {
        photo.isDownloading = true
        let path = photo.pathInfo.getPath()
        
        downloadTasks.append(FlickrClient.sharedInstance().downloadPhotoAtUrl(path) {data, error in
            if error != nil {
                // currently no need to handle the error as the download can br retried later
            } else {
                let filePath = Constants.documentsDirectory+photo.imagePath
                data?.writeToFile(filePath, atomically: true) // atomically set to true to prevent corrupted data
                photo.isDownloading = false
            }
            })
    }
    
    // Returns an MKPointAnnotation that matches the Pin object,
    func annotationForPin(pin: Pin) -> MKPointAnnotation {
        var annotationToReturn = MKPointAnnotation()
        for var i = 0; i < fetchedResultsController.fetchedObjects?.count; i++ {
            let annotation = mapView.annotations[i] as! MKPointAnnotation
            if pin == annotation.pin {
                annotationToReturn = annotation
                break
            }
        }
        return annotationToReturn
    }
    
}

// variable's memory address will be used as a unique association key
private var associationKey: UInt8 = 0

// Extend MKPointAnnotation to include a pin property. This will be used to get the pin object associated with each instance.
extension MKPointAnnotation {
    var pin: Pin! {
        get {
            return objc_getAssociatedObject(self, &associationKey) as! Pin
        }
        set(newValue) {
            objc_setAssociatedObject(self, &associationKey, newValue, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN))
        }
    }
}
