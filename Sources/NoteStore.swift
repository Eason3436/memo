import Foundation

extension Notification.Name {
    static let notesDidChange = Notification.Name("notesDidChange")
}

/// 負責備忘錄的讀取與儲存（存成 JSON 檔在 App 的 Documents 資料夾）
final class NoteStore {
    static let shared = NoteStore()

    private(set) var notes: [Note] = []
    private let fileURL: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("notes.json")
        load()
    }

    /// 置頂優先，其次依最後修改時間排序
    var sortedNotes: [Note] {
        notes.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
    }

    func note(id: UUID) -> Note? {
        notes.first { $0.id == id }
    }

    @discardableResult
    func create() -> Note {
        let note = Note()
        notes.append(note)
        save()
        return note
    }

    func update(_ note: Note) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }
        var updated = note
        updated.updatedAt = Date()
        notes[index] = updated
        save()
    }

    func togglePin(id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].isPinned.toggle()
        save()
    }

    /// 設定分類（不算修改內容，所以不更新修改時間）
    func setCategory(id: UUID, _ category: String?) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].category = category
        save()
    }

    func delete(id: UUID) {
        notes.removeAll { $0.id == id }
        save()
    }

    /// 移除內容全空白的備忘錄（離開編輯畫面時呼叫）
    func removeIfEmpty(id: UUID) {
        guard let note = note(id: id) else { return }
        if note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            delete(id: id)
        }
    }

    // MARK: - 檔案存取

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        notes = (try? decoder.decode([Note].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(notes) {
            try? data.write(to: fileURL, options: .atomic)
        }
        NotificationCenter.default.post(name: .notesDidChange, object: nil)
    }
}
