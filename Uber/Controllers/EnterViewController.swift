//
//  EnterViewController.swift
//  Uber
//
//  Created by Glauber Gustavo on 21/08/21.
//

import UIKit
import FirebaseAuth

class EnterViewController: UIViewController {
    
    @IBOutlet weak var tfEmail: UITextField!
    @IBOutlet weak var tfPassword: UITextField!
    
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
    
    @IBAction func enter(_ sender: Any) {
        
        let regress = validateFields()
        if regress == "" {
            
            //Faz autenticaçāo do usuário (Login)
            let authentication = Auth.auth()
            
            if let retrievedEmail = tfEmail.text {
                if let retrievedPassword = tfPassword.text {
                    
                    authentication.signIn(withEmail: retrievedEmail, password: retrievedPassword) { user, error in
                        
                        if error == nil {
                            
                            /*
                             Valida se o usuário está logado
                             Caso o usuário esteja logado, será redirecionado automaticamente de acordo com o tipo de usuário, com evento criado na ViewController
                             */
                            if user == nil {
                                print("Erro ao logar usuário!")
                            }
                            
                        } else {
                            print("Erro ao autenticar usuário, tente novamente!")
                        }
                        
                    }
                    
                }
            }
            
            
        } else {
            print("O campo \(regress) nāo foi preenchido!")
        }
        
    }
    
    func validateFields() -> String {
        
        if (tfEmail.text?.isEmpty)! && (tfPassword.text?.isEmpty)! {
            return "E-mail e Senha"
        } else if (tfEmail.text?.isEmpty)! {
            return "E-mail"
        } else if (tfPassword.text?.isEmpty)! {
            return "Senha"
        }
        return ""
    }
}
