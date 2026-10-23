import UIKit

/// 備忘錄列表：搜尋、分類篩選、AI 分類、新增、左滑刪除、右滑置頂
final class NotesListViewController: UITableViewController {

    private let store = NoteStore.shared
    private var displayedNotes: [Note] = []
    private let searchController = UISearchController(searchResultsController: nil)
    private var selectedCategory: String?
    /// Apple Intelligence 分類進行中的狀態文字
    private var classifyProgress: String?
    private lazy var filterItem = UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal.decrease.circle"),
                                                  menu: UIMenu(children: [UIDeferredMenuElement.uncached { [weak self] completion in
        completion(self?.filterMenuElements() ?? [])
    }]))

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_Hant_TW")
        return f
    }()

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "備忘錄"

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        // 搜尋列
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "搜尋"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true

        // 底部工具列：搜尋列 + 新增按鈕
        let addItem = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(addNote))
        addItem.style = .prominent
        toolbarItems = [navigationItem.searchBarPlacementBarButtonItem, .flexibleSpace(), addItem]

        navigationItem.rightBarButtonItem = filterItem

        // 往下捲動時縮小導覽列，捲回頂端才恢復
        navigationItem.navigationBarMinimization.minimizationBehavior = .onScrollDown
        navigationItem.navigationBarMinimization.restorationBehavior = .atScrollEdge

        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                               name: .notesDidChange, object: nil)
        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    @objc private func reload() {
        let keyword = searchController.searchBar.text?.trimmingCharacters(in: .whitespaces) ?? ""
        var notes = store.sortedNotes
        if let selectedCategory {
            notes = notes.filter { $0.category == selectedCategory }
        }
        if !keyword.isEmpty {
            notes = notes.filter {
                $0.plainText.localizedCaseInsensitiveContains(keyword)
                    || ($0.category?.contains(keyword) ?? false)
                    || ($0.location?.name.localizedCaseInsensitiveContains(keyword) ?? false)
            }
        }
        displayedNotes = notes
        filterItem.image = UIImage(systemName: selectedCategory == nil
                                   ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
        updateSubtitle()
        tableView.reloadData()
        updateEmptyState()
    }

    private func updateSubtitle() {
        if let classifyProgress {
            navigationItem.subtitle = classifyProgress
        } else if let selectedCategory {
            navigationItem.subtitle = "\(selectedCategory) · \(displayedNotes.count) 則"
        } else {
            navigationItem.subtitle = "\(store.notes.count) 則備忘錄"
        }
    }

    // MARK: - 分類

    /// 右上角選單：依分類篩選 + Apple Intelligence 批次分類
    private func filterMenuElements() -> [UIMenuElement] {
        let counts = Dictionary(grouping: store.notes.compactMap(\.category), by: { $0 }).mapValues(\.count)
        let all = UIAction(title: "全部", image: UIImage(systemName: "tray.full"),
                           state: selectedCategory == nil ? .on : .off) { [weak self] _ in
            self?.selectedCategory = nil
            self?.reload()
        }
        let categories = NoteCategory.all.map { category in
            let action = UIAction(title: category, image: UIImage(systemName: NoteCategory.icon(for: category)),
                                  state: selectedCategory == category ? .on : .off) { [weak self] _ in
                self?.selectedCategory = category
                self?.reload()
            }
            action.subtitle = "\(counts[category] ?? 0) 則"
            return action
        }
        let busy: UIMenuElement.Attributes = classifyProgress == nil ? [] : .disabled
        let ai = [
            UIAction(title: "自動分類未分類的備忘錄", image: UIImage(systemName: "apple.intelligence"),
                     attributes: busy) { [weak self] _ in self?.classifyNotes(onlyUnclassified: true) },
            UIAction(title: "全部重新分類", image: UIImage(systemName: "arrow.triangle.2.circlepath"),
                     attributes: busy) { [weak self] _ in self?.classifyNotes(onlyUnclassified: false) }
        ]
        ([all] + categories + ai).forEach { $0.preferredImageVisibility = .visible }
        return [
            UIMenu(title: "依分類顯示", options: .displayInline, children: [all] + categories),
            UIMenu(title: "Apple Intelligence", options: .displayInline, children: ai)
        ]
    }

    /// 用 Apple Intelligence 逐則分類
    private func classifyNotes(onlyUnclassified: Bool) {
        if let reason = NoteClassifier.unavailableReason {
            return showAlert("無法使用 Apple Intelligence", reason)
        }
        let targets = store.notes.filter {
            !$0.plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && (!onlyUnclassified || $0.category == nil)
        }
        guard !targets.isEmpty else { return showAlert("沒有需要分類的備忘錄") }
        Task {
            for (index, note) in targets.enumerated() {
                classifyProgress = "Apple Intelligence 分類中 \(index + 1)/\(targets.count)…"
                updateSubtitle()
                do {
                    store.setCategory(id: note.id, try await NoteClassifier.classify(note.plainText))
                } catch {
                    classifyProgress = nil
                    reload()
                    return showAlert("分類失敗", error.localizedDescription)
                }
            }
            classifyProgress = nil
            reload()
        }
    }

    private func classifyNote(_ note: Note) {
        Task {
            do {
                store.setCategory(id: note.id, try await NoteClassifier.classify(note.plainText))
            } catch {
                showAlert("分類失敗", error.localizedDescription)
            }
        }
    }

    private func updateEmptyState() {
        guard displayedNotes.isEmpty else {
            tableView.backgroundView = nil
            return
        }
        var config = UIContentUnavailableConfiguration.empty()
        let searching = !(searchController.searchBar.text ?? "").isEmpty
        if searching {
            config.image = UIImage(systemName: "magnifyingglass")
            config.text = "找不到符合的備忘錄"
        } else if let selectedCategory {
            config.image = UIImage(systemName: NoteCategory.icon(for: selectedCategory))
            config.text = "「\(selectedCategory)」沒有備忘錄"
        } else {
            config.image = UIImage(systemName: "note.text")
            config.text = "還沒有備忘錄"
            config.secondaryText = "點右下角的編寫按鈕新增第一則"
        }
        tableView.backgroundView = UIContentUnavailableView(configuration: config)
    }

    @objc private func addNote() {
        let note = store.create()
        openEditor(for: note.id)
    }

    private func openEditor(for id: UUID) {
        navigationController?.pushViewController(NoteEditorViewController(noteID: id), animated: true)
    }

    private func dateText(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            dateFormatter.dateFormat = "HH:mm"
        } else if Calendar.current.isDateInYesterday(date) {
            return "昨天"
        } else {
            dateFormatter.dateFormat = "yyyy/M/d"
        }
        return dateFormatter.string(from: date)
    }

    // MARK: - Table view

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        displayedNotes.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let note = displayedNotes[indexPath.row]

        var content = UIListContentConfiguration.subtitleCell()
        content.text = note.title
        content.textProperties.font = .preferredFont(forTextStyle: .headline)
        content.textProperties.numberOfLines = 1
        content.secondaryAttributedText = detailText(for: note)
        content.secondaryTextProperties.color = .secondaryLabel
        content.secondaryTextProperties.numberOfLines = 2
        content.textToSecondaryTextVerticalPadding = 4
        if note.isPinned {
            content.image = UIImage(systemName: "pin.fill")
            content.imageProperties.tintColor = .systemOrange
            content.imageProperties.maximumSize = CGSize(width: 16, height: 16)
        }
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    /// 第一行：日期 + 預覽；有分類或地點時第二行顯示標籤
    private func detailText(for note: Note) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .subheadline),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let detail = NSMutableAttributedString(string: "\(dateText(for: note.updatedAt))  \(note.preview)",
                                               attributes: attributes)
        var tags: [(symbol: String, label: String)] = []
        if let category = note.category { tags.append((NoteCategory.icon(for: category), category)) }
        if let location = note.location { tags.append(("mappin", location.name)) }
        for (index, tag) in tags.enumerated() {
            detail.append(NSAttributedString(string: index == 0 ? "\n" : "   ", attributes: attributes))
            if let image = UIImage(systemName: tag.symbol)?.withTintColor(.systemOrange, renderingMode: .alwaysOriginal) {
                detail.append(NSAttributedString(attachment: NSTextAttachment(image: image)))
            }
            detail.append(NSAttributedString(string: " " + tag.label, attributes: attributes))
        }
        return detail
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        openEditor(for: displayedNotes[indexPath.row].id)
    }

    // 長按選單：置頂、分享、刪除
    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath,
                            point: CGPoint) -> UIContextMenuConfiguration? {
        let note = displayedNotes[indexPath.row]
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let pin = UIAction(title: note.isPinned ? "取消置頂" : "置頂",
                               image: UIImage(systemName: note.isPinned ? "pin.slash" : "pin")) { _ in
                self?.store.togglePin(id: note.id)
            }
            let share = UIAction(title: "分享", image: UIImage(systemName: "square.and.arrow.up")) { _ in
                self?.share(note, from: indexPath)
            }
            let delete = UIAction(title: "刪除", image: UIImage(systemName: "trash"),
                                  attributes: .destructive) { _ in
                self?.store.delete(id: note.id)
            }
            let category = UIMenu.category(current: note.category, onAutoClassify: {
                self?.classifyNote(note)
            }, onSelect: { category in
                self?.store.setCategory(id: note.id, category)
            })
            [pin, share, delete].forEach { $0.preferredImageVisibility = .visible }
            return UIMenu(children: [pin, category, share, delete])
        }
    }

    private func share(_ note: Note, from indexPath: IndexPath) {
        let vc = UIActivityViewController(activityItems: [note.plainText], applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath)
        present(vc, animated: true)
    }

    // 左滑刪除
    override func tableView(_ tableView: UITableView,
                            trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let id = displayedNotes[indexPath.row].id
        let delete = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, done in
            self?.store.delete(id: id)
            done(true)
        }
        delete.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [delete])
    }

    // 右滑置頂
    override func tableView(_ tableView: UITableView,
                            leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let note = displayedNotes[indexPath.row]
        let pin = UIContextualAction(style: .normal, title: nil) { [weak self] _, _, done in
            self?.store.togglePin(id: note.id)
            done(true)
        }
        pin.image = UIImage(systemName: note.isPinned ? "pin.slash.fill" : "pin.fill")
        pin.backgroundColor = .systemOrange
        return UISwipeActionsConfiguration(actions: [pin])
    }
}

extension NotesListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        reload()
    }
}
