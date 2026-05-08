//
//  DeviceLoginView.swift
//  Petio
//
//  Splashscreen for device-based login.
//

import SwiftUI

struct DeviceLoginView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var retryTrigger = 0

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            if let error = authViewModel.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(PetCareTheme.muted)

                    Text(error)
                        .font(.system(size: 15))
                        .foregroundStyle(PetCareTheme.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Button {
                        authViewModel.errorMessage = nil
                        retryTrigger += 1
                    } label: {
                        Text("Попробовать снова")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(PetCareTheme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                ProgressView()
                    .scaleEffect(1.5)
            }

            Spacer()
        }
        .padding()
        .background(PetCareTheme.background.ignoresSafeArea())
        .task(id: retryTrigger) {
            print("[DEVICE_LOGIN] task fired, retryTrigger=\(retryTrigger)")
            await authViewModel.deviceLogin()
            print("[DEVICE_LOGIN] deviceLogin() completed, isAuthenticated=\(authViewModel.isAuthenticated)")
        }
    }
}

#Preview {
    DeviceLoginView(authViewModel: AuthViewModel(authManager: AuthManager.shared))
}
