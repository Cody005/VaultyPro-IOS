import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(UndoCenter.self) private var undo
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var showOnboarding = false

    var body: some View {
        TabView {
            Tab("Home", systemImage: "tray.full") {
                HomeView()
            }
            Tab("Collections", systemImage: "square.stack.3d.up") {
                CollectionsView()
            }
            Tab("Search", systemImage: "magnifyingglass") {
                SearchView()
            }
            Tab("Profile", systemImage: "person.crop.circle") {
                SettingsView()
            }
        }
        .tint(Color.stashAmber)
        .overlay(alignment: .bottom) {
            if undo.pending != nil {
                UndoToast(message: undo.message,
                          onUndo: { undo.undo(in: context) },
                          onDismiss: { undo.clear() })
                    .padding(.horizontal, 16)
                    .padding(.bottom, 70)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: undo.pending != nil)
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .onAppear { if !hasOnboarded { showOnboarding = true } }
        .task { SeedData.seedIfNeeded(context) }
    }
}

/// Transient toast offering to undo the most recent deletion.
struct UndoToast: View {
    let message: String
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.stashRed)
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button(action: onUndo) {
                Text("Undo")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.stashAmber)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
    }
}

#Preview {
    ContentView()
        .modelContainer(Persistence.makeContainer(inMemory: true))
        .environment(ProStatusManager())
        .environment(UndoCenter())
}
