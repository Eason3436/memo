import UIKit

extension UIMenu {
    /// 「分類」子選單：Apple Intelligence 自動分類 + 手動選擇
    static func category(current: String?,
                         onAutoClassify: @escaping () -> Void,
                         onSelect: @escaping (String?) -> Void) -> UIMenu {
        let auto = UIAction(title: "用 Apple Intelligence 分類",
                            image: UIImage(systemName: "apple.intelligence")) { _ in onAutoClassify() }
        let choices = NoteCategory.all.map { category in
            UIAction(title: category, image: UIImage(systemName: NoteCategory.icon(for: category)),
                     state: current == category ? .on : .off) { _ in onSelect(category) }
        }
        let none = UIAction(title: "無分類", state: current == nil ? .on : .off) { _ in onSelect(nil) }
        ([auto] + choices + [none]).forEach { $0.preferredImageVisibility = .visible }
        return UIMenu(title: "分類", subtitle: current, image: UIImage(systemName: "tag"), children: [
            auto,
            UIMenu(options: .displayInline, children: choices + [none])
        ])
    }
}
