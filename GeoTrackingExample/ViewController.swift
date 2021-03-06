/*
See LICENSE folder for this sample’s licensing information.

Abstract:
View controller.
*/

import UIKit
import RealityKit
import ARKit
import MapKit
import Photos

class ViewController: UIViewController, ARSessionDelegate, CLLocationManagerDelegate, MKMapViewDelegate {
    
    @IBOutlet var arView: ARView!
//    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var toastLabel: UILabel!
    @IBOutlet weak var undoButton: UIButton!
    @IBOutlet weak var menuButton: UIButton!
    @IBOutlet weak var trackingStateLabel: UILabel!
 
    let coachingOverlayWorldTracking = ARCoachingOverlayView()
//    let arrayOfColors = [UIColor.blue,UIColor.red,UIColor.lightGray,UIColor.green, UIColor.systemPink, UIColor.brown, UIColor.cyan, UIColor.yellow]
    let arrayOfColors = [UIColor(red: 0, green: 253/255, blue: 255/255, alpha: 1),UIColor(red: 8/255, green: 255/255, blue: 8/255, alpha: 1),UIColor(red: 255/255, green: 207/255, blue: 0, alpha: 1 ),UIColor(red: 254/255, green: 20/255, blue: 147/255, alpha: 1 ),UIColor(red: 255/255, green: 85/255, blue: 85/255, alpha: 1),UIColor(red: 204/255, green: 255/255, blue: 2/255, alpha: 1),UIColor.blue,UIColor.red,UIColor.lightGray,UIColor.green, UIColor.systemPink, UIColor.brown, UIColor.yellow, UIColor.white]
    var geoCoachingController: GeoCoachingViewController!
    
    let locationManager = CLLocationManager()
 
    let toleranceAngle = Double(30)
    
    var currentAnchors: [ARAnchor] {
        return arView.session.currentFrame?.anchors ?? []
    }
    
    var nearbyLocations:[MKMapItem] = []
        
    // Geo anchors ordered by the time of their addition to the scene.
    var geoAnchors: [GeoAnchorWithAssociatedData] = []
    
    // Auto-hide the home indicator to maximize immersion in AR experiences.
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    // Hide the status bar to maximize immersion in AR experiences.
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    // MARK: - View Controller Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set this view controller as the session's delegate.
        arView.session.delegate = self
        
        // Enable coaching.
        setupWorldTrackingCoachingOverlay()
        
        geoCoachingController = GeoCoachingViewController(for: arView)
                
        // Set this view controller as the Core Location manager delegate.
        locationManager.delegate = self
        
        // Set this view controller as the MKMapView delegate.
//        mapView.delegate = self
        
        // Disable automatic configuration and set up geotracking
        arView.automaticallyConfigureSession = false
                
        // Run a new AR Session.
        restartSession()
                
        // Add tap gesture recognizers
//        arView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTapOnARView(_:))))
//        mapView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTapOnMapView(_:))))
        
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Prevent the screen from being dimmed to avoid interuppting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true

        // Start listening for location updates from Core Location
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
 
    }
    
    // Disable Core Location when the view disappears.
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - User Interaction
    @IBAction func menuButtonTapped(_ sender: Any) {
        self.restartSession()
    }
    
    @IBAction func updateNameBtnTapped(_ sender: Any) {
     
        geoAnchors.removeAll()
        
        arView.scene.anchors.removeAll()
        addNearByBuildingNames()
    }
    // Responds to a user tap on the AR view.
    @objc
    func handleTapOnARView(_ sender: UITapGestureRecognizer) {
        let point = sender.location(in: view)
        
        // Perform ARKit raycast on tap location
        if let result = arView.raycast(from: point, allowing: .estimatedPlane, alignment: .any).first {
            addGeoAnchor(at: result.worldTransform.translation)
        } else {
            showToast("No raycast result.\nTry pointing at a different area\nor move closer to a surface.")
        }
    }
    
    // Responds to a user tap on the map view.
