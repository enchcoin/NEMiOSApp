import UIKit

extension UInt8
{
    init?(_ string: String, radix: UInt8) {
        let digits = "0123456789abcdefghijklmnopqrstuvwxyz"
        var result = UInt8(0)
        for digit in string.lowercaseString.characters {
            if let range = digits.rangeOfString(String(digit)) {
                let val = UInt8(digits.startIndex.distanceTo(range.startIndex))
                if val >= radix {
                    return nil
                }
                result = result * radix + val
            }
            else {
                return nil
            }
        }
        self = result
    }
    
    func asHex()->String {
        let string :String = NSString(format: "%02x", self) as String
        
        return string
    }
}