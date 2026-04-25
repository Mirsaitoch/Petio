//
//  DeviceLoginView.swift
//  Petio
//
//  Splashscreen for device-based login.
//

import SwiftUI

struct DeviceLoginView: View {
    @ObservedObject var authViewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("Один момент")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Настраиваем ваш аккаунт...")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            ProgressView()
                .scaleEffect(1.5)

            Spacer()
        }
        .padding()
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
        .onAppear {
            Task {
                await authViewModel.deviceLogin()
            }
        }
    }
}

#Preview {
    DeviceLoginView(authViewModel: AuthViewModel(authManager: AuthManager.shared))
}
