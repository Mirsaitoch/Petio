import Foundation
import Network

@MainActor
class NetworkMonitor: ObservableObject {
    @Published var isOnline: Bool = true

    private let pathMonitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")

    init() {
        startMonitoring()
    }

    private func startMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOnline = (path.status == .satisfied)
                let status = self?.isOnline == true ? "✅ Онлайн" : "⚠️ Офлайн"
                print("\(status)")
            }
        }
        pathMonitor.start(queue: queue)
    }

    deinit {
        pathMonitor.cancel()
    }
}
