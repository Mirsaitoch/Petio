import SwiftUI

struct OfflineIndicatorView: View {
    @EnvironmentObject var networkMonitor: NetworkMonitor

    var body: some View {
        if !networkMonitor.isOnline {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 14, weight: .semibold))

                Text("Без интернета • Режим просмотра")
                    .font(.system(size: 13, weight: .medium))

                Spacer()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.red.opacity(0.85))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

#Preview {
    ZStack {
        VStack {
            OfflineIndicatorView()
                .environmentObject(NetworkMonitor())

            Spacer()
        }
        .background(Color(.systemGray6))
    }
}
