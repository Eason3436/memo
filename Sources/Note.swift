import Foundation
import CoreLocation

/// 備忘錄附加的地點
struct NoteLocation: Codable, Equatable {
    var name: String
    var address: String?
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// 固定的分類清單（Apple Intelligence 只能從這裡面選）
enum NoteCategory {
    static let all = ["工作", "生活", "學習", "購物", "旅遊", "想法", "待辦", "其他"]

    static func icon(for category: String) -> String {
        switch category {
        case "工作": return "briefcase"
        case "生活": return "house"
        case "學習": return "book"
        case "購物": return "cart"
        case "旅遊": return "airplane"
        case "想法": return "lightbulb"
        case "待辦": return "checklist"
        default: return "tag"
        }
    }
}

struct Note: Codable, Identifiable, Equatable {
    let id: UUID
    /// 純文字內容（標題、預覽、搜尋、AI 分類用）
    var text: String
    /// 含格式與繪圖的內容（封存的 NSAttributedString）
    var richText: Data?
    var location: NoteLocation?
    var category: String?
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool

    init(text: String = "") {
        self.id = UUID()
        self.text = text
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isPinned = false
    }

    /// 去掉繪圖佔位字元後的文字
    var plainText: String {
        text.replacingOccurrences(of: "\u{FFFC}", with: "")
    }

    /// 去掉空白行後的每一行文字
    private var lines: [String] {
        plainText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// 第一行當標題
    var title: String { lines.first ?? (text.contains("\u{FFFC}") ? "手繪" : "新備忘錄") }

    /// 第二行當預覽
    var preview: String { lines.dropFirst().first ?? "沒有其他文字" }
}
