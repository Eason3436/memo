import UIKit
import PencilKit

/// 編輯畫面：文字格式、手繪、地點、分類；輸入時自動儲存，離開時若內容為空就刪除
final class NoteEditorViewController: UIViewController {

    private let noteID: UUID
    private let store = NoteStore.shared
    private let textView = UITextView()
    private let locationItem = UIBarButtonItem()
    private var isClassifying = false

    private static let bodyFont = UIFont.preferredFont(forTextStyle: .body)

    init(noteID: UUID) {
        self.noteID = noteID
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.largeTitleDisplayMode = .never

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.adjustsFontForContentSizeCategory = true
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.allowsEditingTextAttributes = true
        textView.grammarCheckingType = .yes
        textView.inputAccessoryView = makeFormatBar()
        textView.delegate = self
        loadContent()
        view.addSubview(textView)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // 跟著鍵盤高度調整，避免文字被鍵盤擋住
            textView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
        ])

        let share = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"),
                                    style: .plain, target: self, action: #selector(shareNote))
        let more = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: makeMoreMenu())
        // 空間不夠時，「更多」先收起，分享按鈕保留
        share.visibilityPriority = .high
        more.visibilityPriority = .low
        navigationItem.rightBarButtonItems = [more, share]

        // 底部工具列：地點、繪圖
        let drawItem = UIBarButtonItem(primaryAction: UIAction(title: "繪圖",
                                                               image: UIImage(systemName: "pencil.tip.crop.circle")) { [weak self] _ in
            self?.openDrawing(nil, replacing: nil)
        })
        toolbarItems = [locationItem, .flexibleSpace(), drawItem]
        updateLocationItem()
        updateTitle()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 新的空白備忘錄直接跳出鍵盤
        if textView.text.isEmpty { textView.becomeFirstResponder() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent { store.removeIfEmpty(id: noteID) }
    }

    // MARK: - 讀取與儲存

    private var defaultAttributes: [NSAttributedString.Key: Any] {
        [.font: Self.bodyFont, .foregroundColor: UIColor.label]
    }

    private func loadContent() {
        let note = store.note(id: noteID)
        let content: NSMutableAttributedString
        if let data = note?.richText, let saved = RichText.unarchive(data) {
            content = NSMutableAttributedString(attributedString: saved)
        } else {
            content = NSMutableAttributedString(string: note?.text ?? "", attributes: defaultAttributes)
        }
        // 文字顏色一律跟著淺色／深色模式
        content.addAttribute(.foregroundColor, value: UIColor.label,
                             range: NSRange(location: 0, length: content.length))
        textView.attributedText = content
        textView.typingAttributes = defaultAttributes
    }

    private func saveContent() {
        guard var note = store.note(id: noteID) else { return }
        note.text = textView.text
        note.richText = RichText.archive(textView.attributedText)
        store.update(note)
        updateTitle()
    }

    private func updateTitle() {
        let count = textView.text.filter { $0 != "\u{FFFC}" }.count
        navigationItem.title = count == 0 ? "" : "\(count) 字"
        updateSubtitle()
    }

    /// 標題下方顯示分類與地點
    private func updateSubtitle() {
        if isClassifying {
            navigationItem.subtitle = "Apple Intelligence 分類中…"
            return
        }
        let note = store.note(id: noteID)
        let parts = [note?.category, note?.location?.name].compactMap { $0 }
        navigationItem.subtitle = parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - 文字格式

    /// 鍵盤上方的格式工具列
    private func makeFormatBar() -> UIToolbar {
        let bar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        func button(_ symbol: String, _ handler: @escaping () -> Void) -> UIBarButtonItem {
            UIBarButtonItem(image: UIImage(systemName: symbol), primaryAction: UIAction { _ in handler() })
        }
        let styles = UIMenu(title: "段落樣式", children: [
            UIAction(title: "標題") { [weak self] _ in self?.applyParagraphStyle(.title1, weight: .bold) },
            UIAction(title: "副標題") { [weak self] _ in self?.applyParagraphStyle(.title3, weight: .semibold) },
            UIAction(title: "內文") { [weak self] _ in self?.applyParagraphStyle(.body, weight: .regular) }
        ])
        bar.items = [
            UIBarButtonItem(image: UIImage(systemName: "textformat"), menu: styles),
            button("bold") { [weak self] in self?.toggleTrait(.traitBold) },
            button("italic") { [weak self] in self?.toggleTrait(.traitItalic) },
            button("underline") { [weak self] in self?.toggleLine(.underlineStyle) },
            button("strikethrough") { [weak self] in self?.toggleLine(.strikethroughStyle) },
            button("textformat.size.smaller") { [weak self] in self?.adjustFontSize(by: -2) },
            button("textformat.size.larger") { [weak self] in self?.adjustFontSize(by: 2) },
            .flexibleSpace(),
            button("keyboard.chevron.compact.down") { [weak self] in self?.textView.resignFirstResponder() }
        ]
        bar.sizeToFit()
        return bar
    }

    /// 選取範圍開頭的格式；沒有選取時用接下來要輸入的格式
    private var attributesAtSelection: [NSAttributedString.Key: Any] {
        let range = textView.selectedRange
        guard range.length > 0 else { return textView.typingAttributes }
        return textView.textStorage.attributes(at: range.location, effectiveRange: nil)
    }

    /// 改選取範圍內每一段的字型；沒有選取時改接下來要輸入的字型
    private func modifyFonts(_ transform: (UIFont) -> UIFont) {
        let range = textView.selectedRange
        guard range.length > 0 else {
            let font = textView.typingAttributes[.font] as? UIFont ?? Self.bodyFont
            textView.typingAttributes[.font] = transform(font)
            return
        }
        let storage = textView.textStorage
        storage.beginEditing()
        storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
            storage.addAttribute(.font, value: transform(value as? UIFont ?? Self.bodyFont), range: subrange)
        }
        storage.endEditing()
        saveContent()
    }

    private func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
        let font = attributesAtSelection[.font] as? UIFont ?? Self.bodyFont
        let enable = !font.fontDescriptor.symbolicTraits.contains(trait)
        modifyFonts { font in
            var traits = font.fontDescriptor.symbolicTraits
            if enable { traits.insert(trait) } else { traits.remove(trait) }
            guard let descriptor = font.fontDescriptor.withSymbolicTraits(traits) else { return font }
            return UIFont(descriptor: descriptor, size: font.pointSize)
        }
    }

    private func adjustFontSize(by delta: CGFloat) {
        modifyFonts { $0.withSize(min(max($0.pointSize + delta, 10), 48)) }
    }

    /// 底線、刪除線開關
    private func toggleLine(_ key: NSAttributedString.Key) {
        let enable = (attributesAtSelection[key] as? Int ?? 0) == 0
        let range = textView.selectedRange
        guard range.length > 0 else {
            textView.typingAttributes[key] = enable ? NSUnderlineStyle.single.rawValue : nil
            return
        }
        if enable {
            textView.textStorage.addAttribute(key, value: NSUnderlineStyle.single.rawValue, range: range)
        } else {
            textView.textStorage.removeAttribute(key, range: range)
        }
        saveContent()
    }

    /// 把游標所在段落設成標題／副標題／內文
    private func applyParagraphStyle(_ style: UIFont.TextStyle, weight: UIFont.Weight) {
        let font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: style).pointSize, weight: weight)
        let range = (textView.text as NSString).paragraphRange(for: textView.selectedRange)
        if range.length > 0 {
            textView.textStorage.addAttribute(.font, value: font, range: range)
            saveContent()
        }
        textView.typingAttributes[.font] = font
    }

    // MARK: - 繪圖

    /// 開啟繪圖畫面；replacing 有值時是編輯既有的圖
    private func openDrawing(_ attachment: DrawingAttachment?, replacing range: NSRange?) {
        let drawingVC = DrawingViewController(drawing: attachment?.drawing ?? PKDrawing())
        drawingVC.onDone = { [weak self] drawing, width in
            self?.insertDrawing(drawing, canvasWidth: width, replacing: range)
        }
        let nav = UINavigationController(rootViewController: drawingVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    private func insertDrawing(_ drawing: PKDrawing, canvasWidth: CGFloat, replacing range: NSRange?) {
        let storage = textView.textStorage
        let image = NSAttributedString(attachment: DrawingAttachment(drawing: drawing, canvasWidth: canvasWidth))
        if let range {
            // 畫布清空就等於刪掉這張圖
            storage.replaceCharacters(in: range, with: drawing.strokes.isEmpty ? NSAttributedString() : image)
        } else if !drawing.strokes.isEmpty {
            let insertion = NSMutableAttributedString(attributedString: image)
            insertion.append(NSAttributedString(string: "\n", attributes: defaultAttributes))
            let at = textView.selectedRange
            storage.replaceCharacters(in: at, with: insertion)
            textView.selectedRange = NSRange(location: at.location + insertion.length, length: 0)
        }
        saveContent()
    }

    // MARK: - 地點

    private func updateLocationItem() {
        updateSubtitle()
        guard let location = store.note(id: noteID)?.location else {
            locationItem.menu = nil
            locationItem.primaryAction = UIAction(title: "加入地點",
                                                  image: UIImage(systemName: "mappin.and.ellipse")) { [weak self] _ in
                self?.pickLocation()
            }
            return
        }
        locationItem.primaryAction = nil
        locationItem.image = UIImage(systemName: "mappin.circle.fill")
        let actions = [
            UIAction(title: "在地圖上查看", image: UIImage(systemName: "map")) { [weak self] _ in
                self?.pickLocation()
            },
            UIAction(title: "在「地圖」App 開啟", image: UIImage(systemName: "arrow.up.forward.app")) { _ in
                location.openInMaps()
            },
            UIAction(title: "移除地點", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.setLocation(nil)
            }
        ]
        actions.forEach { $0.preferredImageVisibility = .visible }
        locationItem.menu = UIMenu(title: location.name, subtitle: location.address, children: actions)
    }

    private func pickLocation() {
        let picker = LocationPickerViewController(initial: store.note(id: noteID)?.location)
        picker.onPick = { [weak self] location in self?.setLocation(location) }
        let nav = UINavigationController(rootViewController: picker)
        nav.isToolbarHidden = false
        present(nav, animated: true)
    }

    private func setLocation(_ location: NoteLocation?) {
        guard var note = store.note(id: noteID) else { return }
        note.location = location
        store.update(note)
        updateLocationItem()
    }

    // MARK: - 分類

    private func classifyWithAI() {
        let text = textView.text.replacingOccurrences(of: "\u{FFFC}", with: "")
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return showAlert("沒有文字可以分類")
        }
        isClassifying = true
        updateSubtitle()
        Task {
            do {
                store.setCategory(id: noteID, try await NoteClassifier.classify(text))
            } catch {
                showAlert("分類失敗", error.localizedDescription)
            }
            isClassifying = false
            updateSubtitle()
        }
    }

    // MARK: - 更多選單、分享、刪除

    /// 「更多」選單：每次打開時依目前狀態產生（置頂、分類會變）
    private func makeMoreMenu() -> UIMenu {
        UIMenu(children: [UIDeferredMenuElement.uncached { [weak self] completion in
            guard let self, let note = self.store.note(id: self.noteID) else { return completion([]) }
            let pin = UIAction(title: note.isPinned ? "取消置頂" : "置頂",
                               image: UIImage(systemName: note.isPinned ? "pin.slash" : "pin")) { [weak self] _ in
                guard let self else { return }
                self.store.togglePin(id: self.noteID)
            }
            pin.subtitle = note.isPinned ? nil : "固定在列表最上方"
            let category = UIMenu.category(current: note.category, onAutoClassify: { [weak self] in
                self?.classifyWithAI()
            }, onSelect: { [weak self] category in
                guard let self else { return }
                self.store.setCategory(id: self.noteID, category)
                self.updateSubtitle()
            })
            let delete = UIAction(title: "刪除", image: UIImage(systemName: "trash"),
                                  attributes: .destructive) { [weak self] _ in
                self?.confirmDelete()
            }
            [pin, delete].forEach { $0.preferredImageVisibility = .visible }
            completion([pin, category, delete])
        }])
    }

    @objc private func shareNote() {
        guard !textView.text.isEmpty else { return }
        let vc = UIActivityViewController(activityItems: [textView.attributedText ?? NSAttributedString()],
                                          applicationActivities: nil)
        vc.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItems?.last
        present(vc, animated: true)
    }

    private func confirmDelete() {
        let alert = UIAlertController(title: "刪除這則備忘錄？", message: "刪除後無法復原。",
                                      preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "刪除", style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.store.delete(id: self.noteID)
            self.navigationController?.popViewController(animated: true)
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItems?.first
        present(alert, animated: true)
    }
}

extension NoteEditorViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        saveContent()
    }

    // 點一下手繪圖就打開編輯
    func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem,
                  defaultAction: UIAction) -> UIAction? {
        guard case .textAttachment(let attachment) = textItem.content,
              let drawing = attachment as? DrawingAttachment else { return defaultAction }
        let range = textItem.range
        return UIAction(title: "編輯繪圖") { [weak self] _ in self?.openDrawing(drawing, replacing: range) }
    }

    // 長按手繪圖的選單加上「編輯繪圖」
    func textView(_ textView: UITextView, menuConfigurationFor textItem: UITextItem,
                  defaultMenu: UIMenu) -> UITextItem.MenuConfiguration? {
        guard case .textAttachment(let attachment) = textItem.content,
              let drawing = attachment as? DrawingAttachment else { return UITextItem.MenuConfiguration(menu: defaultMenu) }
        let range = textItem.range
        let edit = UIAction(title: "編輯繪圖", image: UIImage(systemName: "pencil.tip")) { [weak self] _ in
            self?.openDrawing(drawing, replacing: range)
        }
        return UITextItem.MenuConfiguration(menu: UIMenu(children: [edit, defaultMenu]))
    }
}
