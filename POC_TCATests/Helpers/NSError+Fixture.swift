import Foundation

extension NSError {
    // `nonisolated`: it is called inside the clients' `@Sendable` closures
    // (`fetchData = { throw NSError.fixture() }`), outside the MainActor.
    nonisolated static func fixture(message: String = "connection error") -> NSError {
        NSError(domain: "Tests", code: 0, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
