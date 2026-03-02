import Foundation

struct ConversionRecord: Codable, Identifiable {
    let id: UUID
    let input: String
    let inputSuffix: String
    let result: String
    let resultSuffix: String
    let date: Date
}

@Observable
class ConversionHistory {
    private(set) var records: [ConversionRecord] = []
    private let maxRecords = 20
    private let storageKey = "conversion_history"

    init() { load() }

    func add(input: String, inputSuffix: String, result: String, resultSuffix: String) {
        let trimmed = result.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !input.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        // Skip if identical to the most recent record
        if let last = records.first,
           last.input == input,
           last.inputSuffix == inputSuffix,
           last.result == result,
           last.resultSuffix == resultSuffix {
            return
        }

        let record = ConversionRecord(
            id: UUID(),
            input: input,
            inputSuffix: inputSuffix,
            result: result,
            resultSuffix: resultSuffix,
            date: Date()
        )
        records.insert(record, at: 0)
        if records.count > maxRecords {
            records = Array(records.prefix(maxRecords))
        }
        save()
    }

    func clear() {
        records.removeAll()
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ConversionRecord].self, from: data) else { return }
        records = decoded
    }
}
