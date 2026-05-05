import Foundation

@MainActor
final class ServerProfileStore: ObservableObject {
    @Published private(set) var servers: [ServerProfile] = []

    private let defaults: UserDefaults
    private let storageKey = "NodeGetMonitor.ServerProfiles.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.servers = Self.loadServers(from: defaults, key: storageKey)
    }

    func add(name: String, baseURL: URL, token: String) throws -> ServerProfile {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = ServerProfile(
            name: cleanName.isEmpty ? URLNormalizer.defaultName(for: baseURL) : cleanName,
            baseURL: baseURL
        )

        try KeychainStore.shared.saveToken(token, for: profile.id)
        servers.insert(profile, at: 0)
        save()

        return profile
    }

    func delete(_ profile: ServerProfile) {
        servers.removeAll { $0.id == profile.id }
        try? KeychainStore.shared.deleteToken(for: profile.id)
        save()
    }

    func delete(at offsets: IndexSet) {
        let profiles = offsets.map { servers[$0] }
        for profile in profiles {
            try? KeychainStore.shared.deleteToken(for: profile.id)
        }
        for index in offsets.sorted(by: >) {
            servers.remove(at: index)
        }
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(servers)
            defaults.set(data, forKey: storageKey)
        } catch {
            print("Failed to save server profiles: \(error)")
        }
    }

    private static func loadServers(from defaults: UserDefaults, key: String) -> [ServerProfile] {
        guard let data = defaults.data(forKey: key) else { return [] }

        do {
            return try JSONDecoder().decode([ServerProfile].self, from: data)
        } catch {
            print("Failed to load server profiles: \(error)")
            return []
        }
    }
}
