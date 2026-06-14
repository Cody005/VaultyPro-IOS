import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProStatusManager.self) private var pro
    @State private var selectedAnnual = true

    private let features = [
        ("infinity", "Unlimited saves", "No more 50-item limit"),
        ("folder.fill", "Unlimited collections", "Organize without limits"),
        ("magnifyingglass", "Full-text search", "Find anything instantly"),
        ("highlighter", "Highlights", "Color-code & export to Readwise"),
        ("square.and.arrow.up", "Import & Export", "Raindrop, Instapaper, JSON, CSV"),
        ("app.badge", "Custom app icons", "Make it yours")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                hero
                featureList
                plans
                ctaButton
                restoreButton
                Text("Cancel anytime. Payment is charged to your Apple ID.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(AppMetrics.hPadding)
            .padding(.bottom, 24)
        }
        .background(backdrop.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2).foregroundStyle(.white.opacity(0.7))
            }
            .padding()
        }
        .onChange(of: pro.isPro) { _, isPro in if isPro { dismiss() } }
    }

    private var backdrop: some View {
        LinearGradient(colors: [.stashNavy, Color(hex: "#1A2A3A"), .stashNavy],
                       startPoint: .top, endPoint: .bottom)
    }

    private var hero: some View {
        VStack(spacing: 10) {
            Image(systemName: "crown.fill")
                .font(.system(size: 50))
                .foregroundStyle(LinearGradient(colors: [.stashAmber, .typeImage],
                                                startPoint: .top, endPoint: .bottom))
                .padding(.top, 30)
            Text("VaultyPro Pro")
                .font(.system(size: 30, weight: .bold)).foregroundStyle(.white)
            Text("Everything you save, supercharged.")
                .font(.system(size: 15)).foregroundStyle(.white.opacity(0.7))
        }
    }

    private var featureList: some View {
        VStack(spacing: 14) {
            ForEach(features, id: \.0) { feature in
                HStack(spacing: 14) {
                    Image(systemName: feature.0)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.stashAmber)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(feature.1).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                        Text(feature.2).font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.stashGreen)
                }
            }
        }
        .padding(18)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
    }

    private var plans: some View {
        VStack(spacing: 12) {
            planRow(title: "Annual", price: pro.annualProduct?.displayPrice ?? "$24.99",
                    subtitle: "Best value · 2 months free", isAnnual: true)
            planRow(title: "Monthly", price: pro.monthlyProduct?.displayPrice ?? "$2.99",
                    subtitle: "Billed monthly", isAnnual: false)
        }
    }

    private func planRow(title: String, price: String, subtitle: String, isAnnual: Bool) -> some View {
        Button { selectedAnnual = isAnnual } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Text(price).font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
            }
            .padding(16)
            .background(.white.opacity(selectedAnnual == isAnnual ? 0.12 : 0.04), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .strokeBorder(selectedAnnual == isAnnual ? Color.stashAmber : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private var ctaButton: some View {
        Button {
            Task {
                if let product = selectedAnnual ? pro.annualProduct : pro.monthlyProduct {
                    await pro.purchase(product)
                }
            }
        } label: {
            Text("Start VaultyPro Pro")
                .font(.system(size: 17, weight: .bold)).foregroundStyle(Color.stashNavy)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color.stashAmber.gradient, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var restoreButton: some View {
        Button("Restore Purchases") { Task { await pro.restore() } }
            .font(.system(size: 13)).tint(.white.opacity(0.8))
    }
}
