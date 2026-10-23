import UIKit

/// 備忘錄列表：搜尋、新增、左滑刪除、右滑置頂
final class NotesListViewController: UITableViewController {

    private let store = NoteStore.shared
    private var displayedNotes: [Note] = []
    private let searchController = UISearchController(searchResultsController: nil)
    private let countLabel = UILabel()

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

        // 底部工具列：數量 + 新增按鈕
        countLabel.font = .preferredFont(forTextStyle: .footnote)
        countLabel.textColor = .secondaryLabel
        let flexible = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let countItem = UIBarButtonItem(customView: countLabel)
        let addItem = UIBarButtonItem(image: UIImage(systemName: "square.and.pencil"),
                                      style: .plain, target: self, action: #selector(addNote))
        toolbarItems = [flexible, countItem, flexible, addItem]

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
        if keyword.isEmpty {
            displayedNotes = store.sortedNotes
        } else {
            displayedNotes = store.sortedNotes.filter { $0.text.localizedCaseInsensitiveContains(keyword) }
        }
        countLabel.text = "\(store.notes.count) 則備忘錄"
        countLabel.sizeToFit()
        tableView.reloadData()
        updateEmptyState()
    }

    private func updateEmptyState() {
        guard displayedNotes.isEmpty else {
            tableView.backgroundView = nil
            return
        }
        var config = UIContentUnavailableConfiguration.empty()
        let searching = !(searchController.searchBar.text ?? "").isEmpty
        config.image = UIImage(systemName: searching ? "magnifyingglass" : "note.text")
        config.text = searching ? "找不到符合的備忘錄" : "還沒有備忘錄"
        config.secondaryText = searching ? nil : "點右下角的按鈕新增第一則"
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
        content.secondaryText = "\(dateText(for: note.updatedAt))  \(note.preview)"
        content.secondaryTextProperties.color = .secondaryLabel
        content.secondaryTextProperties.numberOfLines = 1
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

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        openEditor(for: displayedNotes[indexPath.row].id)
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
