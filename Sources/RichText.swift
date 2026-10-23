import UIKit

/// 把含格式與繪圖的文字轉成 Data 存檔，或從 Data 讀回來
enum RichText {
    static func archive(_ text: NSAttributedString) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: text, requiringSecureCoding: false)
    }

    static func unarchive(_ data: Data) -> NSAttributedString? {
        guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        // 檔案只由本 App 寫入，內含自訂的繪圖附件類別
        unarchiver.requiresSecureCoding = false
        defer { unarchiver.finishDecoding() }
        return unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? NSAttributedString
    }
}
