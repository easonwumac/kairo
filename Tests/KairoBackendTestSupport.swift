import Foundation
@testable import KairoCore

func makeBackendTestAgentSkillManagerService(
    runtimeContext: AgentSkillRuntimeContext = .permissive
) async throws -> AgentSkillManagerService {
    let storeURL = temporaryBackendTestFileURL(named: "agent-skills.json")
    let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
    return AgentSkillManagerService(
        store: store,
        builtInCatalog: .default,
        runtimeContext: runtimeContext
    )
}

func encodeBackendTestManifestJSON(_ manifest: AgentSkillManifest) throws -> String {
    let data = try JSONEncoder().encode(manifest)
    return String(decoding: data, as: UTF8.self)
}

func temporaryBackendTestFileURL(named name: String) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent(name)
}
