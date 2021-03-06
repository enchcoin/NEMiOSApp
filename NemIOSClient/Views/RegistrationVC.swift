import UIKit
class RegistrationVC: AbstractViewController
{
    //MARK: - Private Variables

    @IBOutlet weak var userName: UITextField!
    
    @IBOutlet weak var scroll: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var backButton: UIButton!
        
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var createButton: UIButton!
    
    //MARK: - Load Methods

    override func viewDidLoad() {
        super.viewDidLoad()
        
        contentView.layer.cornerRadius = 10
        contentView.clipsToBounds = true
        
        let center: NSNotificationCenter = NSNotificationCenter.defaultCenter()
        
        center.addObserver(self, selector: #selector(RegistrationVC.keyboardWillShow(_:)), name: UIKeyboardWillShowNotification, object: nil)
        center.addObserver(self, selector: #selector(RegistrationVC.keyboardWillHide(_:)), name: UIKeyboardWillHideNotification, object: nil)
        
        createButton.setTitle("CREATE_NEW_ACCCOUNT".localized(), forState: UIControlState.Normal)
        titleLabel.text = "CREATE_NEW_ACCCOUNT".localized()
        userName.placeholder = "ACCOUNT_NAME_PLACEHOLDER".localized()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        State.currentVC = SegueToRegistrationVC
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    //MARK: - IBAction

    @IBAction func backButtonTouchUpInside(sender: AnyObject) {
        if self.delegate != nil && self.delegate!.respondsToSelector(#selector(MainVCDelegate.pageSelected(_:))) {
            (self.delegate as! MainVCDelegate).pageSelected(SegueToAddAccountVC)
        }
    }
    
    @IBAction func chouseTextField(sender: UITextField) {
        scroll.scrollRectToVisible(self.view.convertRect(sender.frame, fromView: sender), animated: true)
    }
        
    @IBAction func nextBtnPressed(sender: AnyObject) {        
        var alert :UIAlertView!
        
        if userName.text != "" {
            WalletGenerator().createWallet(userName.text!)
            
            State.toVC = SegueToLoginVC
            
            if self.delegate != nil && self.delegate!.respondsToSelector(#selector(MainVCDelegate.pageSelected(_:))) {
                (self.delegate as! MainVCDelegate).pageSelected(SegueToLoginVC)
            }
        }
        else {
            
            alert  = UIAlertView(title: "VALIDATION".localized(), message: "FIELDS_EMPTY_ERROR".localized(), delegate: self, cancelButtonTitle: "OK")
        }
        
        if(alert != nil) {
            alert.show()
        }
    }
    
    @IBAction func changeField(sender: UITextField) {
        sender.endEditing(true)
    }
    
    //MARK: - Keyboard Delegate
    
    final func keyboardWillShow(notification: NSNotification) {
        let info:NSDictionary = notification.userInfo!
        let keyboardSize = (info[UIKeyboardFrameEndUserInfoKey] as! NSValue).CGRectValue()
        
        var keyboardHeight:CGFloat = keyboardSize.height
        
        keyboardHeight -= self.view.frame.height - self.scroll.frame.height
        
        scroll.contentInset = UIEdgeInsetsMake(0, 0, keyboardHeight - 10, 0)
        scroll.scrollIndicatorInsets = UIEdgeInsetsMake(0, 0, keyboardHeight + 15, 0)
    }
    
    func keyboardWillHide(notification: NSNotification) {
        self.scroll.contentInset = UIEdgeInsetsZero
        self.scroll.scrollIndicatorInsets = UIEdgeInsetsZero
    }
}
