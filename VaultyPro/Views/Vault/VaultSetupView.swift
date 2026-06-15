import SwiftUI

/// First-time setup flow shown when the vault has no auth configured yet.
struct VaultSetupView: View {
    @Environment(VaultManager.self) private var vault
    @Environment(\.dismiss) private var dismiss

    @State private var step: SetupStep = .chooseMethod
    @State private var pinDraft = ""
    @State private var pinConfirm = ""
    @State private var isConfirming = false
    @State private var mismatch = false
    @State private var biometricFailed = false
    @State private var shakeOffset: CGFloat = 0

    enum SetupStep {
        case chooseMethod
        case enterPIN
        case confirmPIN
        case done
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground().ignoresSafeArea()
                content
            }
            .navigationTitle("Set Up Vault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(Color.stashAmber)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .chooseMethod:  chooseMethodView
        case .enterPIN:      pinEntryView(title: "Create a 6-digit PIN", subtitle: "You'll use this to unlock your Vault.")
        case .confirmPIN:    pinEntryView(title: "Confirm your PIN", subtitle: "Enter the same PIN again.")
        case .done:          doneView
        }
    }

    // MARK: - Choose method

    private var chooseMethodView: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.stashAmber)
                    .symbolEffect(.pulse)
                Text("Protect Your Vault")
                    .font(AppFont.title())
                Text("Choose how you want to lock your personal vault.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 14) {
                if vault.canUseBiometrics {
                    methodButton(
                        icon: vault.biometrySystemImage,
                        title: "Use \(vault.biometryDisplayName)",
                        subtitle: "Quick and secure biometric unlock"
                    ) {
                        Task { await setupBiometric() }
                    }
                }

                methodButton(
                    icon: "lock.fill",
                    title: "Use a 6-Digit PIN",
                    subtitle: "Enter a PIN every time you open the vault"
                ) {
                    step = .enterPIN
                }
            }
            .padding(.horizontal, AppMetrics.hPadding)

            if biometricFailed {
                Text("Biometric authentication failed. Please try again or use a PIN.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.stashRed)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }

    private func methodButton(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.stashAmber)
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(.primary)
                    Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(18)
            .background(Color.stashCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primary.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - PIN entry

    private func pinEntryView(title: String, subtitle: String) -> some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Text(title).font(AppFont.title())
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            PINDotsView(length: isConfirming ? pinConfirm.count : pinDraft.count)
                .offset(x: shakeOffset)

            if mismatch {
                Text("PINs don't match. Try again.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.stashRed)
                    .transition(.opacity)
            }

            VaultPINPadView(
                pin: isConfirming ? $pinConfirm : $pinDraft
            ) { completed in
                handlePINComplete(completed)
            }

            Spacer()
        }
        .padding(.horizontal, AppMetrics.hPadding)
        .animation(.default, value: mismatch)
    }

    // MARK: - Done

    private var doneView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 70))
                .foregroundStyle(Color.stashGreen)
                .symbolEffect(.bounce)
            Text("Vault is ready!")
                .font(AppFont.title())
            Text("Your personal vault is now protected.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Vault") { dismiss() }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.stashNavy)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.stashAmber, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, AppMetrics.hPadding)
            Spacer()
        }
    }

    // MARK: - Logic

    private func handlePINComplete(_ pin: String) {
        if !isConfirming {
            isConfirming = true
            step = .confirmPIN
        } else {
            if pin == pinDraft {
                vault.setupWithPIN(pinDraft)
                step = .done
            } else {
                mismatch = true
                shakeField()
                pinConfirm = ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    mismatch = false
                    pinDraft = ""
                    pinConfirm = ""
                    isConfirming = false
                    step = .enterPIN
                }
            }
        }
    }

    private func setupBiometric() async {
        let success = await vault.setupWithBiometrics()
        if success {
            step = .done
        } else {
            biometricFailed = true
        }
    }

    private func shakeField() {
        withAnimation(.default) { shakeOffset = -8 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.default) { shakeOffset = 8 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring()) { shakeOffset = 0 }
            }
        }
    }
}
