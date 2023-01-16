//
//  RegistrationViewController.swift
//  Uber
//
//  Created by Glauber Gustavo on 21/08/21.
//

import UIKit
import FirebaseAuth
import FirebaseDatabase

class RegistrationViewController: UIViewController {
    
    @IBOutlet weak var tfEmail: UITextField!
    @IBOutlet weak var tfFullName: UITextField!
    @IBOutlet weak var tfPassword: UITextField!
    @IBOutlet weak var swUserType: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
   
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }

    @IBAction func btRegisterUser(_ sender: Any) {
        
        let regress = validateFields()
        if regress == "" {
            
            //cadastrar usuario no Firebase
            let authentication = Auth.auth()
            
            if let retrievedEmail = tfEmail.text {
                if let retrievedName = tfFullName.text {
                    if let retrievedPassword = tfPassword.text {
                        
                        authentication.createUser(withEmail: retrievedEmail, password: retrievedPassword) { (user, error) in
                            
                            if error == nil {
                                
                                //Valida se o usuário está logado
                                if user != nil {
                                    
                                    //Configura database
                                    let database = Database.database().reference()
                                    let users = database.child("usuarios")
                                    
                                    //Verifica tipo do usuário
                                    var type = ""
                                    if self.swUserType.isOn {//Passageiro
                                        type = "Passageiro"
                                    } else {//Motorista
                                        type = "Motorista"
                                    }
                                    
                                    //Salva no banco de dados do usuário
                                    let userData = [
                                        "email" : user?.user.email,
                                        "nome" : retrievedName,
                                        "tipo" : type
                                    ]
                                    
                                    //Salvar dados
                                    users.child((user?.user.uid)!).setValue(userData)
                                    
                                    /*
                                     Valida se o usuário está logado
                                     Caso o usuário esteja logado, será redirecionado automaticamente de acordo com o tipo de usuário, com evento criado na ViewController
                                     */

                                } else {
                                    print("Erro ao autenticar o usuário!")
                                }
                                
                            } else {
                                print("Erro ao criar conta do usuário, tente novamente!")
                            }
                        }
                        
                    }
                }
            }
            
            
            
        } else {
            print("O campo \(regress) nāo foi preenchido!")
        }
        
    }
    
    func validateFields() -> String {
        
        if (tfEmail.text?.isEmpty)! && (tfFullName.text?.isEmpty)! && (tfPassword.text?.isEmpty)! {
            return "E-mail, Nome completo e Senha"
        } else if (tfEmail.text?.isEmpty)!, (tfFullName.text?.isEmpty)! {
            return "E-mail e Nome completo"
        } else if (tfEmail.text?.isEmpty)!, (tfPassword.text?.isEmpty)! {
            return "E-mail e Senha"
        } else if (tfFullName.text?.isEmpty)!, (tfPassword.text?.isEmpty)!{
            return "Nome Completo e Senha"
        } else if (tfEmail.text?.isEmpty)! {
            return "E-mail"
        } else if (tfFullName.text?.isEmpty)! {
            return "Nome completo"
        } else if (tfPassword.text?.isEmpty)! {
            return "Senha"
        }
        return ""
    }
}
