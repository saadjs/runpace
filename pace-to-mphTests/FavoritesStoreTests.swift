import Foundation
import Testing
@testable import pace_to_mph

struct FavoritesStoreTests {

    private func makeStore(function: String = #function) -> (FavoritesStore, () -> Void) {
        let suiteName = "FavoritesStoreTests.\(function).\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        let store = FavoritesStore(userDefaults: suite, storageKey: "favorites-test")
        return (store, { suite.removePersistentDomain(forName: suiteName) })
    }

    @Test func addFavorite() {
        let (store, cleanup) = makeStore()
        defer { cleanup() }
        store.add(input: "8:00", inputSuffix: "/mi", result: "7.50", resultSuffix: "MPH")
        #expect(store.favorites.count == 1)
        #expect(store.favorites.first?.input == "8:00")
    }
    
    @Test func addDuplicateSkipped() {
        let (store, cleanup) = makeStore()
        defer { cleanup() }
        store.add(input: "8:00", inputSuffix: "/mi", result: "7.50", resultSuffix: "MPH")
        store.add(input: "8:00", inputSuffix: "/mi", result: "7.50", resultSuffix: "MPH")
        #expect(store.favorites.count == 1)
    }
    
    @Test func removeFavorite() {
        let (store, cleanup) = makeStore()
        defer { cleanup() }
        store.add(input: "8:00", inputSuffix: "/mi", result: "7.50", resultSuffix: "MPH")
        let id = store.favorites.first!.id
        store.remove(id: id)
        #expect(store.favorites.isEmpty)
    }
    
    @Test func isFavorited() {
        let (store, cleanup) = makeStore()
        defer { cleanup() }
        store.add(input: "8:00", inputSuffix: "/mi", result: "7.50", resultSuffix: "MPH")
        #expect(store.isFavorited(input: "8:00", inputSuffix: "/mi", result: "7.50", resultSuffix: "MPH"))
        #expect(!store.isFavorited(input: "7:00", inputSuffix: "/mi", result: "8.57", resultSuffix: "MPH"))
    }
    
    @Test func toggleFavorite() {
        let (store, cleanup) = makeStore()
        defer { cleanup() }
        store.toggle(input: "8:00", inputSuffix: "/mi", result: "7.50", resultSuffix: "MPH")
        #expect(store.favorites.count == 1)
        store.toggle(input: "8:00", inputSuffix: "/mi", result: "7.50", resultSuffix: "MPH")
        #expect(store.favorites.isEmpty)
    }
    
    @Test func maxFavoritesEnforced() {
        let (store, cleanup) = makeStore()
        defer { cleanup() }
        for i in 0..<25 {
            store.add(input: "\(i):00", inputSuffix: "/mi", result: "\(60.0/Double(max(i,1)))", resultSuffix: "MPH")
        }
        #expect(store.favorites.count == 20)
    }
    
    @Test func clearFavorites() {
        let (store, cleanup) = makeStore()
        defer { cleanup() }
        store.add(input: "8:00", inputSuffix: "/mi", result: "7.50", resultSuffix: "MPH")
        store.clear()
        #expect(store.favorites.isEmpty)
    }

    @Test func customStorageIsolation() {
        let suite1Name = "FavoritesStoreTests.suite1.\(UUID().uuidString)"
        let suite2Name = "FavoritesStoreTests.suite2.\(UUID().uuidString)"
        let suite1 = UserDefaults(suiteName: suite1Name)!
        let suite2 = UserDefaults(suiteName: suite2Name)!
        defer {
            suite1.removePersistentDomain(forName: suite1Name)
            suite2.removePersistentDomain(forName: suite2Name)
        }

        let first = FavoritesStore(userDefaults: suite1, storageKey: "favorites")
        let second = FavoritesStore(userDefaults: suite2, storageKey: "favorites")
        first.add(input: "8:00", inputSuffix: "/mi", result: "7.50", resultSuffix: "MPH")
        #expect(first.favorites.count == 1)
        #expect(second.favorites.isEmpty)
    }
}
