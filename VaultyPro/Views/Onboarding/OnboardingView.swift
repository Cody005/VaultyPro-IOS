import SwiftUI
import UserNotifications

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var page = 0

    var body: some View {
        ZStack {
            LinearGradient(colors: [.stashNavy, Color(hex: "#16263A")],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button("Skip") { finish() }
                        .font(.system(size: 15, weight: .medium))
                        .tint(.white.opacity(0.7))
                        .padding()
                }

                TabView(selection: $page) {
                    intro.tag(0)
                    shareFlow.tag(1)
                    permissions.tag(2)
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Button {
                    if page < 2 { withAnimation { page += 1 } } else { finish() }
                } label: {
                    Text(page < 2 ? "Continue" : "Get Started")
                        .font(.system(size: 17, weight: .bold)).foregroundStyle(Color.stashNavy)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color.stashAmber.gradient, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 30).padding(.bottom, 30)
            }
        }
    }

    private var intro: some View {
        page(icon: "tray.full.fill",
             title: "Welcome to VaultyPro",
             message: "Your universal inbox for everything worth keeping — articles, videos, posts, and ideas.")
    }

    private var shareFlow: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 70)).foregroundStyle(Color.stashAmber)
                Image(systemName: "arrow.turn.right.down")
                    .font(.system(size: 30)).foregroundStyle(.white.opacity(0.6))
                    .offset(x: 60, y: -40)
            }
            Text("Share from anywhere")
                .font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
            Text("In any app, tap Share → VaultyPro. We'll grab the title, thumbnail and link automatically.")
                .font(.system(size: 16)).foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center).padding(.horizontal, 36)
            Spacer()
        }
    }

    private var permissions: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "icloud.fill").font(.system(size: 64)).foregroundStyle(Color.stashAmber)
            Text("Synced & ready").font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
            Text("Your vault syncs across devices with iCloud. Enable notifications to get gentle reminders about your reading list.")
                .font(.system(size: 16)).foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center).padding(.horizontal, 36)
            Button {
                Task { _ = try? await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .badge, .sound]) }
            } label: {
                Label("Enable Notifications", systemImage: "bell.fill")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(.white.opacity(0.12), in: Capsule())
            }.buttonStyle(.plain)
            Spacer()
        }
    }

    private func page(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundStyle(LinearGradient(colors: [.stashAmber, .typeImage],
                                                startPoint: .top, endPoint: .bottom))
            Text(title).font(.system(size: 28, weight: .bold)).foregroundStyle(.white)
            Text(message).font(.system(size: 16)).foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center).padding(.horizontal, 36)
            Spacer()
        }
    }

    private func finish() {
        hasOnboarded = true
        withAnimation(.easeInOut) { isPresented = false }
    }
}
