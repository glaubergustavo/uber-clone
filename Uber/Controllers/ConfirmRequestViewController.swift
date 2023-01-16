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

enum RaceStatus: String {
    case onRequest = "em_requisicao"
    case getPassenger = "pegar_passageiro"
    case startTrip = "iniciar_viagem"
    case onTrip = "em_viagem"
}

class ConfirmRequestViewController: UIViewController, CLLocationManagerDelegate {
    
    @IBOutlet weak var map: MKMapView!
    @IBOutlet weak var btnRaceAccept: UIButton!
    
    var passengerName = ""
    var passengerEmail = ""
    var driverName = ""
    var driverEmail = ""
    var passengerLocal = CLLocationCoordinate2D()
    var driverLocal = CLLocationCoordinate2D()
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
    }
    
    //---------------------------------------------------------
    //------------ MARK: - Custom Methods ---------------------
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
    
    private func updateRequest() {
        
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
    
    private func getPassenger() {
        self.status = .getPassenger
        self.toggleButton(title: "A caminho do passageiro",
                          isEnabled: false,
                          color: UIColor(displayP3Red: 0.502, green: 0.502, blue: 0.502, alpha: 1))
    }
    
    private func driverUpdate() {
        
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
                        
                        let status = self.startTripStatus()
                        let driverData = [
                            "motoristaLatitude" : self.driverLocal.latitude,
                            "motoristaLongitude" : self.driverLocal.longitude,
                            "status" : status
                        ]
                        snapshot.ref.updateChildValues(driverData)
                        self.toggleButton(title: "A caminho do passageiro",
                                          isEnabled: false,
                                          color: UIColor(displayP3Red: 0.502, green: 0.502, blue: 0.502, alpha: 1))
                        
                    }else if recoveredStatus == RaceStatus.startTrip.rawValue {
                        self.toggleButton(title: "Iniciar Viagem",
                                          isEnabled: true,
                                          color: UIColor(displayP3Red: 0.067, green: 0.576, blue: 0.604, alpha: 1))
                    }
                }
            }
        }
    }
    
    private func startTripStatus() -> String {
        
        let driverLocation = CLLocation(latitude: self.driverLocal.latitude,
                                        longitude: self.driverLocal.longitude)
        
        let passengerLocation = CLLocation(latitude: self.passengerLocal.latitude,
                                           longitude: self.passengerLocal.longitude)
        
        let mDistance = driverLocation.distance(from: passengerLocation)
        
        let kmDistance = round(mDistance / 1000)
        
        if kmDistance <= 0.5 {
            self.status = .startTrip
        }
        return self.status.rawValue
    }
    
    private func toggleButton(title: String,
                              isEnabled: Bool,
                              color: UIColor) {
        
        self.btnRaceAccept.setTitle(title, for: .normal)
        self.btnRaceAccept.isEnabled = isEnabled
        self.btnRaceAccept.backgroundColor = color
    }
    
    //---------------------------------------------------------
    //------------ MARK: - Actions Buttons --------------------
    //---------------------------------------------------------
    
    @IBAction func raceAccept(_ sender: Any) {
        
        if self.status == .onRequest {
            self.updateRequest()
            self.showWayToPassengerOnMap()
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
        self.driverUpdate()
//        manager.stopUpdatingLocation()
    }
}
