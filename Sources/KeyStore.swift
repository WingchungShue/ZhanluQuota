import Foundation

/// key 库：JSON 存 Documents/zhanlu_keys.json（与 PC 端 zhanlu_keys.json 同结构可互通）
final class KeyStore: ObservableObject {
    @Published private(set) var keys: [ZKey] = []
    @Published private(set) var querying: Set<UUID> = []

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("zhanlu_keys.json")
    }

    init() { load() }

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let list = try? JSONDecoder().decode([ZKey].self, from: data) else { return }
        keys = list
    }

    func save() {
        guard let data = try? JSONEncoder().encode(keys) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func upsert(_ k: ZKey) {
        if let i = keys.firstIndex(where: { $0.id == k.id }) {
            keys[i] = k
        } else {
            keys.append(k)
        }
        save()
    }

    func delete(_ k: ZKey) {
        keys.removeAll { $0.id == k.id }
        save()
    }

    func query(_ k: ZKey) async {
        await MainActor.run { _ = querying.insert(k.id) }
        do {
            let q = try await QuotaService.query(key: k.key, mode: k.mode)
            await MainActor.run { update(k) { $0.quota = q; $0.lastError = nil; $0.lastTime = Date() } }
        } catch {
            await MainActor.run { update(k) { $0.lastError = error.localizedDescription; $0.lastTime = Date() } }
        }
        await MainActor.run { _ = querying.remove(k.id) }
    }

    func queryAll() async {
        for k in keys {
            await query(k)
        }
    }

    private func update(_ k: ZKey, _ mutate: (inout ZKey) -> Void) {
        guard let i = keys.firstIndex(where: { $0.id == k.id }) else { return }
        mutate(&keys[i])
        save()
    }
}