//    @objc
//    func handleTapOnMapView(_ sender: UITapGestureRecognizer) {
//        let point = sender.location(in: mapView)
//        let location = mapView.convert(point, toCoordinateFrom: mapView)
//        addGeoAnchor(at: location)
//    }
    
    // Removes the most recent geo anchor.
    @IBAction func undoButtonTapped(_ sender: Any) {
        guard let lastGeoAnchor = geoAnchors.last else {
            showToast("Nothing to undo")
            return
        }
        
        // Remove geo anchor from the scene.
        arView.session.remove(anchor: lastGeoAnchor.geoAnchor)
        
        // Remove map overlay
//        mapView.removeOverlay(lastGeoAnchor.mapOverlay)
        
        // Remove the element from the collection.
        geoAnchors.removeLast()
        
        showToast("Removed last added anchor")
    }
    
    // MARK: - Methods
    
    
    
    // Presents the available actions when the user presses the menu button.
//    func presentAdditionalActions() {
//        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
//        actionSheet.addAction(UIAlertAction(title: "Reset Session", style: .destructive, handler: { (_) in
//            self.restartSession()
//        }))
//        actionSheet.addAction(UIAlertAction(title: "Load Anchors …", style: .default, handler: { (_) in
//            self.showGPXFiles()
//        }))
//        actionSheet.addAction(UIAlertAction(title: "Save Anchors …", style: .default, handler: { (_) in
//            self.saveAnchors()
//        }))
//        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
//        present(actionSheet, animated: true)
//    }
    
    // Calls into the function that saves any user-created geo anchors to a GPX file.
    func saveAnchors() {
        let geoAnchors = currentAnchors.compactMap({ $0 as? ARGeoAnchor })
        guard !geoAnchors.isEmpty else {
                alertUser(withTitle: "No geo anchors", message: "There are no geo anchors to save.")
            return
        }
        
        saveAnchorsAsGPXFile(geoAnchors)
    }

    func restartSession() {
        // Check geo-tracking location-based availability.
        ARGeoTrackingConfiguration.checkAvailability { (available, error) in
            if !available {
                let errorDescription = error?.localizedDescription ?? ""
                let recommendation = "Please try again in an area where geotracking is supported."
                let restartSession = UIAlertAction(title: "Restart Session", style: .default) { (_) in
                    self.restartSession()
                }
                self.alertUser(withTitle: "Geotracking unavailable",
                               message: "\(errorDescription)\n\(recommendation)",
                               actions: [restartSession])
            }
        }
        
        // Re-run the ARKit session.
        let geoTrackingConfig = ARGeoTrackingConfiguration()
        geoTrackingConfig.planeDetection = [.horizontal]
        arView.session.run(geoTrackingConfig)
        geoAnchors.removeAll()
        
        arView.scene.anchors.removeAll()
        
        trackingStateLabel.text = ""
        
//        // Remove all anchor overlays from the map view
//        let anchorOverlays = mapView.overlays.filter { $0 is AnchorIndicator }
//        mapView.removeOverlays(anchorOverlays)
        
        showToast("Running new AR session")
    }
    
    func addGeoAnchor(at worldPosition: SIMD3<Float>) {
        arView.session.getGeoLocation(forPoint: worldPosition) { (location, altitude, error) in
            if let error = error {
                self.alertUser(withTitle: "Cannot add geo anchor",
                               message: "An error occurred while translating ARKit coordinates to geo coordinates: \(error.localizedDescription)")
                return
            }
            self.addGeoAnchor(at: location, altitude: altitude)
        }
    }
    
    func addGeoAnchor(at location: CLLocationCoordinate2D, altitude: CLLocationDistance? = nil, name:String = "There is no name!", angle:Float = 0) {
        var geoAnchor: ARGeoAnchor!
        if let altitude = altitude {
            geoAnchor = ARGeoAnchor(coordinate: location, altitude: altitude)
        } else {
            geoAnchor = ARGeoAnchor(coordinate: location)
        }
        addGeoAnchor(geoAnchor)
        let geoAnchorEntity = AnchorEntity(anchor: geoAnchor)
        geoAnchorEntity.addChild(generateSignEntity(name))
        let orientiation = simd_quatf.init(angle: angle, axis:  SIMD3<Float>(0,1,0))
        //on my left pi/2, on my right -pi/2
//        print("\(name): \(location)")
//        print("My location \(locationManager.location!.coordinate)")
        geoAnchorEntity.setOrientation(orientiation, relativeTo: geoAnchorEntity)
        
        addGeoAnchor(geoAnchorEntity)
    }
    func getOrientation(_ TargetLocation: CLLocationCoordinate2D ) -> Float
    {
        
        if let currentLoco = locationManager.location?.coordinate{
            
        let y_diff = Float(TargetLocation.latitude - currentLoco.latitude)
        let x_diff = Float(TargetLocation.longitude - currentLoco.longitude)
        let ratio = abs(x_diff/y_diff)
        let radian = atan(ratio)
            if (y_diff > 0 && x_diff > 0 ){
                return 2*Float.pi-radian
//                return -Float.pi/4
            }else if(y_diff < 0 && x_diff < 0){
                return (Float.pi-radian)
//                return Float.pi*3/4
            }else if(y_diff < 0 && x_diff > 0){
                    return (Float.pi+radian)
//                return -Float.pi*3/4
            }else if(y_diff >= 0 && x_diff <= 0){
                return radian;
//                return
//                    Float.pi/4
            }
            
            print("y_diff \(y_diff) and x_dif\(x_diff)")
            print("angle \(atan(ratio))")
            return atan(ratio)
            
            
        }
       
      
        return 0
    }
    func generateSignEntity(_ name:String) -> Entity{
        let mesh =  MeshResource.generateText(name,
                            extrusionDepth: 0.5,
                                      font: .systemFont(ofSize: 5),
                            containerFrame: CGRect.zero,
                                 alignment: .center,
                             lineBreakMode: .byCharWrapping)
       let entity = ModelEntity(mesh: mesh)
        var mat = SimpleMaterial()
        mat.baseColor = MaterialColorParameter.color(arrayOfColors.randomElement() ?? UIColor.white)
        
        entity.model?.materials = [mat]
        entity.setPosition([entity.scale.x/2,0,0], relativeTo: entity)
        return entity
    }
    
    func addGeoAnchor(_ geoAnchor: ARGeoAnchor) {
        
        // Don't add a geo anchor if Core Location isn't sure yet where the user is.
        guard isGeoTrackingLocalized else {
            alertUser(withTitle: "Cannot add geo anchor", message: "Unable to add geo anchor because geotracking has not yet localized.")
            return
        }
        arView.session.add(anchor: geoAnchor)
    }
    
    func addGeoAnchor(_ geoAnchorEntity: AnchorEntity) {
        
        // Don't add a geo anchor if Core Location isn't sure yet where the user is.
        guard isGeoTrackingLocalized else {
            alertUser(withTitle: "Cannot add geo anchor", message: "Unable to add geo anchor because geotracking has not yet localized.")
            return
        }
        arView.scene.addAnchor(geoAnchorEntity)
    }
    
    var isGeoTrackingLocalized: Bool {
        if let status = arView.session.currentFrame?.geoTrackingStatus, status.state == .localized {
            return true
        }
        return false
    }
    
    func distanceFromDevice(_ coordinate: CLLocationCoordinate2D) -> Double {
        if let devicePosition = locationManager.location?.coordinate {
            return MKMapPoint(coordinate).distance(to: MKMapPoint(devicePosition))
        } else {
            return 0
        }
    }
    
    // MARK: - ARSessionDelegate
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for geoAnchor in anchors.compactMap({ $0 as? ARGeoAnchor }) {
            // Effect a spatial-based delay to avoid blocking the main thread.
            DispatchQueue.main.asyncAfter(deadline: .now() + (distanceFromDevice(geoAnchor.coordinate) / 10)) {
                // Add an AR placemark visualization for the geo anchor.
                self.arView.scene.addAnchor(Entity.placemarkEntity(for: geoAnchor))
            }
            // Add a visualization for the geo anchor in the map view.
            let anchorIndicator = AnchorIndicator(center: geoAnchor.coordinate)
//            self.mapView.addOverlay(anchorIndicator)

            // Remember the geo anchor we just added
            let anchorInfo = GeoAnchorWithAssociatedData(geoAnchor: geoAnchor, mapOverlay: anchorIndicator)
            self.geoAnchors.append(anchorInfo)
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        DispatchQueue.main.async {
            // Present an alert informing about the error that has occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.restartSession()
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    /// - Tag: GeoTrackingStatus
    func session(_ session: ARSession, didChange geoTrackingStatus: ARGeoTrackingStatus) {
        
        geoCoachingController.update(for: geoTrackingStatus)
        configureUIForCoaching(geoTrackingStatus.state != .localized)
        
        var text = ""
        // In localized state, show geotracking accuracy
        if geoTrackingStatus.state == .localized {
            text += "Accuracy: \(geoTrackingStatus.accuracy.description)"
        } else {
            // Otherwise show details why geotracking couldn't localize (yet)
            switch geoTrackingStatus.stateReason {
            case .none:
                break
            case .worldTrackingUnstable:
                let arTrackingState = session.currentFrame?.camera.trackingState
                if case let .limited(arTrackingStateReason) = arTrackingState {
                    text += "\n\(geoTrackingStatus.stateReason.description): \(arTrackingStateReason.description)."
                } else {
                    fallthrough
                }
            default: text += "\n\(geoTrackingStatus.stateReason.description)."
            }
        }
        self.trackingStateLabel.text = text
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Notify GeoLocation session coaching that the tracking state is stable
        switch frame.camera.trackingState {
        case .normal:
            geoCoachingController.worldTrackingStateIsNormal(true)
        default:
            return
        }
    }
    func correctAngle(facing:Double, angle:Double) -> Bool{
        let diff = abs( facing - angle )
        let smallerDiff = min(diff, 360-diff)
        if smallerDiff > toleranceAngle{
            return false
        }
        return true
    }
    
    func addNearByBuildingNames(){
       
//        if self.nearbyLocations.count == 0{
//            alertUser(withTitle: "No Nearby Building 😢", message: "Try to move close to the building.")
//        }
//        print(nearbyLocations.count)
        for item in self.nearbyLocations{
            let name = item.name ?? "No name"
            let region = item.placemark.coordinate
            let rand = getOrientation(region)
            let angle = 360 - Double(rand) * 180 / .pi
            let facing = locationManager.heading?.trueHeading ?? 0.0
//          print("Facing \(facing), Build \(angle), \(name)")
//            addGeoAnchor(at: region, name: name,angle: rand)
            if  correctAngle(facing: facing, angle: angle) {
                addGeoAnchor(at: region, name: name,angle: rand)
//                alertUser(withTitle: "Facing \(facing), Build \(angle)", message: "\(name)")
//                print("Added \(item.name)")
                return
            }
           
        }
        alertUser(withTitle: "No Nearby Building😢", message: "Move to closer to the building!🚶‍♂️")
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Update location indicator with live estimate from Core Location
//        guard let location = locations.last else { return }
        
//        // Update map area
//        let camera = MKMapCamera(lookingAtCenter: location.coordinate,
//                                 fromDistance: CLLocationDistance(250),
//                                 pitch: 0,
//                                 heading: mapView.camera.heading)
//        mapView.setCamera(camera, animated: false)
        
        
        let request = MKLocalPointsOfInterestRequest(center: locationManager.location!.coordinate, radius: 500)
//        request.pointOfInterestFilter = MKPointOfInterestFilter(including: <#T##[MKPointOfInterestCategory]#>)//don't have a way to exclude street names : (
        let search = MKLocalSearch(request: request)
        search.start { [unowned self] (response, error) in
                
            if let items = response?.mapItems{
                nearbyLocations = items
            }
            
           }
    }
    
    // MARK: - MKMapViewDelegate
    
//    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
//        if let anchorOverlay = overlay as? AnchorIndicator {
//            let anchorOverlayView = MKCircleRenderer(circle: anchorOverlay)
//            anchorOverlayView.strokeColor = .white
//            anchorOverlayView.fillColor = .blue
//            anchorOverlayView.lineWidth = 2
//            return anchorOverlayView
//        }
//        return MKOverlayRenderer()
//    }
}
