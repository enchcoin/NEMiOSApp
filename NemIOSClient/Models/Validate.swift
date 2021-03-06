import UIKit

class Validate: NSObject
{
    
    final class func account(privateKey privateKey :String) -> String? {
        let accounts = CoreDataManager().getWallets()
        
        for account in accounts {
            let privKey =  HashManager.AES256Decrypt(account.privateKey, key: State.loadData!.password!)
            if privKey == privateKey {
                return account.login
            }
        }
        
        return nil
    }
    
    final class func address(inputText :String? ,length: Int = 40) -> Bool {
        if inputText == nil {
            return false
        }
        
        if inputText!.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) != 40 {
            return false
        }
        
        let expresion = "^(?:[A-Z2-7]{8})*(?:[A-Z2-7]{2}={6}|[A-Z2-7]{4}={4}|[A-Z2-7]{5}={3}|[A-Z2-7]{7}=)?$"
        
        let range = inputText!.rangeOfString(expresion, options:.RegularExpressionSearch)

        let result = range != nil ? true : false
        return result

    }
    
    final class func key(inputText :String? ,length: Int = 64) -> Bool {
        if inputText == nil {
            return false
        }
        
        let validator :Array<UInt8> = Array<UInt8>("0123456789abcdef".utf8)
        var keyArray :Array<UInt8> = Array<UInt8>(inputText!.utf8)
        
        if keyArray.count == length || keyArray.count == length + 2 {
            if keyArray.count == length + 2 {
                keyArray.removeAtIndex(0)
                keyArray.removeAtIndex(0)
            }
            
            for value in keyArray {
                var find = false
                
                for valueChecker in validator {
                    if value == valueChecker
                    {
                        find = true
                        break
                    }
                }
                
                if !find {
                    return false
                }
            }
        }
        else {
            return false
        }
        
        return true
    }
    
    final class func password(inputText :String) -> Bool {
        let keyArray :Array<UInt8> = Array<UInt8>(inputText.utf8)
        
        if keyArray.count < 6 {
            return false
        }
                
        return true
    }
    
    final class func stringNotEmpty(inputText :String?) -> Bool {
        if inputText == nil {
            return false
        }
        
        if inputText == "" {
            return false
        }
        
        let regEx = "^ *$"
        let range = inputText!.rangeOfString(regEx, options:.RegularExpressionSearch)
        let result = range == nil ? true : false
        
        return result
    }
    
    final class func hexString(text : String) -> Bool {
        let regex: NSRegularExpression?
        do {
            regex = try NSRegularExpression(pattern: "^[0-9a-f]*$", options: .CaseInsensitive)
        } catch {
            regex = nil
        }
        
        let found = regex?.firstMatchInString(text, options: [], range: NSMakeRange(0, text.characters.count))
        
        if found == nil || found?.range.location == NSNotFound || text.characters.count % 2 != 0 {
            return false
        }
        
        return true
    }
}
