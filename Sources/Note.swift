import Foundation

struct Note: Codable, Identifiable, Equatable {
    let id: UUID
    var text: String
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

    /// 去掉空白行後的每一行文字
    private var lines: [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// 第一行當標題
    var title: String { lines.first ?? "新備忘錄" }

    /// 第二行當預覽
    var preview: String { lines.dropFirst().first ?? "沒有其他文字" }
}
