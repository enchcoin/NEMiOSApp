import Foundation

extension NSData {
    public func toHexString () -> String {
        let sha256description = self.description as String
        
        // TODO: more elegant way to convert NSData to a hex string
        
        var result: String = ""

        for char in sha256description.characters {
            switch char {
            case "0", "1", "2", "3", "4", "5", "6", "7","8","9", "a", "b", "c", "d", "e", "f":
                result.append(char)
            default:
                result += String("")
            }
        }
        
        return result
    }

    public class func fromHexString (string: String) -> NSData {
        // Based on: http://stackoverflow.com/a/2505561/313633
        let data = NSMutableData()
            
        var temp = ""
        
        for char in string.characters {
            temp+=String(char)
            if(temp.characters.count == 2) {
                let scanner = NSScanner(string: temp)
                var value: CUnsignedInt = 0
                scanner.scanHexInt(&value)
                data.appendBytes(&value, length: 1)
                temp = ""
            }
            
        }
        
        return data as NSData
    }
}