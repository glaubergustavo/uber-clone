//
//  DriverTableViewController.swift
//  Uber
//
//  Created by Glauber Gustavo on 23/08/21.
//

import UIKit
import FirebaseAuth
import FirebaseDatabase
import MapKit

class DriverTableViewController: UITableViewController, CLLocationManagerDelegate {
    
    var locationManager = CLLocationManager()
    var driverLocal = CLLocationCoordinate2D()
    var requests: DatabaseReference = DatabaseReference()
    var driverName = ""
    var driverEmail = ""
    var userData: [String: Any] = [:]
    
    let database = Database.database().reference()
    let authentication = Auth.auth()

    var requestsList: [DataSnapshot] = [] {
        didSet {
            self.tableView.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Configurar localizaçāo do motorista
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        //Recuperar nome do motorista
        self.driverLoadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.requests = self.database.child("requisicoes")
        
        //Limpa requisição, caso o usuario cancele
        self.cancelData()
        
        self.loadData()
    }
        
    //---------------------------------------------------------
    //------------ MARK: - Custom Methods ---------------------
    //---------------------------------------------------------
    
    private func cancelData() {
        self.requests.observe(.childRemoved) { snapshot in
            
            var index = 0
            for request in self.requestsList {
                if request.key == snapshot.key {
                    self.requestsList.remove(at: index)
                }
                index = index + 1
            }
            self.tableView.reloadData()
        }
    }
    
    private func loadData() {
        
        self.requestsList = []
        
        self.requests.observe(.childAdded) { snapshot in
            self.requestsList.append(snapshot)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        if let coordinates = manager.location?.coordinate {
            self.driverLocal = coordinates
        }
    }
    
    @IBAction func logOffDriver(_ sender: Any) {
        
        do {
            try self.authentication.signOut()
            dismiss(animated: true, completion: nil)
        } catch  {
            print("Nāo foi possível deslogar o usuário!")
        }
    }
    
    private func driverLoadData() {
        
        guard let driverID = self.authentication.currentUser?.uid else { return }
        guard let driverEmail = self.authentication.currentUser?.email else { return }
        
        let users = self.database.child("usuarios")
                                 .child(driverID)
        
        users.observeSingleEvent(of: .value) { snapshot in
            
            let data = snapshot.value as? NSDictionary
            guard let driverName = data?["nome"] as? String else { return }
            self.driverName = driverName
            self.driverEmail = driverEmail
        }
    }

    // MARK: - Table view data source
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let snapshot = self.requestsList[indexPath.row]
        self.performSegue(withIdentifier: "SegueAcceptRace", sender: snapshot)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "SegueAcceptRace" {
            
            guard let vc = segue.destination as? ConfirmRequestViewController else { return }
            guard let snapshot = sender as? DataSnapshot else { return }
            guard let userData = snapshot.value as? [String: Any] else { return }
            
            if let passengerLat = userData["latitude"] as? Double,
               let passengerLon = userData["longitude"] as? Double,
               let passengerName = userData["nome"] as? String,
               let passengerEmail = userData["email"] as? String {
                
                //Dados do passageiro
                let passengerLocal = CLLocationCoordinate2D(latitude: passengerLat,
                                                            longitude: passengerLon)
                
                vc.passengerName = passengerName
                vc.passengerEmail = passengerEmail
                vc.passengerLocal = passengerLocal
                vc.driverName = self.driverName
                vc.driverLocal = self.driverLocal
                vc.driverEmail = self.driverEmail
            }
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.requestsList.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        let snapshot = self.requestsList[indexPath.row]
        if let userData = snapshot.value as? [String: Any] {
            self.userData = userData
            if let passengerLat = userData["latitude"] as? Double,
               let passengerLon = userData["longitude"] as? Double {
                
                let driverLocation = CLLocation(latitude: self.driverLocal.latitude,
                                                longitude: self.driverLocal.longitude)
                
                let passengerLocation = CLLocation(latitude: passengerLat,
                                                   longitude: passengerLon)
                
                let mDistance = driverLocation.distance(from: passengerLocation)
                
                let kmDistance = round(mDistance / 1000)
                
                var requestDriver = ""
                if let recoverDriverEmail = userData["emailMotorista"] as? String {
                    if self.driverEmail == recoverDriverEmail {
                        requestDriver = " - {EM ANDAMENTO}"
                    }
                }
                
                if let userName = userData["nome"] as? String {
                    cell.textLabel?.text = "\(userName)" + "\(requestDriver)"
                }
                
                if mDistance < 1000 {
                    cell.detailTextLabel?.text = "\(round(mDistance)) M de distância"
                }else {
                    cell.detailTextLabel?.text = "\(kmDistance) KM de distância"
                }
            }
        }
        return cell
    }
}
