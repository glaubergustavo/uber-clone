//
//  ViewController.swift
//  Uber
//
//  Created by Glauber Gustavo on 20/08/21.
//

import UIKit
import FirebaseAuth
import FirebaseDatabase

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let authentication = Auth.auth()
        
        authentication.addStateDidChangeListener { authentication, user in
            
            if let loggedUser = user {
                
                let database = Database.database().reference()
                let users = database.child("usuarios").child( loggedUser.uid )
                
                users.observeSingleEvent(of: .value) { snapshot in
                    
                    let userData = snapshot.value as? NSDictionary
                    if let userType = userData?["tipo"] as? String {
                        if userType == "Passageiro" {
                            self.performSegue(withIdentifier: "segueMainScreen", sender: nil)
                        } else {//Tipo: Motorista
                            self.performSegue(withIdentifier: "segueMainScreenDriver", sender: nil)
                        }
                    } else {
                        print("Usuário nāo foi cadastrado corretamente! Faltou especificar o campo tipo")
                    }
                }
            }
            
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
}

