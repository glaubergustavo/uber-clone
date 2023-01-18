//
//  ConfirmRequestViewController.swift
//  Uber
//
//  Created by Glauber Gustavo on 23/08/21.
//

import UIKit
import MapKit
import FirebaseAuth
import FirebaseDatabase

class ConfirmRequestViewController: UIViewController, CLLocationManagerDelegate {
    
    @IBOutlet weak var map: MKMapView!
    @IBOutlet weak var btnRaceAccept: UIButton!
    
    var passengerName = ""
    var passengerEmail = ""
    var driverName = ""
    var driverEmail = ""
    var passengerLocal = CLLocationCoordinate2D()
    var driverLocal = CLLocationCoordinate2D()
    var destinationLocal = CLLocationCoordinate2D()
    var requests: DatabaseReference = DatabaseReference()
    var status: RaceStatus = .onRequest
    
    let database = Database.database().reference()
    
    private lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.allowsBackgroundLocationUpdates = true
        
        return manager
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.mapConfig(local: self.passengerLocal, localText: self.passengerName)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        locationManager.requestAlwaysAuthorization()
        
        self.reloadRaceStatus()
    }
    
    //---------------------------------------------------------
    //------------ MARK: - Custom Methods ---------------------
    //---------------------------------------------------------
    
    private func reloadRaceStatus() {
        self.requests = self.database.child("requisicoes")
        let queryRequest = self.requests.queryOrdered(byChild: "email")
            .queryEqual(toValue: self.passengerEmail)
        
        queryRequest.observeSingleEvent(of: .childChanged) { snapshot in
            self.driverReloadData()
        }
    }
    
    private func setOnTripStatus() {
        self.status = .onTrip
        self.btnRaceAccept = .toggleButton(button: self.btnRaceAccept,
                                           title: "Em Viagem",
                                           isEnabled: false,
                                           color: .colorButtonOnTrip)
    }
    
    private func setStarTripStatus() {
        self.status = .startTrip
        self.btnRaceAccept = .toggleButton(button: self.btnRaceAccept,
                                           title: "Iniciar Viagem",
                                           isEnabled: true,
                                           color: .colorButtonStarTrip)
    }
        
    private func setGetPassengerStatus() {
        self.status = .getPassenger
        self.btnRaceAccept = .toggleButton(button: self.btnRaceAccept,
                                           title: "A caminho do passageiro",
                                           isEnabled: false,
                                           color: .colorButtonGetPassenger)
    }
    
    private func setfinalizeRaceStatus() {
        self.status = .finalizeRace
        self.btnRaceAccept = .toggleButton(button: self.btnRaceAccept,
                                           title: "Encerrar Corrida",
                                           isEnabled: true,
                                           color: .colorButtonCancel)
    }
    
    private func driverReloadData() {
        
        //Atualiza localizacao do motorista no Firebase
        if !self.passengerEmail.isEmpty {
            
            self.requests = self.database.child("requisicoes")
            let queryRequest = self.requests.queryOrdered(byChild: "email")
                                            .queryEqual(toValue: self.passengerEmail)
            
            queryRequest.observeSingleEvent(of: .childAdded) { snapshot in
                
                guard let data = snapshot.value as? [String: Any] else { return }
                if let recoveredStatus = data["status"] as? String {
                    
                    if let latDestination = data["destinoLatitude"] as? Double,
                    let lonDestination = data["destinoLongitude"] as? Double {
                        self.destinationLocal = CLLocationCoordinate2D(latitude: latDestination, longitude: lonDestination)
                    }
                    
                    if recoveredStatus == RaceStatus.getPassenger.rawValue {
                        
                        if (self.calculatedDistance(of: self.driverLocal,
                                                    to: self.passengerLocal)).isEqual(to: 0.0) {
                            self.setStarTripStatus()
                        }
                        
                        self.showPassengerDriverOnMap(startDestination: self.driverLocal,
                                                 endDestination: self.passengerLocal,
                                                 starDestinationText: "Meu local",
                                                 endDestinationText: self.passengerName)
                        
                    }else if recoveredStatus == RaceStatus.startTrip.rawValue {
                        
                        self.showPassengerDriverOnMap(startDestination: self.passengerLocal,
                                                 endDestination: self.destinationLocal,
                                                 starDestinationText: self.driverName,
                                                 endDestinationText: "Destino de \(self.passengerName)")
                        
                        
                    }else if recoveredStatus == RaceStatus.onTrip.rawValue {
                        
                        if self.calculatedDistance(of: self.driverLocal,
                                                   to: self.destinationLocal) == 0.0 {
                            self.setfinalizeRaceStatus()
                        }
                        self.showPassengerDriverOnMap(startDestination: self.destinationLocal,
                                                 endDestination: self.driverLocal,
                                                 starDestinationText: "Destino de \(self.passengerName)",
                                                 endDestinationText: self.driverName)
                        
                    }else if recoveredStatus == RaceStatus.finalizeRace.rawValue {
                        
                        Util.userCanceledRequest(false)
                        //Remover requisiçāo
                        self.requests.queryOrdered(byChild: "email")
                            .queryEqual(toValue: self.passengerEmail)
                               .observeSingleEvent(of: .childAdded) { snapshot in
                            
                            snapshot.ref.removeValue()
                                   self.status = .onRequest
                        }
                    }
                    
                    if self.status != .onRequest {
                        let driverData = [
                            "motoristaLatitude" : self.driverLocal.latitude,
                            "motoristaLongitude" : self.driverLocal.longitude,
                            "status" : self.status.rawValue
                        ]
                        snapshot.ref.updateChildValues(driverData)
                    }
                }
            }
        }
    }
    
    
    
    private func calculatedDistance(of firstLocal: CLLocationCoordinate2D, to endLocal: CLLocationCoordinate2D) -> Double {
        
        let driverLocation = CLLocation(latitude: firstLocal.latitude,
                                        longitude: firstLocal.longitude)
        
        let passengerLocation = CLLocation(latitude: endLocal.latitude,
                                           longitude: endLocal.longitude)
        
        let mDistance = driverLocation.distance(from: passengerLocation)
        
        let kmDistance = round(mDistance / 1000)
        
        return kmDistance
    }
    
    private func reloadRaceData() {
        
        //Atualizar a requisiçāo
        self.requests = self.database.child("requisicoes")
        
        self.requests
                .queryOrdered(byChild: "email")
                .queryEqual(toValue: self.passengerEmail)
                .observeSingleEvent(of: .childAdded) { snapshot in
            
            let driverData = [
                "motoristaLatitude" : self.driverLocal.latitude,
                "motoristaLongitude" : self.driverLocal.longitude,
                "nomeMotorista" : self.driverName,
                "emailMotorista" : self.driverEmail,
                "status" : RaceStatus.getPassenger.rawValue
            ]
            
            snapshot.ref.updateChildValues(driverData)
        }
    }
    
    //---------------------------------------------------------
    //------------ MARK: - Custom Map ---------------------
    //---------------------------------------------------------
    
    private func mapConfig(local: CLLocationCoordinate2D,
                           localText: String) {
        
        //Configurar área inicial do mapa
        let region = MKCoordinateRegion.init(center: local,
                                             latitudinalMeters: 200,
                                             longitudinalMeters: 200)
        map.setRegion(region, animated: true)
        
        //Adiciona anotacāo para
        let passengerAnnotation = MKPointAnnotation()
        passengerAnnotation.coordinate = local
        passengerAnnotation.title = localText
        map.addAnnotation(passengerAnnotation)
    }
    
    private func showWayToPassengerOnMap() {
        
        let passengerCLL = CLLocation(latitude: passengerLocal.latitude,
                                      longitude: passengerLocal.longitude)
        CLGeocoder().reverseGeocodeLocation(passengerCLL) { local, error in
            
            if error == nil {
                
                if let localData = local?.first {
                    let placemark = MKPlacemark(placemark: localData)
                    let mapItem = MKMapItem(placemark: placemark)
                    mapItem.name = self.passengerName
                    
                    let options = [
                        MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                    ]
                    mapItem.openInMaps(launchOptions: options)
                }
            }
        }
    }
    
    private func showWayToDestinationPassengerOnMap() {
        
        let destinationLocalCLL = CLLocation(latitude: self.destinationLocal.latitude,
                                      longitude: self.destinationLocal.longitude)
        CLGeocoder().reverseGeocodeLocation(destinationLocalCLL) { local, error in
            
            if error == nil {
                
                if let localData = local?.first {
                    let placemark = MKPlacemark(placemark: localData)
                    let mapItem = MKMapItem(placemark: placemark)
                    mapItem.name = "Destino do \(self.passengerName)"
                    
                    let options = [
                        MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                    ]
                    mapItem.openInMaps(launchOptions: options)
                }
            }
        }
    }
    
    private func showPassengerDriverOnMap(startDestination: CLLocationCoordinate2D,
                                          endDestination: CLLocationCoordinate2D,
                                          starDestinationText: String,
                                          endDestinationText: String) {
        
        map.removeAnnotations(map.annotations)

        let latDiference = abs(startDestination.latitude - endDestination.latitude) * 300000
        let lonDiference = abs(startDestination.longitude - endDestination.longitude) * 300000
        let region = MKCoordinateRegion.init(center: startDestination,
                                             latitudinalMeters: latDiference,
                                             longitudinalMeters: lonDiference)
        map.setRegion(region, animated: true)
                
        let driverAnnotation = MKPointAnnotation()
        driverAnnotation.coordinate = startDestination
        driverAnnotation.title = starDestinationText
        map.addAnnotation(driverAnnotation)
        
        let userAnnotation = MKPointAnnotation()
        userAnnotation.coordinate = endDestination
        userAnnotation.title = endDestinationText
        map.addAnnotation(userAnnotation)
    }
    
    private func dismiss() {
        navigationController?.popViewController(animated: true)
    }
    
    //---------------------------------------------------------
    //------------ MARK: - Actions Buttons --------------------
    //---------------------------------------------------------
    
    @IBAction func raceAccept(_ sender: Any) {
        
        if self.status == .onRequest {
            self.reloadRaceData()
            self.setGetPassengerStatus()
            self.showWayToPassengerOnMap()
        }else if self.status == .startTrip {
            self.setOnTripStatus()
            self.driverReloadData()
            self.showWayToDestinationPassengerOnMap()
        }else if self.status == .startTrip {
            self.setOnTripStatus()
        }else if self.status == .finalizeRace {
            self.mapConfig(local: self.driverLocal, localText: "Meu local")
            self.driverReloadData()
            self.dismiss()
        }
    }
    
    //---------------------------------------------------------
    //---------- MARK: - CLLocationManagerDelegate ------------
    //---------------------------------------------------------
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {

        switch status {
        case .authorizedAlways, .authorizedWhenInUse, .authorized:
            manager.startUpdatingLocation()
            break
        case .notDetermined, .restricted, .denied:
            break
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        guard let coordinates = manager.location?.coordinate else { return }
                
        self.driverLocal = coordinates
        self.driverReloadData()
    }
}
