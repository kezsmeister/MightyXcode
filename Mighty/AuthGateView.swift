import SwiftUI

struct AuthGateView: View {
    @State private var authState = AuthState.shared

    var body: some View {
        Group {
            if authState.isLoading {
                // Loading state while checking auth
                ZStack {
                    Color.black.ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.purple)

                        Text("Loading...")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            } else if authState.canAccessApp {
                // User is signed in or chose to skip - show main app
                RootView()
            } else {
                // User is not signed in and hasn't skipped - show login
                LoginView()
            }
        }
        .task {
            await AuthenticationService.shared.checkAuthenticationStatus()
        }
    }
}

#Preview {
    AuthGateView()
}
