import UIKit

class MessageVC: AbstractViewController, UITableViewDelegate, UIAlertViewDelegate, APIManagerDelegate, AccountsChousePopUpDelegate, DetailedTableViewCellDelegate
{
    private struct DefinedCell
    {
        var type :ConversationCellType = ConversationCellType.Unknown
        var height :CGFloat = 44
        var minCosignatories :Int? = nil
        var detailsTop :NSAttributedString = NSAttributedString(string: "")
        var detailsMiddle :NSAttributedString = NSAttributedString(string: "")
        var detailsBottom :NSAttributedString = NSAttributedString(string: "")
    }
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var userInfo: NEMLabel!
    @IBOutlet weak var amoundField: NEMTextField?
    @IBOutlet weak var messageField: NEMTextField?
    @IBOutlet weak var sendButton: UIButton?
    @IBOutlet weak var accountsButton: UIButton?
    @IBOutlet weak var amoundContainerView: UIView!
    @IBOutlet weak var contactInfo: UILabel!
    
    @IBOutlet weak var encButton: UIButton!
    @IBOutlet weak var copyButton: UIButton!
    
    private var _unconfirmedTransactions  :[TransactionPostMetaData] = []
    private var _transactions :[TransactionPostMetaData] = []
    private var _definedCells :[DefinedCell] = []

    private var _apiManager :APIManager? = APIManager()
    private var _operationDipatchQueue :dispatch_queue_t = dispatch_queue_create("Message VC operation queu", nil)
    
    private let _contact :Correspondent = State.currentContact!
    private var _accounts :[AccountGetMetaData] = []
    private var _mainAccount :AccountGetMetaData? = nil
    private var _activeAccount :AccountGetMetaData? = nil
    
    private var _isEnc = false
    
    private var _bottomInsert :CGFloat = 0
    
    let contact :Correspondent = State.currentContact!
    
    private let rowLength :Int = 21
    private let textSizeCommon :CGFloat = 12
    private let textSizeXEM :CGFloat = 14
    
    private let greenColor :UIColor = UIColor(red: 65/256, green: 206/256, blue: 123/256, alpha: 1)
    private let grayColor :UIColor = UIColor(red: 239 / 255, green: 239 / 255, blue: 244 / 255, alpha: 1)
    
    private var _requestsLimit: Int = 2
    private var _transactionsLimit: Int = 50
    
    private var _requestCounter = 0
    private var _completed = 0
    private var _unconfirmed = 0
    private var _account_address :String? = nil
    private var _timer: NSTimer? = nil
    private var _popup :AbstractViewController? = nil

    // MARK: - Load Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        copyButton.setTitle("COPY", forState: UIControlState.Normal)
        userInfo.text = "NO_INTERNET_CONNECTION".localized()
        amoundField?.placeholder = "AMOUNT".localized()
        messageField?.placeholder = "MESSAGE".localized()
        sendButton?.setTitle("SEND".localized(), forState: UIControlState.Normal)
        accountsButton?.setTitle("ACCOUNTS".localized(), forState: UIControlState.Normal)
        
        _apiManager?.delegate = self
        
        _initButtonsConfigs()
        contactInfo.text = contact.name
        
        let privateKey = HashManager.AES256Decrypt(State.currentWallet!.privateKey, key: State.loadData!.password!)
        _account_address = AddressGenerator.generateAddressFromPrivateKey(privateKey!)
        
        if !Validate.stringNotEmpty(self.contact.public_key){
            self._apiManager?.accountGet(State.currentServer!, account_address: self.contact.address)
        }
        
        _apiManager?.accountGet(State.currentServer!, account_address: _account_address!)
        
        self.tableView.tableFooterView = UIView(frame: CGRectZero)
        scrollToEnd()
        
        let observer: NSNotificationCenter = NSNotificationCenter.defaultCenter()
        
