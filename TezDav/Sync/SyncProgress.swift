import Foundation

enum SyncPhase: Equatable, Sendable {
    case idle
    case authenticating
    case importing(page: Int, imported: Int)
    case finished(imported: Int)
    case failed(String)
}

@MainActor
final class SyncProgress: ObservableObject {
    @Published var phase: SyncPhase = .idle
}
