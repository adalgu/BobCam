import Foundation

struct AppSettings: Codable, Equatable {
    var sensitivity: Double
    var waitTimeSeconds: Int
    var nudgeMessages: [String]

    static let defaultSettings = AppSettings(
        sensitivity: 0.5,
        waitTimeSeconds: 5,
        nudgeMessages: ["밥 먹자!", "냠냠!", "한 입 더!"]
    )
}

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var settings: AppSettings {
        didSet {
            save()
        }
    }

    private let key = "BobCamSettings"

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        } else {
            settings = .defaultSettings
        }
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    func reset() {
        settings = .defaultSettings
    }
}
