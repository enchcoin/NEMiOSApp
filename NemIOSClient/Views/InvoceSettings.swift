//
//  InvoceSettings.swift
//  NemIOSClient
//
//  Created by Lyubomir Dominik on 24.12.15.
//  Copyright © 2015 Artygeek. All rights reserved.
//

import UIKit

class InvoceSettings: AbstractViewController {
    
    //MARK: - @IBOutlet
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var scroll: UIScrollView!
    @IBOutlet weak var prefix: NEMTextField!
    @IBOutlet weak var postfix: NEMTextField!
    @IBOutlet weak var message: NEMTextField!
    @IBOutlet weak var saveButton: UIButton!
    
    private let _accounts :[Wallet] = CoreDataManager().getWallets()
    
    //MARK: - Load Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        contentView.layer.cornerRadius = 5
        contentView.clipsToBounds = true
        let loadData = State.loadData
        
        prefix.text = loadData?.invoicePrefix
        postfix.text = loadData?.invoicePostfix
        message.text = loadData?.invoiceMessage
        
        prefix.placeholder = "   " + "PREFIX".localized()
        postfix.placeholder = "   " + "POSTFIX".localized()
        message.placeholder = "   " + "MESSAGE".localized()
        
        saveButton.setTitle("SAVE".localized(), forState: UIControlState.Normal)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    //MARK: - @IBAction
    
    @IBAction func closePopUp(sender: AnyObject) {
        self.view.removeFromSuperview()
        self.removeFromParentViewController()
    }
    
    @IBAction func switchField(sender: NEMTextField) {
        switch sender {
        case prefix:
            postfix.becomeFirstResponder()
        case postfix:
            message.becomeFirstResponder()
        case message:
            message.endEditing(true)
        default:
            break
        }
    }
    
    
    @IBAction func reset(sender: AnyObject) {
        let loadData = State.loadData
        loadData?.invoicePrefix = prefix.text
        loadData?.invoicePostfix = postfix.text
        loadData?.invoiceMessage = message.text
        
        CoreDataManager().commit()
        (self.delegate as! AbstractViewController).viewDidAppear(false)
        closePopUp(self)
    }
}
