import Foundation

final class RaceStateCache: ObservableObject {

    private var debounceTask: Task<Void, Never>?
    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("race_state.json")
    }

    // Called on every MARK or assignment — debounced 750ms trailing edge
    func stage(_ blob: RaceStateBlob) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 750_000_000)
            guard !Task.isCancelled else { return }
            write(blob)
        }
    }

    // Called from sceneDidEnterBackground — synchronous, immediate
    func flushImmediately(_ blob: RaceStateBlob) {
        debounceTask?.cancel()
        debounceTask = nil
        write(blob)
    }

    func load() -> RaceStateBlob? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(RaceStateBlob.self, from: data)
    }

    // Called when race finishes normally to remove stale state
    func clear() {
        debounceTask?.cancel()
        debounceTask = nil
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: – Private

    private func write(_ blob: RaceStateBlob) {
        guard let data = try? JSONEncoder().encode(blob) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
