import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var isLoading = false
    @State private var showMagicCodeEntry = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo/Brand
                VStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 60))
                        .foregroundColor(.purple)

                    Text("Mighty")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Sign in to sync your data across devices")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                // Email Input
                VStack(spacing: 16) {
                    TextField("Email address", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .disabled(isLoading)
                        .padding(.horizontal, 24)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 24)
                    }

                    Button(action: sendMagicCode) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Continue with Email")
                            }
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isValidEmail ? Color.purple : Color.gray.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!isValidEmail || isLoading)
                    .padding(.horizontal, 24)
                }

                Spacer()

                // Skip Option
                Button("Skip for now") {
                    AuthState.shared.skipAuthentication()
                }
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showMagicCodeEntry) {
            MagicCodeView(email: email)
        }
    }

    private var isValidEmail: Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }

    private func sendMagicCode() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await AuthenticationService.shared.sendMagicCode(to: email)
                await MainActor.run {
                    isLoading = false
                    showMagicCodeEntry = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    LoginView()
}
