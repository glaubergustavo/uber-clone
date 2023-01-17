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
        
        self.mapConfig()
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
    
    private func starTrip() {
        self.status = .startTrip
        self.btnRaceAccept = .toggleButton(button: self.btnRaceAccept,
                                           title: "Iniciar Viagem",
                                           isEnabled: true,
                                           color: .colorButtonStarTrip)
    }
    
    private func getPassenger() {
        self.status = .getPassenger
        self.btnRaceAccept = .toggleButton(button: self.btnRaceAccept,
                                           title: "A caminho do passageiro",
                                           isEnabled: false,
                                           color: .colorButtonGetPassenger)
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
                    
                    //Status pegar_passageiro
                    if recoveredStatus == RaceStatus.getPassenger.rawValue {
                        
                        self.setCurrentStatus()
                        
                        self.showPassengerDriverOnMap(startDestination: self.driverLocal,
                                                 endDestination: self.passengerLocal,
                                                 starDestinationText: "Meu local",
                                                 endDestinationText: self.passengerName)
                        
                    }else if recoveredStatus == RaceStatus.startTrip.rawValue {
                        
                        if let latDestination = data["destinoLatitude"] as? Double,
                        let lonDestination = data["destinoLongitude"] as? Double {
                            self.destinationLocal = CLLocationCoordinate2D(latitude: latDestination, longitude: lonDestination)
                        }
                        self.showPassengerDriverOnMap(startDestination: self.passengerLocal,
                                                 endDestination: self.destinationLocal,
                                                 starDestinationText: self.driverName,
                                                 endDestinationText: "Destino de \(self.passengerName)")
                        
                    }else if recoveredStatus == RaceStatus.onTrip.rawValue {
                        
                    }
                    
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
    
    private func setCurrentStatus() {
        
        if self.calculatedDistance() <= 0.5 {
            self.starTrip()
        }else {
            self.getPassenger()
        }
    }
    
    private func calculatedDistance() -> Double {
        
        let driverLocation = CLLocation(latitude: self.driverLocal.latitude,
                                        longitude: self.driverLocal.longitude)
        
        let passengerLocation = CLLocation(latitude: self.passengerLocal.latitude,
                                           longitude: self.passengerLocal.longitude)
        
        let mDistance = driverLocation.distance(from: passengerLocation)
        
        let kmDistance = round(mDistance / 1000)
        
        return kmDistance
    }
    
    private func reloadData() {
        
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
            self.getPassenger()
        }
    }
    
    //---------------------------------------------------------
    //------------ MARK: - Custom Map ---------------------
    //---------------------------------------------------------
    
    private func mapConfig() {
        
        //Configurar área inicial do mapa
        let region = MKCoordinateRegion.init(center: self.passengerLocal,
                                             latitudinalMeters: 200,
                                             longitudinalMeters: 200)
        map.setRegion(region, animated: true)
        
        //Adiciona anotacāo para o passageiro
        let passengerAnnotation = MKPointAnnotation()
        passengerAnnotation.coordinate = self.passengerLocal
        passengerAnnotation.title = self.passengerName
        map.addAnnotation(passengerAnnotation)
    }
    
    private func showWayToPassengerOnMap() {
        
        //Exibir caminho para o passageiro no mapa
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
    
    private func showPassengerDriverOnMap(startDestination: CLLocationCoordinate2D, endDestination: CLLocationCoordinate2D, starDestinationText: String, endDestinationText: String) {
        
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
    
    //---------------------------------------------------------
    //------------ MARK: - Actions Buttons --------------------
    //---------------------------------------------------------
    
    @IBAction func raceAccept(_ sender: Any) {
        
        if self.status == .onRequest {
            self.reloadData()
            self.showWayToPassengerOnMap()
        }else if self.status == .startTrip {
            self.status = .onTrip
            self.driverReloadData()
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