        observer.addObserver(self, selector: #selector(MessageVC.keyboardWillShow(_:)), name: UIKeyboardWillShowNotification, object: nil)
        observer.addObserver(self, selector: #selector(MessageVC.keyboardWillHide(_:)), name: UIKeyboardWillHideNotification, object: nil)

        _timer = NSTimer.scheduledTimerWithTimeInterval(NSTimeInterval(updateInterval), target: self, selector: #selector(MessageVC.refreshHistory), userInfo: nil, repeats: true)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        State.currentVC = SegueToMessageVC
        
        let observer: NSNotificationCenter = NSNotificationCenter.defaultCenter()
        
        observer.addObserver(self, selector: #selector(MessageVC.keyboardWillShow(_:)), name: UIKeyboardWillShowNotification, object: nil)
        observer.addObserver(self, selector: #selector(MessageVC.keyboardWillHide(_:)), name: UIKeyboardWillHideNotification, object: nil)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        self.view.endEditing(true)
        
        let observer: NSNotificationCenter = NSNotificationCenter.defaultCenter()
        observer.removeObserver(self)
        
        _timer?.invalidate()
    }

    // MARK: - IBAction
    
    @IBAction func backButtonTouchUpInside(sender: AnyObject) {
        if self.delegate != nil && self.delegate!.respondsToSelector(#selector(MainVCDelegate.pageSelected(_:))) {
            (self.delegate as! MainVCDelegate).pageSelected(SegueToMessages)
        }
    }
    
    @IBAction func amoundFieldDidEndOnExit(sender: UITextField) {
        if Double(sender.text!) == nil {
            sender.text = "0"
        }
    }
    
    @IBAction func messageFieldDidEndOnExit(sender: UITextField) {

    }
    
    @IBAction func copyCorrespondentAddress(sender: AnyObject) {
        
        let pasteBoard :UIPasteboard = UIPasteboard.generalPasteboard()
        pasteBoard.string = _contact.address
    }
    
    @IBAction func encTouchUpInside(sender: UIButton) {
        _isEnc = !_isEnc
        sender.backgroundColor = (_isEnc) ? greenColor : grayColor
    }
    
    @IBAction func accountsButtonDidTouchInside(sender: AnyObject){
        if _popup == nil {
            
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            
            let accounts :AccountsChousePopUp =  storyboard.instantiateViewControllerWithIdentifier("AccountsChousePopUp") as! AccountsChousePopUp
            _popup = accounts
            accounts.view.frame = CGRect(x: tableView.frame.origin.x,
                                         y:  tableView.frame.origin.y,
                                         width: tableView.frame.width,
                                         height: tableView.frame.height)
            
            accounts.view.layer.opacity = 0
            accounts.delegate = self
            
            var wallets = _mainAccount?.cosignatoryOf ?? []
            if _mainAccount != nil
            {
                wallets.append(self._mainAccount!)
            }
            accounts.wallets = wallets
            
            if accounts.wallets.count > 0
            {
                self.sendButton?.enabled = false
                self.view.addSubview(accounts.view)
                
                UIView.animateWithDuration(0.5, animations: { () -> Void in
                    accounts.view.layer.opacity = 1
                    }, completion: nil)
            }
        } else {
            _popup!.view.removeFromSuperview()
            _popup!.removeFromParentViewController()
            _popup = nil
        }
    }
    
    @IBAction func sendButtonTouchUpInside(sender: AnyObject) {
        
        if _activeAccount == nil || State.currentServer == nil {
            return
        }
        let amount = Double(amoundField!.text!) ?? 0
        if amount < 0.000001 && amount != 0 {
            amoundField!.text = "0"
            return
        }
        
        let transaction :TransferTransaction = TransferTransaction()
        
        if let amount = Double(amoundField!.text!) {
            if Double(_activeAccount?.balance ?? -1) > amount {
                transaction.amount = amount
            } else {
                _failedWithError("ACCOUNT_NOT_ENOUGHT_MONEY".localized())
                return
            }
        } else {
            amoundField!.text = "0"
            transaction.amount = 0
            return
        }
                
        let messageTextHex = messageField!.text!.hexadecimalStringUsingEncoding(NSUTF8StringEncoding)
        
        if !Validate.hexString(messageTextHex!) {
            _failedWithError("NOT_A_HEX_STRING".localized())
            return
        }
        
        var messageBytes :[UInt8] = messageTextHex!.asByteArray()
        
        if _isEnc && messageBytes.count > 0
        {
            guard let contactPublicKey = contact.public_key else {
                _failedWithError("NO_PUBLIC_KEY_FOR_ENC".localized())

                return
            }
            var encryptedMessage :[UInt8] = Array(count: 32, repeatedValue: 0)
            encryptedMessage = MessageCrypto.encrypt(messageBytes, senderPrivateKey: HashManager.AES256Decrypt(State.currentWallet!.privateKey, key: State.loadData!.password!)!, recipientPublicKey: contactPublicKey)
            messageBytes = encryptedMessage
        }
        
        if messageBytes.count > 160 {
            _failedWithError("VALIDAATION_MESSAGE_LEANGTH".localized())
            return
        }
        
        transaction.message.payload = messageBytes
        transaction.message.type = (_isEnc && messageBytes.count > 0) ? MessageType.Ecrypted.rawValue : MessageType.Normal.rawValue
        
        var fee = 0
        
        if transaction.amount >= 8 {
            fee = Int(max(2, 99 * atan(transaction.amount / 150000)))
        }
        else {
            fee = 10 - Int(transaction.amount)
        }
        var messageLength = messageField!.text!.hexadecimalStringUsingEncoding(NSUTF8StringEncoding)?.asByteArray().count
        
        if _isEnc && messageLength != 0 {
            messageLength! += 64
        }

        if messageLength != 0 {
            fee += Int(2 * max(1, Int( messageLength! / 16)))
        }
        
        transaction.timeStamp = Double(Int(TimeSynchronizator.nemTime))
        transaction.fee = Double(fee)
        transaction.recipient = contact.address
        transaction.type = transferTransaction
        transaction.deadline = Double(Int(TimeSynchronizator.nemTime + waitTime))
        transaction.version = 1
        transaction.signer = _activeAccount?.publicKey
        
        _apiManager?.prepareAnnounce(State.currentServer!, transaction: transaction)
        
        self.view.endEditing(true)
    }
    
    final func defineData() {
        //let publicKey :String = KeyGenerator.generatePublicKey(HashManager.AES256Decrypt(State.currentWallet!.privateKey, key: State.loadData!.password!)!)
        var data :[DefinedCell] = []
        
        for transaction in _transactions {
            var definedCell : DefinedCell = DefinedCell()
            definedCell.type = .Outgoing
            
            let innertTransaction = (transaction.type == multisigTransaction) ? ((transaction as! MultisigTransaction).innerTransaction as! TransferTransaction) :
            (transaction as! TransferTransaction)
            
            if (innertTransaction.recipient == _account_address) {
                definedCell.type = .Incoming
            }
            
            innertTransaction.message.signer = contact.public_key
            var message :NSMutableAttributedString = NSMutableAttributedString(string: innertTransaction.message.getMessageString() ?? "COULD_NOT_DECRYPT".localized(), attributes: [NSFontAttributeName:UIFont(name: "HelveticaNeue-Light", size: textSizeCommon)!])
            
            if(innertTransaction.amount > 0) {
                var text :String = " \((innertTransaction.amount / 1000000).format()) XEM"
                if message != ""
                {
                    text = "\n" + text
                }
                
                let messageXEMS :NSMutableAttributedString = NSMutableAttributedString(string:text , attributes: [NSFontAttributeName:UIFont(name: "HelveticaNeue", size: textSizeXEM)! ])
                message.appendAttributedString(messageXEMS)
            }
            
            message = (message.length == 0) ? NSMutableAttributedString(string: "EMPTY_MESSAGE".localized(), attributes: [NSFontAttributeName:UIFont(name: "HelveticaNeue-Italic", size: textSizeCommon)! ]) : message
            
            definedCell.height = _heightForCell(message, width: tableView.frame.width - 120) + 20

            message = NSMutableAttributedString(string: "BLOCK".localized() + ": " , attributes: nil)
            message.appendAttributedString(NSMutableAttributedString(string:"\(innertTransaction.height.format())" , attributes: [NSFontAttributeName:UIFont(name: "HelveticaNeue", size: 10)! ]))
            definedCell.detailsTop = message
            
            message = NSMutableAttributedString(string: "FEE".localized() + ": " , attributes: nil)
            message.appendAttributedString(NSMutableAttributedString(string:"\((innertTransaction.fee / 1000000).format())" , attributes: [NSFontAttributeName:UIFont(name: "HelveticaNeue", size: 10)! ]))
            
            definedCell.detailsMiddle = message
            
            data.append(definedCell)
        }
        
        for transaction in _unconfirmedTransactions {
            var definedCell : DefinedCell = DefinedCell()
            definedCell.type = .Processing
            
            let innertTransaction = (transaction.type == multisigTransaction) ? ((transaction as! MultisigTransaction).innerTransaction as! TransferTransaction) :
                (transaction as! TransferTransaction)
            innertTransaction.message.signer = contact.public_key

            var message :NSMutableAttributedString = NSMutableAttributedString(string: innertTransaction.message.getMessageString() ?? "COULD_NOT_DECRYPT".localized() , attributes: [NSFontAttributeName:UIFont(name: "HelveticaNeue-Light", size: textSizeCommon)!])
            
            if(innertTransaction.amount != 0) {
                var text :String = "\((innertTransaction.amount / 1000000).format()) XEM"
                if message != ""
                {
                    text = "\n" + text 
                }
                
                let messageXEMS :NSMutableAttributedString = NSMutableAttributedString(string:text , attributes: [NSFontAttributeName:UIFont(name: "HelveticaNeue", size: textSizeXEM)! ])
                message.appendAttributedString(messageXEMS)
            }
            
            message = (message.length == 0) ? NSMutableAttributedString(string: "EMPTY_MESSAGE".localized(), attributes: [NSFontAttributeName:UIFont(name: "HelveticaNeue-Italic", size: textSizeCommon)! ]) : message
            
            definedCell.height =  max(_heightForCell(message, width: tableView.frame.width - 120), CGFloat(80))
            
            
            if transaction.type == multisigTransaction {
                definedCell.minCosignatories = _getMinCosigFor(transaction as! MultisigTransaction)
            }
            
            if transaction.type == multisigTransaction {
                let signerAdress = AddressGenerator.generateAddress(innertTransaction.signer)
                let singnaturesCount = (transaction as! MultisigTransaction).signatures.count + 1
                var cosignatories = 0
                var minCosig = 0

                for account in _accounts {
                    if account.address == signerAdress {
                        minCosig = account.minCosignatories!
                        cosignatories = account.cosignatories.count
                        break
                    }
                }
                let attribute = [NSForegroundColorAttributeName : greenColor]

                message = NSMutableAttributedString(string:"\(singnaturesCount)" , attributes: attribute)
                message.appendAttributedString(NSMutableAttributedString(string: " " + "OF".localized() + " ", attributes: nil))
                message.appendAttributedString(NSMutableAttributedString(string:"\(cosignatories) " , attributes: [NSFontAttributeName:UIFont(name: "HelveticaNeue", size: 10)! ]))
                message.appendAttributedString(NSMutableAttributedString(string:"SIGNERS".localized() , attributes: nil))
                
                definedCell.detailsTop = message
                
                message = NSMutableAttributedString(string:"MIN".localized() + " " , attributes: nil)
                message.appendAttributedString(NSMutableAttributedString(string:"\(((minCosig == 0) ? cosignatories : minCosig))" , attributes: [NSFontAttributeName:UIFont(name: "HelveticaNeue", size: 10)! ]))
                message.appendAttributedString(NSMutableAttributedString(string:" " + "SIGNERS".localized() , attributes: nil))
                
                definedCell.detailsMiddle = message
                
                message = NSMutableAttributedString(string: "FEE".localized() + ": " , attributes: nil)
                message.appendAttributedString(NSMutableAttributedString(string:"\((innertTransaction.fee / 1000000).format())" , attributes: [NSFontAttributeName:UIFont(name: "HelveticaNeue", size: 10)! ]))
                
                definedCell.detailsBottom = message
            } else {
                message = NSMutableAttributedString(string: "FEE".localized() + ": " , attributes: nil)
                message.appendAttributedString(NSMutableAttributedString(string:"\((innertTransaction.fee / 1000000).format())" , attributes: [NSFontAttributeName:UIFont(name: "HelveticaNeue", size: 10)! ]))
                
                definedCell.detailsMiddle = message
            }

            data.append(definedCell)
        }
        
        var removeCount = 0
        var addCount = _transactions.count - _completed
        
        if self.tableView.numberOfRowsInSection(0) == 0 && (addCount > 0 || _unconfirmedTransactions.count > 0){
            addCount += 1
        }
        
        removeCount = (_unconfirmed > 0) ? _unconfirmed + 1 : 0
        addCount += (_unconfirmedTransactions.count > 0) ? _unconfirmedTransactions.count + 1 : 0

        _completed = _transactions.count
        _unconfirmed = _unconfirmedTransactions.count
        _definedCells = data
        
        dispatch_async(dispatch_get_main_queue() , {
            () -> Void in
                        
            var actionArray :[NSIndexPath] = []
            var rowsCount = self.tableView.numberOfRowsInSection(0)
            
            for var i = self.tableView.numberOfRowsInSection(0) - removeCount ; 0 < removeCount && addCount > 0 ;i += 1 {
                print("update \(i)")
                actionArray.append(NSIndexPath(forRow: i, inSection: 0))
                removeCount -= 1
                addCount -= 1
            }
            
            self.tableView.beginUpdates()
            
            if actionArray.count > 0 {
                self.tableView.reloadRowsAtIndexPaths(actionArray, withRowAnimation: UITableViewRowAnimation.None)
            }
            
            actionArray = []
            
            for var i = 0 ; i < removeCount && (rowsCount - 1 - i > 0) ;i += 1 {
                print("delete \(rowsCount - 1 - i)")
                actionArray.append(NSIndexPath(forRow: rowsCount - 1 - i, inSection: 0))
            }
            if actionArray.count > 0 {
                self.tableView.deleteRowsAtIndexPaths(actionArray, withRowAnimation: UITableViewRowAnimation.Left)
            }
            
            actionArray = []
            rowsCount = self.tableView.numberOfRowsInSection(0)
            
            for var i = 0 ; i < addCount ;i += 1 {
                actionArray.append(NSIndexPath(forRow: rowsCount + i, inSection: 0))
            }
            if actionArray.count > 0 {
                self.tableView.insertRowsAtIndexPaths(actionArray, withRowAnimation: UITableViewRowAnimation.Fade)
            }
            
            self.tableView.endUpdates()

            //self.tableView.reloadData()
            //self.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: UITableViewRowAnimation.None)
            self.scrollToEnd()
        })
    }
    
    func scrollToEnd() {
        var indexPath :NSIndexPath!
        
        if (tableView.numberOfRowsInSection(0) != 0) {
            indexPath = NSIndexPath(forRow: tableView.numberOfRowsInSection(0) - 1 , inSection: 0)
        }
        
        if indexPath != nil {
            tableView.scrollToRowAtIndexPath(indexPath, atScrollPosition: UITableViewScrollPosition.Bottom, animated: true)
        }
    }
    
    // MARK: - TableView Delegate
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if _definedCells.count > 0 {
            var count = _transactions.count + 1
            count += (_unconfirmedTransactions.count > 0) ? _unconfirmedTransactions.count + 1 : 0
            return count
        }
        
        return 0
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        if( indexPath.row != 0 ) {
            var index :Int = 0
            let cell : ConversationTableViewCell = self.tableView.dequeueReusableCellWithIdentifier("messageCell") as! ConversationTableViewCell
            
            cell.detailDelegate = self
            cell.detailsIsShown = false
            
            var transaction :TransactionPostMetaData!
            var innertTransaction :TransferTransaction!
            
            if indexPath.row <= _transactions.count {
                index = indexPath.row - 1
                cell.cellType = _definedCells[indexPath.row - 1].type
                cell.setDetails(_definedCells[indexPath.row - 1].detailsTop, middle: _definedCells[indexPath.row - 1].detailsMiddle, bottom: _definedCells[indexPath.row - 1].detailsBottom)
                transaction = _transactions[index]
                innertTransaction = (transaction.type == multisigTransaction) ? ((transaction as! MultisigTransaction).innerTransaction as! TransferTransaction) :
                    (transaction as! TransferTransaction)
            } else {
                
                index = indexPath.row - _transactions.count - 2
                
                if index < 0 {
                    let headerCell :UITableViewCell  = self.tableView.dequeueReusableCellWithIdentifier("groupHeader")!
                    return headerCell
                }
                cell.cellType = _definedCells[indexPath.row - 2].type
                cell.setDetails(_definedCells[indexPath.row - 2].detailsTop, middle: _definedCells[indexPath.row - 2].detailsMiddle, bottom: _definedCells[indexPath.row - 2].detailsBottom)
                if _unconfirmedTransactions.count <= index {
                    self.tableView.reloadData()
                    return cell
                }
                transaction  = _unconfirmedTransactions[index]
                innertTransaction = (transaction.type == multisigTransaction) ? ((transaction as! MultisigTransaction).innerTransaction as! TransferTransaction) :
                    (transaction as! TransferTransaction)
            }
            innertTransaction.message.signer = contact.public_key
            let messageText = innertTransaction.message.getMessageString() ?? "COULD_NOT_DECRYPT".localized()
            
            var message :NSMutableAttributedString = NSMutableAttributedString(string: messageText , attributes: [NSFontAttributeName:UIFont(name: "HelveticaNeue-Light", size: textSizeCommon)!])
            
            if (innertTransaction.amount > 0) {
                var text :String = ((cell.cellType == .Incoming) ? "+" : "-") + "\((innertTransaction.amount / 1000000).format()) XEM"
                
                if messageText != ""
                {
                    text = "\n" + text
                }
                
                let messageXEMS :NSMutableAttributedString = NSMutableAttributedString(string:text , attributes: [NSFontAttributeName:UIFont(name: "HelveticaNeue", size: textSizeXEM)! ])
                message.appendAttributedString(messageXEMS)
            }
            
            message = (message.length == 0) ? NSMutableAttributedString(string: "EMPTY_MESSAGE".localized(), attributes: [NSFontAttributeName:UIFont(name: "HelveticaNeue-Italic", size: textSizeCommon)! ]) : message
            cell.setMessage(message)
            let dateFormatter = NSDateFormatter()
            dateFormatter.dateFormat = "HH:mm dd.MM.yy "
            
            let timeStamp = Double(innertTransaction.timeStamp)
            
            cell.setDate(dateFormatter.stringFromDate(NSDate(timeIntervalSince1970: genesis_block_time + timeStamp)))
            
            if(indexPath.row == _transactions.count ) {
                scrollToEnd()
            }
            return cell
        }
        
        let cell :UITableViewCell  = self.tableView.dequeueReusableCellWithIdentifier("simpl")!
        return cell
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if indexPath.row == 0 {
            var height :CGFloat = 0
            
            for cell in _definedCells {
                height += cell.height
            }
            
            if height >= self.tableView.bounds.height {
                return 1
            }
            else {
                return self.tableView.bounds.height - height
            }
        } else if indexPath.row <= _transactions.count + 1  {
            
            return _definedCells[indexPath.row - 1].height
        } else if indexPath.row == _transactions.count + 1 {
            return 44
        } else {
            return _definedCells[indexPath.row - 2].height
        }
    }
    
    //MARK: - DetailedTableViewCellDelegate Methods
    
    func showDetailsForCell(cell: DetailedTableViewCell) {
        cell.detailsIsShown = true
    }
    
    func hideDetailsForCell(cell: DetailedTableViewCell) {
        cell.detailsIsShown = false
    }
    
    // MARK: - APIManagerDelegate Methods
    
    final func accountGetResponceWithAccount(account: AccountGetMetaData?) {
        dispatch_async(_operationDipatchQueue, {
            () -> Void in
            if let responceAccount = account {
                let privateKey = HashManager.AES256Decrypt(State.currentWallet!.privateKey, key: State.loadData!.password!)
                
                if responceAccount.address == self.contact.address && !Validate.stringNotEmpty(self.contact.public_key){
                    self.contact.public_key = responceAccount.publicKey
                }
                
                if responceAccount.address == self._account_address! {
                    if responceAccount.publicKey == nil {
                        responceAccount.publicKey = KeyGenerator.generatePublicKey(privateKey!)
                    }

                    self._activeAccount = responceAccount
                    
                    if self._mainAccount == nil {
                        self._mainAccount = responceAccount
                        self.refreshHistory()
                    } else {
                        self._mainAccount = responceAccount
                    }
                    
                    for multisigAccount in responceAccount.cosignatoryOf {
                        self._apiManager?.accountGet(State.currentServer!, account_address: multisigAccount.address)
                    }
                    
                    dispatch_async(dispatch_get_main_queue() , {
                        () -> Void in
                        var userDescription :NSMutableAttributedString!
                        userDescription = NSMutableAttributedString(string: "\(State.currentWallet!.login)")
                        
                        let attribute = [NSForegroundColorAttributeName : UIColor(red: 65/256, green: 206/256, blue: 123/256, alpha: 1)]
                        let balance = " \(self._activeAccount!.balance / 1000000) XEM"
                        
                        userDescription.appendAttributedString(NSMutableAttributedString(string: balance, attributes: attribute))
                        
                        self.userInfo.attributedText = userDescription
                    })
                    
                }
                
                var exist = false
                
                for value in self._accounts {
                    if value.address == responceAccount.address {
                        exist = true
                        break
                    }
                }
                
                if !exist {
                    self._accounts.append(responceAccount)
                }
            } else {
                dispatch_async(dispatch_get_main_queue() , {
                    () -> Void in
                    self.userInfo.attributedText = NSMutableAttributedString(string: "LOST_CONNECTION".localized(), attributes: [NSForegroundColorAttributeName : UIColor.redColor()])
                })
            }
        })
    }
    
    final func accountTransfersAllResponceWithTransactions(data: [TransactionPostMetaData]?) {
        dispatch_async(_operationDipatchQueue, {
            () -> Void in
            if let data = data {
                self._transactions = self._findMessages(data.reverse()) + self._transactions
                if data.count >= 25 && self._requestCounter < self._requestsLimit && self._transactions.count <= self._transactionsLimit{
                    self._requestCounter += 1
                    self._apiManager?.accountTransfersAll(State.currentServer!, account_address: self._account_address!, aditional: "&id=\(Int(data.last!.id))")
                } else {
                    //self._sortMessages()
                    self._apiManager?.unconfirmedTransactions(State.currentServer!, account_address: self._mainAccount!.address)
                }
            } else {
                dispatch_async(dispatch_get_main_queue() , {
                    () -> Void in
                    self.userInfo.attributedText = NSMutableAttributedString(string: "LOST_CONNECTION".localized(), attributes: [NSForegroundColorAttributeName : UIColor.redColor()])
                })
            }
        })
    }
    
    final func unconfirmedTransactionsResponceWithTransactions(data: [TransactionPostMetaData]?) {
        dispatch_async(_operationDipatchQueue, {
            () -> Void in
            
            if let data = data {
                self._unconfirmedTransactions = self._findMessages(data).reverse()
                self.defineData()
            } else {
                dispatch_async(dispatch_get_main_queue() , {
                    () -> Void in
                    self.userInfo.attributedText = NSMutableAttributedString(string: "LOST_CONNECTION".localized(), attributes: [NSForegroundColorAttributeName : UIColor.redColor()])
                })
            }
        })
    }
    
    func prepareAnnounceResponceWithTransactions(data: [TransactionPostMetaData]?) {
        self.refreshHistory()
        if !(data ?? []).isEmpty {
            messageField!.text = ""
            amoundField!.text = ""
            let alert :UIAlertController = UIAlertController(title: "INFO".localized(), message: "TRANSACTION_ANOUNCE_SUCCESS".localized(), preferredStyle: UIAlertControllerStyle.Alert)
            
            let ok :UIAlertAction = UIAlertAction(title: "OK".localized(), style: UIAlertActionStyle.Default) {
                alertAction -> Void in
            }
            
            alert.addAction(ok)
            self.presentViewController(alert, animated: true, completion: nil)
            
        } else {
            let alert :UIAlertController = UIAlertController(title: "INFO".localized(), message: "TRANSACTION_ANOUNCE_FAILED".localized(), preferredStyle: UIAlertControllerStyle.Alert)
            
            let ok :UIAlertAction = UIAlertAction(title: "OK".localized(), style: UIAlertActionStyle.Default) {
                alertAction -> Void in
            }
            
            alert.addAction(ok)
            self.presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    //MARK: - AccountsChousePopUpDelegate Methods
    
    func didChouseAccount(account: AccountGetMetaData) {
        _activeAccount = account
        _popup?.view.removeFromSuperview()
        _popup?.removeFromParentViewController()
        _popup = nil
        
        self.sendButton?.enabled = true
        
        self.encButton?.enabled = _activeAccount?.address == _account_address
        
        if _activeAccount?.address != _account_address {
            _isEnc = false
            self.encButton.backgroundColor = grayColor
        }
        
        let userDescription :NSMutableAttributedString = NSMutableAttributedString(string: "\(_activeAccount!.address.nemName())")
        
        let attribute = [NSForegroundColorAttributeName : UIColor(red: 65/256, green: 206/256, blue: 123/256, alpha: 1)]
        let balance = " \(self._activeAccount!.balance / 1000000) XEM"
        
        userDescription.appendAttributedString(NSMutableAttributedString(string: balance, attributes: attribute))
        
        dispatch_async(dispatch_get_main_queue() , {
            () -> Void in
            self.userInfo.attributedText = userDescription
        })
    }
    
    //MARK: - Public Helpers
    
    final func refreshHistory() {
        _requestCounter = 0
        _transactions = []
        
        self._apiManager?.accountTransfersAll(State.currentServer!, account_address: self._mainAccount!.address)
    }
    
    //MARK: - Private Helpers
    
    private func _heightForCell(message: NSMutableAttributedString, width: CGFloat)-> CGFloat {
        let label:UILabel = UILabel(frame: CGRectMake(0, 0, width, CGFloat.max))
        label.numberOfLines = 10
        label.lineBreakMode = NSLineBreakMode.ByWordWrapping
        label.attributedText = message
        
        label.sizeToFit()
        return label.frame.height + 10
    }
    
    private func _initButtonsConfigs() {
        if accountsButton != nil {
            accountsButton!.layer.cornerRadius = 5
        }
        
        if sendButton != nil {
            sendButton!.layer.cornerRadius = 5
        }
        
        if amoundContainerView != nil {
            amoundContainerView.layer.cornerRadius = 5
            amoundContainerView.clipsToBounds = true
        }
        
        if messageField != nil {
            messageField!.layer.cornerRadius = 5
        }
    }
    
    private func _findMessages(data: [TransactionPostMetaData]) -> [TransactionPostMetaData] {
        var transactions :[TransactionPostMetaData] = data
        let privateKey = HashManager.AES256Decrypt(State.currentWallet!.privateKey, key: State.loadData!.password!)
        let publicKey = KeyGenerator.generatePublicKey(privateKey!)
        
        for var index = 0; index < transactions.count; index++ {
            var transaction :TransferTransaction?
            
            switch transactions[index].type {
            case multisigTransaction :
                let innerTransaction = ((transactions[index] as! MultisigTransaction).innerTransaction as TransactionPostMetaData)
                switch innerTransaction.type {
                case transferTransaction:
                    transaction = innerTransaction as? TransferTransaction
                default:
                    break
                }
            case transferTransaction:
                transaction = transactions[index] as? TransferTransaction
                
            default :
                break
            }
            
            if transaction == nil {
                
                transactions.removeAtIndex(index)
                index--
                continue
            }
            
            var needToSave = false
            
            if transaction!.recipient == _account_address && AddressGenerator.generateAddress(transaction!.signer) == self.contact.address {
                needToSave = true
            } else if transaction!.recipient == self.contact.address && transaction!.signer == publicKey  {
                needToSave = true
            } else if AddressGenerator.generateAddress(transaction!.signer) == _account_address && transaction!.recipient == _account_address && _account_address == self.contact.address {
                needToSave = true
            }
            
            if !needToSave {
                transactions.removeAtIndex(index)
                index--

            }
        }
        
        return transactions
    }
    
    private final func _getMinCosigFor(transaction: MultisigTransaction) -> Int? {
        let innertTransaction =  (transaction.innerTransaction as! TransferTransaction)
        let transactionsignerAddress = AddressGenerator.generateAddress(innertTransaction.signer)
        
        for account in _accounts {
            if account.address == transactionsignerAddress {
                return account.minCosignatories
            }
        }
        
        return nil
    }
    
    func _sortMessages() {
        var accum :TransactionPostMetaData!
        for(var index = 0; index < _transactions.count; index += 1) {
            var sorted = true
            
            for(var index = 0; index < _transactions.count - 1; index += 1) {
                
                let valueA :Double = Double(_transactions[index].id)
                
                let valueB :Double = Double(_transactions[index + 1].id)
                
                if valueA > valueB {
                    sorted = false
                    accum = _transactions[index]
                    _transactions[index] = _transactions[index + 1]
                    _transactions[index + 1] = accum
                }
            }
            
            if sorted {
                break
            }
        }
    }
    
    private func _failedWithError(text: String, completion :(Void -> Void)? = nil) {
        let alert :UIAlertController = UIAlertController(title: "INFO".localized(), message: text, preferredStyle: UIAlertControllerStyle.Alert)
        
        alert.addAction(UIAlertAction(title: "OK".localized(), style: UIAlertActionStyle.Default, handler: { (action) -> Void in
            alert.dismissViewControllerAnimated(true, completion: nil)
            completion?()
        }))
        
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    //MARK: - Keyboard Methods
    
    func keyboardWillShow(notification: NSNotification) {
        
        let info:NSDictionary = notification.userInfo!
        let keyboardSize = (info[UIKeyboardFrameEndUserInfoKey] as! NSValue).CGRectValue()
        
        let height:CGFloat = keyboardSize.height - 62
        let delta = height - self._bottomInsert
        self._bottomInsert = height
        
        UIView.animateWithDuration(0.25, animations: { () -> Void in
            self.view.frame.size.height = self.view.frame.height - delta
            }, completion: { (success) -> Void in
                self.scrollToEnd()
        })
    }
    
    func keyboardWillHide(notification: NSNotification) {

        let delta = self._bottomInsert

        self._bottomInsert = 0
        
        UIView.animateWithDuration(0.25, animations: { () -> Void in
            self.view.frame.size.height = self.view.frame.height + delta
            }, completion: { (success) -> Void in
                if !success {
                    self.view.frame.size.height = self.view.frame.height + delta
                }
                self.scrollToEnd()
        })
    }
}
