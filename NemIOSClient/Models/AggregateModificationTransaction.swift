import UIKit

class AggregateModificationTransaction: TransactionPostMetaData
{
    var modifications :[AccountModification] = [AccountModification]()
    var minCosignatory :Int!
    
    override init() {
        super.init()
        minCosignatory = 0
        type = multisigAggregateModificationTransaction
    }
    
    final func addModification(type :Int , publicKey :String) {
        if publicKey.utf16.count != 64 {
            print("ERROR. Modification receive public key with wrong length (length : \(publicKey.utf16.count / 2) bytes)")
        }
        
        var modification :AccountModification = AccountModification()
        modification.publicKey = publicKey
        modification.modificationType = type
        
        self.modifications.append(modification)
    }
    
    final override func getFrom(dictionary: NSDictionary) {
        self.timeStamp = dictionary.objectForKey("timeStamp") as! Double
        self.deadline = dictionary.objectForKey("deadline") as! Double
        self.version = dictionary.objectForKey("version") as! Double
        self.signer = dictionary.objectForKey("signer") as! String
        
        if dictionary.objectForKey("signature") != nil {
            self.signature = dictionary.objectForKey("signature") as! String
        }

        for modification in dictionary.objectForKey("modifications") as! [NSDictionary] {
        self.addModification(modification.objectForKey("modificationType") as! Int, publicKey: modification.objectForKey("cosignatoryAccount") as! String)
        }
        
        self.fee = dictionary.objectForKey("fee") as! Double
    }
}
