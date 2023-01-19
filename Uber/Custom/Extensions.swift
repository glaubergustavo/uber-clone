//
//  Extensions.swift
//  Uber
//
//  Created by Glauber Gustavo on 16/01/23.
//

import UIKit

//-----------------------------------------------------------------------
//  MARK: - UIButton
//-----------------------------------------------------------------------

extension UIButton {
    
    class func toggleButton(button: UIButton, title: String, isEnabled: Bool, color: UIColor) -> UIButton {
         button.setTitle(title, for: .normal)
         button.isEnabled = isEnabled
         button.backgroundColor = color
        
        return button
    }
}

//-----------------------------------------------------------------------
//  MARK: - UIColor
//-----------------------------------------------------------------------

extension UIColor {
    
    class var colorGreen: UIColor { return UIColor(displayP3Red: 0.067, green: 0.576, blue: 0.604, alpha: 1)}
    class var colorRed: UIColor { return UIColor(displayP3Red: 0.831, green: 0.237, blue: 0.146, alpha: 1)}
    class var colorGray: UIColor { return UIColor(displayP3Red: 0.502, green: 0.502, blue: 0.502, alpha: 1)}    
}
