//
//  PassengerViewController.swift
//  Uber
//
//  Created by Glauber Gustavo on 22/08/21.
//

import UIKit
import FirebaseAuth
import FirebaseDatabase
import MapKit

class PassengerViewController: UIViewController, CLLocationManagerDelegate {
    
    @IBOutlet weak var btUberCall: UIButton!
    @IBOutlet weak var txfDestinationAddress: UITextField!
    @IBOutlet weak var map: MKMapView!
    
    var userLocal = CLLocationCoordinate2D()
    var driverLocal = CLLocationCoordinate2D()
    var latDestination = CLLocationDegrees()
    var lonDestination = CLLocationDegrees()
    var userName = ""
    var driverName = ""
    var calledUber = false
    var onTheWayUber = false
    var requests: DatabaseReference = DatabaseReference()
    
    let authentication = Auth.auth()
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
        
        self.loadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        locationManager.requestAlwaysAuthorization()
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
        
        //Recupera as coordenadas do local atual
        if let coordinates = manager.location?.coordinate {
            
            //Configura local atual do usuario
            self.userLocal = coordinates
            
            if self.onTheWayUber {
                self.showDriverPassengerOnMap()
            }else {
                self.mapConfig()
            }
        }
    }
    
    private func mapConfig() {
        
        let region = MKCoordinateRegion.init(center: self.userLocal,
                                             latitudinalMeters: 200,
                                             longitudinalMeters: 200)
        map.setRegion(region, animated: true)
        
        //Remove anota????es antes de criar
        map.removeAnnotations(map.annotations)
        
        //Cria uma anota????o para o local do usu??rio
        let userAnnotation = MKPointAnnotation()
        userAnnotation.coordinate = self.userLocal
        userAnnotation.title = "Meu Local"
        map.addAnnotation(userAnnotation)
    }
    
    private func loadData() {
        
        //Verifica se j?? tem uma requisi????o de Uber
        if let userEmail = self.authentication.currentUser?.email {
            
            self.requests = self.database.child("requisicoes")
            let requestsQuery = self.requests
                .queryOrdered(byChild: "email")
                .queryEqual(toValue: userEmail)
            
            requestsQuery.observe(.childAdded) { snapshot in
                if snapshot.value != nil {
                    self.btUberCall = .toggleButton(button: self.btUberCall,
                                                    title: "Cancelar Uber",
                                                    isEnabled: true,
                                                    color: .colorRed)
                    self.calledUber = true
                }
            }
            
            requestsQuery.observe(.childChanged) { snapshot in
                guard let dataUser = snapshot.value as? [String: Any] else { return }
                guard let latDriver = dataUser["motoristaLatitude"] as? CLLocationDegrees,
                      let lonDriver = dataUser["motoristaLongitude"] as? CLLocationDegrees else { return }
                guard let userName = dataUser["nome"] as? String else { return }
                guard let driverName = dataUser["nomeMotorista"] as? String else { return }
                self.driverName = driverName
                self.userName = userName
                self.driverLocal = CLLocationCoordinate2D(latitude: latDriver, longitude: lonDriver)
                self.showDriverPassengerOnMap()
            }
        }
    }
    
    private func customizeButtonCallDriver() {
        
        let driverLocation = CLLocation(latitude: self.driverLocal.latitude,
                                        longitude: self.driverLocal.longitude)
        
        let userLocation = CLLocation(latitude: self.userLocal.latitude,
                                      longitude: self.userLocal.longitude)
        
        let distance = driverLocation.distance(from: userLocation)
        let mDistance = round(distance)
        let kmDistance = round(mDistance / 1000)
        
        var buttonTitle = ""
        if distance < 1000, distance != 0 {
            buttonTitle = "Motorista \(mDistance) M de distancia"
        }else if distance == 0 {
            buttonTitle = "Seu motorista chegou"
        }else {
            buttonTitle = "Motorista \(kmDistance) KM de distancia"
        }
        self.btUberCall = .toggleButton(button: self.btUberCall,
                                        title: buttonTitle,
                                        isEnabled: false,
                                        color: .colorGreen)
    }
    
    private func showDriverPassengerOnMap() {
        
        self.onTheWayUber = true
        
        self.customizeButtonCallDriver()
        
        map.removeAnnotations(map.annotations)

        let latDiference = abs(self.userLocal.latitude - self.driverLocal.latitude) * 300000
        let lonDiference = abs(self.userLocal.longitude - self.driverLocal.longitude) * 300000
        let region = MKCoordinateRegion.init(center: self.userLocal,
                                             latitudinalMeters: latDiference,
                                             longitudinalMeters: lonDiference)
        map.setRegion(region, animated: true)
                
        let driverAnnotation = MKPointAnnotation()
        driverAnnotation.coordinate = self.driverLocal
        driverAnnotation.title = self.driverName
        map.addAnnotation(driverAnnotation)
        
        let userAnnotation = MKPointAnnotation()
        userAnnotation.coordinate = self.userLocal
        userAnnotation.title = self.userName
        map.addAnnotation(userAnnotation)
    }
    
    @IBAction func logOutUser(_ sender: Any) {

        do {
            try self.authentication.signOut()
            dismiss(animated: true, completion: nil)
        } catch  {
            print("N??o foi poss??vel deslogar o usu??rio!")
        }
    }
    
    @IBAction func callDriver(_ sender: Any) {
                
        self.requests = self.database.child("requisicoes")
        if let userEmail = self.authentication.currentUser?.email {
            
            if self.calledUber {//Uber chamado
                
                self.cancelRequest(userEmail: userEmail)
                
            } else {//Uber n??o foi chamado
                self.loadDestinationAddress()
                
            }
        }
    }
    
    private func cancelRequest(userEmail: String) {
        
        //Alternar para o bot??o de chamar
        self.btUberCall = .toggleButton(button: self.btUberCall,
                                        title: "Chamar Uber",
                                        isEnabled: true,
                                        color: .colorGreen)
        self.calledUber = false
        
        //Remover requisi????o
        self.requests.queryOrdered(byChild: "email")
               .queryEqual(toValue: userEmail)
               .observeSingleEvent(of: .childAdded) { snapshot in
            
            snapshot.ref.removeValue()
            
        }
    }
    
    private func loadDestinationAddress() {
        
        if let destinationAddress = self.txfDestinationAddress.text,
                                    !destinationAddress.isEmpty {
            
            CLGeocoder().geocodeAddressString(destinationAddress) { local, error in
                
                if error == nil {
                    if let localData = local?.first {
                        guard let street = localData.thoroughfare else { return }
                        guard let number = localData.subThoroughfare else { return }
                        guard let burgh = localData.subLocality else { return }
                        guard let city = localData.locality else { return }
                        guard let cep = localData.postalCode else { return }
                        
                        let completionAddress = "\(street), \(number), \(burgh) - \(city) - \(cep)"
                        
                        if let latDestination = localData.location?.coordinate.latitude {
                            self.latDestination = latDestination
                        }
                        if let lonDestination = localData.location?.coordinate.longitude {
                            self.lonDestination = lonDestination
                        }
                        self.addressAlert(completionAddress)
                    }
                }
            }
        }
    }
    
    private func addressAlert(_ completionAddress: String) {
        
        let alert = UIAlertController(title: "Confirme seu endere??o de destino!",
                                      message: completionAddress,
                                      preferredStyle: .alert)
        let cancel = UIAlertAction(title: "Cancelar",
                                   style: .cancel)
        let confirm = UIAlertAction(title: "Confirme",
                                    style: .default) { alertAction in
            self.loadRequestData()
        }
        
        alert.addAction(cancel)
        alert.addAction(confirm)
        
        self.present(alert, animated: true)
    }
        
    private func loadRequestData() {
                
        guard let userEmail = self.authentication.currentUser?.email else { return }
        guard let userID = self.authentication.currentUser?.uid else { return }

        //Recuperar nome do usu??rio
        let users = self.database.child("usuarios").child(userID)
        
        users.observeSingleEvent(of: .value) { snapshot in
            
            let data = snapshot.value as? NSDictionary
            if let userName = data?["nome"] as? String {
                
                //Alternar para o bot??o de cancelar
                self.btUberCall = .toggleButton(button: self.btUberCall,
                                                title: "Cancelar Uber",
                                                isEnabled: true,
                                                color: .colorRed)
                self.calledUber = true
                //Salvar dados da requisi????o
                let userData = [
                    "email" : userEmail,
                    "nome" : userName,
                    "latitude" : self.userLocal.latitude,
                    "longitude" : self.userLocal.longitude,
                    "destinoLatitude" : self.latDestination,
                    "destinoLongitude" : self.lonDestination
                ] as [String : Any]
                
                let request = self.database.child("requisicoes")
                request.childByAutoId().setValue(userData)
                
            } else {
                print("Cadastro feito sem o nome do usu??rio! Por favor refa??a!")
            }
        }
    }
}
