import UIKit

/// 編輯畫面：輸入時自動儲存，離開時若內容為空就刪除
final class NoteEditorViewController: UIViewController {

    private let noteID: UUID
    private let store = NoteStore.shared
    private let textView = UITextView()

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
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.delegate = self
        textView.grammarCheckingType = .yes
        textView.text = store.note(id: noteID)?.text
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
        toolbarItems = []
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

    private func updateTitle() {
        let count = textView.text.count
        navigationItem.title = count == 0 ? "" : "\(count) 字"
    }

    /// 「更多」選單：每次打開時依目前狀態產生（置頂狀態會變）
    private func makeMoreMenu() -> UIMenu {
        UIMenu(children: [UIDeferredMenuElement.uncached { [weak self] completion in
            guard let self, let note = self.store.note(id: self.noteID) else { return completion([]) }
            let pin = UIAction(title: note.isPinned ? "取消置頂" : "置頂",
                               image: UIImage(systemName: note.isPinned ? "pin.slash" : "pin")) { [weak self] _ in
                guard let self else { return }
                self.store.togglePin(id: self.noteID)
            }
            let delete = UIAction(title: "刪除", image: UIImage(systemName: "trash"),
                                  attributes: .destructive) { [weak self] _ in
                self?.confirmDelete()
            }
            pin.subtitle = note.isPinned ? nil : "固定在列表最上方"
            [pin, delete].forEach { $0.preferredImageVisibility = .visible }
            completion([pin, delete])
        }])
    }

    @objc private func shareNote() {
        guard !textView.text.isEmpty else { return }
        let vc = UIActivityViewController(activityItems: [textView.text ?? ""], applicationActivities: nil)
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
        guard var note = store.note(id: noteID) else { return }
        note.text = textView.text
        store.update(note)
        updateTitle()
    }
}
