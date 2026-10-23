import Foundation
import FoundationModels

/// 模型輸出的格式：只能從固定分類裡選一個
@Generable
struct NoteClassification {
    @Guide(description: "最適合這則備忘錄的分類", .anyOf(NoteCategory.all))
    var category: String
}

/// 用裝置上的 Apple Intelligence 模型（Foundation Models）幫備忘錄分類
enum NoteClassifier {

    struct Unavailable: LocalizedError {
        let errorDescription: String?
    }

    /// 目前不能用 Apple Intelligence 的原因；可以用時為 nil
    static var unavailableReason: String? {
        guard case .unavailable(let reason) = SystemLanguageModel.default.availability else { return nil }
        switch reason {
        case .deviceNotEligible:
            return "這台裝置不支援 Apple Intelligence。"
        case .appleIntelligenceNotEnabled:
            return "請先到「設定」>「Apple Intelligence 與 Siri」開啟 Apple Intelligence。"
        case .modelNotReady:
            return "Apple Intelligence 模型還在下載，請稍後再試。"
        @unknown default:
            return "目前無法使用 Apple Intelligence。"
        }
    }

    static func classify(_ text: String) async throws -> String {
        if let reason = unavailableReason { throw Unavailable(errorDescription: reason) }
        // 每則備忘錄用新的 session，避免前一則的內容影響判斷
        let session = LanguageModelSession(instructions: """
            你是備忘錄分類助手。閱讀使用者的備忘錄，從指定的分類中選出最適合的一個。
            """)
        let response = try await session.respond(to: "備忘錄內容：\n\(text.prefix(2000))",
                                                 generating: NoteClassification.self)
        return response.content.category
    }
}
