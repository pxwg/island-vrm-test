import Foundation

// MARK: - Data Models

struct CameraPosition: Codable, Equatable {
    var x: Double
    var y: Double
    var z: Double
}

struct CameraSetting: Codable, Equatable {
    var position: CameraPosition
    var target: CameraPosition
    var fov: Double
}

struct CameraConfig: Codable, Equatable {
    var head: CameraSetting
    var body: CameraSetting
    var lerpSpeed: Double
    // [新增] 鼠标跟随开关
    var followMouse: Bool
}

// MARK: - Settings Manager

class CameraSettings: ObservableObject {
    static let shared = CameraSettings()

    // Published properties for real-time UI binding
    @Published var config: CameraConfig

    private let defaults = UserDefaults.standard
    private let configKey = "com.pxwg.islandvrm.cameraConfig"

    // Default configuration (fallback values)
    private static let defaultConfig = CameraConfig(
        head: CameraSetting(
            position: CameraPosition(x: 0.05, y: 1.45, z: 2.15),
            target: CameraPosition(x: 0.05, y: 1.45, z: 0),
            fov: 40
        ),
        body: CameraSetting(
            position: CameraPosition(x: 0, y: 1.4, z: 0.6),
            target: CameraPosition(x: 0, y: 1.4, z: 0),
            fov: 40
        ),
        lerpSpeed: 0.05,
        // [新增] 默认为 false，保证不跟随
        followMouse: false
    )

    private init() {
        // Load from UserDefaults or use default
        if let savedData = defaults.data(forKey: configKey),
           let decoded = try? JSONDecoder().decode(CameraConfig.self, from: savedData)
        {
            config = decoded
            print("📷 Loaded camera config from UserDefaults")
        } else {
            config = CameraSettings.defaultConfig
            print("📷 Using default camera config")
            // Save default to UserDefaults
            save()
        }
    }

    // MARK: - Public Methods

    /// Save current configuration to UserDefaults
    func save() {
        if let encoded = try? JSONEncoder().encode(config) {
            defaults.set(encoded, forKey: configKey)
            print("💾 Camera config saved to UserDefaults")
        }
    }

    /// Update a specific mode's settings
    func updateHead(position: CameraPosition? = nil, target: CameraPosition? = nil, fov: Double? = nil) {
        if let position = position {
            config.head.position = position
        }
        if let target = target {
            config.head.target = target
        }
        if let fov = fov {
            config.head.fov = fov
        }
        save()
    }

    func updateBody(position: CameraPosition? = nil, target: CameraPosition? = nil, fov: Double? = nil) {
        if let position = position {
            config.body.position = position
        }
        if let target = target {
            config.body.target = target
        }
        if let fov = fov {
            config.body.fov = fov
        }
        save()
    }

    /// Get configuration as JSON string for WebView injection
    func toJSON() -> String? {
        if let encoded = try? JSONEncoder().encode(config),
           let jsonString = String(data: encoded, encoding: .utf8)
        {
            return jsonString
        }
        return nil
    }

    /// Reset to default configuration
    func reset() {
        config = CameraSettings.defaultConfig
        save()
    }
}
