import UIKit

class ButtonBoxTypeOne: UIButton {
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if let imageView = self.imageView {
            imageView.frame = CGRect(x: self.frame.width / 2 - 12, y: self.frame.height / 3 - 8, width: 24, height: 24)
        }
        
        if let titleLabel = self.titleLabel {
            titleLabel.sizeToFit()
            titleLabel.center.x = self.frame.width / 2
            titleLabel.center.y = self.frame.height * 2 / 3
        }
    }
}
