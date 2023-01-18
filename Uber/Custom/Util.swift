//
//  Util.swift
//  Uber
//
//  Created by Glauber Gustavo on 18/01/23.
//

import Foundation

class Util {
    
    static func userCanceledRequest(_ canceled: Bool) {
        UserDefaults.standard.set(canceled, forKey: "userCanceledRequest")
        UserDefaults.standard.synchronize()
    }
}
