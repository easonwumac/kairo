#if canImport(SwiftUI)
import SwiftUI

public struct PermissionHubView: View {
    private let registry = CapabilityRegistry()

    public init() {}

    public var body: some View {
        NavigationStack {
            List(registry.capabilities) { capability in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(capability.displayName).font(.headline)
                        Spacer()
                        Text(capability.permission.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(capability.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if capability.isMVP {
                        Text("MVP")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Access")
        }
    }
}
#endif
