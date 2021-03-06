//
//  ActiveCell.swift
//  NemIOSClient
//
//  Created by Lyubomir Dominik on 23.12.15.
//  Copyright © 2015 Artygeek. All rights reserved.
//

import UIKit

class ActiveCell: UITableViewCell {

    @IBOutlet var title: UILabel!
    @IBOutlet weak var actionButton: UIButton!

    private var _isActive = false
    var isActive :Bool {
        get {
            return _isActive
        }
        set {
            if _isActive != newValue {
                if newValue {
                    self.actionButton.setImage(UIImage(named: "server_indicator_active"), forState: UIControlState.Normal)
                } else {
                    self.actionButton.setImage(UIImage(named: "server_indicator_passive"), forState: UIControlState.Normal)
                }
            }
            _isActive = newValue
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @IBAction func activateCell(sender: AnyObject) {
        super.setSelected(true, animated: true)
    }
}
