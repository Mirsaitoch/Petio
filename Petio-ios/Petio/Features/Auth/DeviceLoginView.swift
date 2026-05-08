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
            
            ProgressView()
                .scaleEffect(1.5)
            
            Spacer()
        }
        .padding()
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
        .onAppear {
            print("[DEVICE_LOGIN_VIEW] onAppear: triggering deviceLogin")
            Task {
                print("[DEVICE_LOGIN_VIEW] Task: calling deviceLogin()")
                await authViewModel.deviceLogin()
                print("[DEVICE_LOGIN_VIEW] Task: deviceLogin() returned")
            }
        }
    }
}

#Preview {
    DeviceLoginView(authViewModel: AuthViewModel(authManager: AuthManager.shared))
}
