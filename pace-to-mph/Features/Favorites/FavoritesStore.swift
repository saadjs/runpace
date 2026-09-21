import Foundation

struct FavoriteConversion: Codable, Identifiable, Equatable {
    let id: UUID
    let input: String
    let inputSuffix: String
    let result: String
    let resultSuffix: String
}

@Observable
class FavoritesStore {
    private(set) var favorites: [FavoriteConversion] = []
    private let maxFavorites = 20
    private let storageKey: String
    private let userDefaults: UserDefaults
    
    init(userDefaults: UserDefaults = .standard, storageKey: String = "pinned_favorites") {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        load()
    }
    
    // Add a favorite. Skip if duplicate (same input+inputSuffix+result+resultSuffix).
    func add(input: String, inputSuffix: String, result: String, resultSuffix: String) {
        // check for duplicate
        if favorites.contains(where: { $0.input == input && $0.inputSuffix == inputSuffix && $0.result == result && $0.resultSuffix == resultSuffix }) {
            return
        }
        let fav = FavoriteConversion(id: UUID(), input: input, inputSuffix: inputSuffix, result: result, resultSuffix: resultSuffix)
        favorites.insert(fav, at: 0)
        if favorites.count > maxFavorites {
            favorites = Array(favorites.prefix(maxFavorites))
        }
        save()
    }
    
    // Remove by id
    func remove(id: UUID) {
        favorites.removeAll { $0.id == id }
        save()
    }
    
    // Check if a conversion is already favorited
    func isFavorited(input: String, inputSuffix: String, result: String, resultSuffix: String) -> Bool {
        favorites.contains { $0.input == input && $0.inputSuffix == inputSuffix && $0.result == result && $0.resultSuffix == resultSuffix }
    }
    
    // Toggle favorite status
    func toggle(input: String, inputSuffix: String, result: String, resultSuffix: String) {
        if let existing = favorites.first(where: { $0.input == input && $0.inputSuffix == inputSuffix && $0.result == result && $0.resultSuffix == resultSuffix }) {
            remove(id: existing.id)
        } else {
            add(input: input, inputSuffix: inputSuffix, result: result, resultSuffix: resultSuffix)
        }
    }
    
    func clear() {
        favorites.removeAll()
        save()
    }
    
    private func save() {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
    
    private func load() {
        guard let data = userDefaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([FavoriteConversion].self, from: data) else { return }
        favorites = decoded
    }
}
