import SwiftUI
import Combine

/// Shown whenever the vault is locked and the user tries to open it.
struct VaultUnlockView: View {
    @Environment(VaultManager.self) private var vault
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var pin = ""
    @State private var wrongPIN = false
    @State private var shakeOffset: CGFloat = 0
    @State private var showResetConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground().ignoresSafeArea()
                VStack(spacing: 0) {
                    Spacer()
                    header
                    Spacer().frame(height: 36)
                    pinSection
                    Spacer()
                    forgotPINButton
                        .padding(.bottom, 32)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(Color.stashAmber)
                }
            }
        }
        .onAppear {
            if vault.authMethod == .biometric { Task { await tryBiometrics() } }
        }
        .alert("Reset Vault?", isPresented: $showResetConfirm) {
            Button("Reset Vault", role: .destructive) {
                vault.resetVault(in: context)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All items in your Vault will be moved back to your Inbox, and your PIN will be cleared. This cannot be undone.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(Color.stashAmber)
            Text("Vault Locked")
                .font(AppFont.title())
            Text("Enter your PIN to view your saved content.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - PIN section

    @ViewBuilder
    private var pinSection: some View {
        if vault.isLockedOut {
            lockoutView
        } else if vault.authMethod == .pin {
            pinPadSection
        } else {
            biometricSection
        }
    }

    private var pinPadSection: some View {
        VStack(spacing: 28) {
            PINDotsView(length: pin.count)
                .offset(x: shakeOffset)

            if wrongPIN {
                wrongPINLabel
            }

            VaultPINPadView(pin: $pin) { entered in
                handlePINEntry(entered)
            }

            if vault.authMethod == .biometric {
                biometricFallbackButton
            }
        }
        .padding(.horizontal, AppMetrics.hPadding)
    }

    private var biometricSection: some View {
        VStack(spacing: 24) {
            Button {
                Task { await tryBiometrics() }
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: vault.biometrySystemImage)
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(Color.stashAmber)
                    Text("Use \(vault.biometryDisplayName)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.stashAmber)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var biometricFallbackButton: some View {
        Button {
            Task { await tryBiometrics() }
        } label: {
            Label("Use \(vault.biometryDisplayName)", systemImage: vault.biometrySystemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.stashAmber)
        }
        .buttonStyle(.plain)
    }

    private var wrongPINLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Color.stashRed)
            Text(attemptsMessage)
                .foregroundStyle(Color.stashRed)
        }
        .font(.system(size: 14))
        .transition(.opacity)
    }

    private var attemptsMessage: String {
        let remaining = 5 - vault.failedAttempts
        if remaining <= 0 { return "Too many attempts. Wait 30 seconds." }
        return "Wrong PIN. \(remaining) attempt\(remaining == 1 ? "" : "s") left."
    }

    private var lockoutView: some View {
        VStack(spacing: 16) {
            Image(systemName: "timer")
                .font(.system(size: 40))
                .foregroundStyle(Color.stashRed)
            Text("Too many attempts")
                .font(.system(size: 17, weight: .semibold))
            Text("Try again in \(vault.lockoutSecondsRemaining)s")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                    if !vault.isLockedOut { pin = "" }
                }
        }
    }

    // MARK: - Forgot PIN

    private var forgotPINButton: some View {
        Button {
            showResetConfirm = true
        } label: {
            Text("Forgot PIN?")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .underline()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Logic

    private func handlePINEntry(_ entered: String) {
        let success = vault.unlockWithPIN(entered)
        if success {
            dismiss()
        } else {
            wrongPIN = true
            shakeField()
            pin = ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                wrongPIN = false
            }
        }
    }

    private func tryBiometrics() async {
        await vault.unlockWithBiometrics()
        if vault.vaultState == .unlocked { dismiss() }
    }

    private func shakeField() {
        withAnimation(.default) { shakeOffset = -10 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.default) { shakeOffset = 10 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring()) { shakeOffset = 0 }
            }
        }
    }
}
