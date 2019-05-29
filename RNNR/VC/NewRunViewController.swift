//
//  NewRunViewController.swift
//  RNNR
//
//  Created by Alex Kagarov on 3/17/19.
//  Copyright © 2019 Alex Kagarov. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit

class NewRunViewController: UIViewController {
    private var run: Run?
    
    private let locationManager = LocationManager.shared
    private var seconds = 0
    private var timer: Timer?
    private var distance = Measurement(value: 0, unit: UnitLength.meters)
    private var locationList: [CLLocation] = []
    
    @IBOutlet weak var launchStackView: UIStackView!
    
    @IBOutlet weak var runDataStackView: UIStackView!
    @IBOutlet weak var timeLbl: UILabel!
    @IBOutlet weak var distanceLbl: UILabel!
    @IBOutlet weak var paceLbl: UILabel!
    
    @IBOutlet weak var startRunBtn: UIButton!
    
    @IBOutlet weak var stopRunBtn: UIButton!
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var mapContainerView: UIView!
    
    private func startLocationUpdates() {
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.distanceFilter = 10
        locationManager.startUpdatingLocation()
    }
    
    func eachSecond() {
        seconds += 1
        updateDisplay()
    }
    
    private func updateDisplay() {
        let formattedDistance = FormatDisplay.distance(distance)
        let formattedTime = FormatDisplay.time(seconds)
        let formattedPace = FormatDisplay.pace(distance: distance,
                                               seconds: seconds,
                                               outputUnit: UnitSpeed.minutesPerMile)
        
        distanceLbl.text = "Distance:  \(formattedDistance)"
        timeLbl.text = "Time:  \(formattedTime)"
        paceLbl.text = "Pace:  \(formattedPace)"
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        runDataStackView.isHidden = true
        stopRunBtn.isHidden = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        locationManager.stopUpdatingLocation()
    }
    
    @IBAction func startRunTapped(_ sender: UIButton) {
        startRun()
    }
    
    @IBAction func stopRunTapped(_ sender: UIButton) {
        let alert = UIAlertController(title: "End run?", message: "Do you really want to end your run?", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Yes", style: .default) { _ in
            self.stopRun()
            self.saveRun() // ADD THIS LINE!
            self.performSegue(withIdentifier: .details, sender: nil)
        })
        alert.addAction(UIAlertAction(title: "Discard", style: .destructive) { _ in
            self.stopRun()
            _ = self.navigationController?.popToRootViewController(animated: true)
        })
        present(alert, animated: true)
    }
    
    private func startRun() {
        //mapContainerView.isHidden = false
        launchStackView.isHidden = true
        runDataStackView.isHidden = false
        startRunBtn.isHidden = true
        stopRunBtn.isHidden = false
        
        seconds = 0
        distance = Measurement(value: 0, unit: UnitLength.meters)
        locationList.removeAll()
        updateDisplay()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.eachSecond()
        }
        startLocationUpdates()

    }
    
    private func stopRun() {
        launchStackView.isHidden = false
        runDataStackView.isHidden = true
        startRunBtn.isHidden = false
        stopRunBtn.isHidden = true
        mapContainerView.isHidden = true
        
        locationManager.stopUpdatingLocation()
    }
    
    private func saveRun() {
        let newRun = Run(context: CoreDataStack.context)
        newRun.distance = distance.value
        newRun.duration = Int16(seconds)
        newRun.timestamp = Date()
        
        for location in locationList {
            let locationObject = Location(context: CoreDataStack.context)
            locationObject.timestamp = location.timestamp
            locationObject.latitude = location.coordinate.latitude
            locationObject.longitude = location.coordinate.longitude
            newRun.addToLocations(locationObject)
        }
        
        CoreDataStack.saveContext()
        
        run = newRun
    }
}

extension NewRunViewController: SegueHandlerType {
    enum SegueIdentifier: String {
        case details = "RunDetailsViewController"
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segueIdentifier(for: segue) {
        case .details:
            let destination = segue.destination as! RunDetailsViewController
            destination.run = run
        }
    }
}

extension NewRunViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for newLocation in locations {
            let howRecent = newLocation.timestamp.timeIntervalSinceNow
            guard newLocation.horizontalAccuracy < 20 && abs(howRecent) < 10 else { continue }
            
            if let lastLocation = locationList.last {
                let delta = newLocation.distance(from: lastLocation)
                distance = distance + Measurement(value: delta, unit: UnitLength.meters)
            }
            
            locationList.append(newLocation)
        }
    }
}
