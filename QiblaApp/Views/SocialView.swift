import SwiftUI
import SwiftData

// MARK: - SocialView

struct SocialView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Halaqa.createdAt, order: .reverse) private var halaqas: [Halaqa]
    @State private var showCreateSheet = false
    @State private var showJoinSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Action buttons
                    actionButtons

                    if halaqas.isEmpty {
                        emptyState
                    } else {
                        ForEach(halaqas) { halaqa in
                            NavigationLink(value: halaqa.persistentModelID) {
                                HalaqaCard(halaqa: halaqa)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(AppPalette.background)
            .navigationTitle("الحلقات")
            .navigationDestination(for: PersistentIdentifier.self) { id in
                if let halaqa = halaqas.first(where: { $0.persistentModelID == id }) {
                    HalaqaDetailView(halaqa: halaqa)
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateHalaqaView(mode: .create)
            }
            .sheet(isPresented: $showJoinSheet) {
                CreateHalaqaView(mode: .join)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                showCreateSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    Text("إنشاء حلقة")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(
                    LinearGradient(
                        colors: [AppPalette.green, AppPalette.green.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            }

            Button {
                showJoinSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "link.circle.fill")
                        .font(.title3)
                    Text("انضم برمز")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(
                    LinearGradient(
                        colors: [AppPalette.socialPurple, AppPalette.socialPurple.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 50))
                .foregroundStyle(AppPalette.green.opacity(0.4))

            Text("لا توجد حلقات بعد")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("أنشئ حلقة جديدة لختم القرآن أو التسبيح مع عائلتك وأصدقائك")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 60)
    }
}

// MARK: - HalaqaCard

struct HalaqaCard: View {
    let halaqa: Halaqa

    var body: some View {
        HStack(spacing: 16) {
            // Circular progress
            ZStack {
                Circle()
                    .stroke(AppPalette.green.opacity(0.15), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: halaqa.completionRatio)
                    .stroke(
                        LinearGradient(
                            colors: [AppPalette.green, AppPalette.gold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Image(systemName: halaqa.type.icon)
                    .font(.title3)
                    .foregroundStyle(AppPalette.green)
            }
            .frame(width: 52, height: 52)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(halaqa.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(halaqa.type.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text("\(halaqa.members.count) أعضاء")
                        .font(.caption2)
                }
                .foregroundStyle(.tertiary)
            }

            Spacer()

            // Progress text
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(halaqa.completionRatio * 100))%")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppPalette.green)

                Text("\(halaqa.totalProgress)/\(halaqa.totalTarget)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.left")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Preview

#Preview {
    SocialView()
        .modelContainer(for: [Halaqa.self, HalaqaMember.self], inMemory: true)
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
        .preferredColorScheme(.dark)
}
