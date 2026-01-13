import SwiftUI
import Combine

struct MagicCodeView: View {
    @Environment(\.dismiss) private var dismiss

    let email: String

    @State private var code = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var resendCooldown = 0
    @State private var isResending = false
    @FocusState private var isCodeFocused: Bool

    // Timer managed with proper cancellation
    @State private var timerCancellable: AnyCancellable?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    // Instructions
                    VStack(spacing: 16) {
                        Image(systemName: "envelope.badge")
                            .font(.system(size: 50))
                            .foregroundColor(.purple)

                        Text("Check your email")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("We sent a 6-digit code to")
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        Text(email)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    // Code Input
                    VStack(spacing: 16) {
                        TextField("000000", text: $code)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(.title.monospacedDigit())
                            .focused($isCodeFocused)
                            .onChange(of: code) { _, newValue in
                                // Only allow digits
                                let filtered = newValue.filter { $0.isNumber }
                                if filtered != newValue {
                                    code = filtered
                                }
                                // Limit to 6 digits
                                if code.count > 6 {
                                    code = String(code.prefix(6))
                                }
                                // Auto-submit when 6 digits entered
                                if code.count == 6 {
                                    verifyCode()
                                }
                            }
                            .padding(.horizontal, 60)

                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        Button(action: verifyCode) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Verify Code")
                                }
                            }
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(code.count == 6 ? Color.purple : Color.gray.opacity(0.5))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(code.count != 6 || isLoading)
                        .padding(.horizontal, 24)
                    }

                    Spacer()

                    // Resend Option
                    if resendCooldown > 0 {
                        Text("Resend code in \(resendCooldown)s")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.bottom, 24)
                    } else if isResending {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(.purple)
                            Text("Sending...")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.bottom, 24)
                    } else {
                        Button("Didn't receive it? Send again") {
                            resendCode()
                        }
                        .font(.subheadline)
                        .foregroundColor(.purple)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            isCodeFocused = true
            resendCooldown = 30
            startTimer()
        }
        .onDisappear {
            // Cancel timer to prevent memory leak
            timerCancellable?.cancel()
            timerCancellable = nil
        }
    }

    private func startTimer() {
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if resendCooldown > 0 {
                    resendCooldown -= 1
                }
            }
    }

    private func verifyCode() {
        guard code.count == 6, !isLoading else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                _ = try await AuthenticationService.shared.verifyMagicCode(
                    email: email,
                    code: code
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    code = ""
                }
            }
        }
    }

    private func resendCode() {
        isResending = true
        errorMessage = nil

        Task {
            do {
                try await AuthenticationService.shared.sendMagicCode(to: email)
                await MainActor.run {
                    isResending = false
                    resendCooldown = 30
                }
            } catch {
                await MainActor.run {
                    isResending = false
                    errorMessage = "Failed to resend code. Please try again."
                }
            }
        }
    }
}

#Preview {
    MagicCodeView(email: "test@example.com")
}
