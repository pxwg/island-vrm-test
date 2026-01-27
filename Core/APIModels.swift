import Foundation

// 对应 "type": "..."
struct APIRequest: Codable {
    let type: String
    let payload: APIPayload
}

// 对应 "payload": { ... }
struct APIPayload: Codable {
    // assistant_response
    let content: String?
    let tool_info: ToolInfo?
    let performance: Performance?

    // agent_state
    let state: String?

    let follow_mouse: Bool?
}

struct ToolInfo: Codable {
    let status: String
    let name: String
}

struct Performance: Codable {
    let face: String
    let intensity: Double?
    let action: String?
    let audio_url: String?
    let duration: Double?
}
