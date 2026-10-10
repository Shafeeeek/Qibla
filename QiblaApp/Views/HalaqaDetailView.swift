import SwiftUI
import SwiftData

// MARK: - HalaqaDetailView

struct HalaqaDetailView: View {
    @Bindable var halaqa: Halaqa
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var stepAmount = 1
    @State private var showDeleteConfirmation = false
    @State private var animatedProgress: Double = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                progressCircle
                shareCodeBanner
                membersList
                updateSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AppPalette.background)
        .navigationTitle(halaqa.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("حذف الحلقة", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("حذف الحلقة؟", isPresented: $showDeleteConfirmation) {
            Button("حذف", role: .destructive) {
                modelContext.delete(halaqa)
                try? modelContext.save()
                dismiss()
            }
            Button("إلغاء", role: .cancel) {}
        } message: {
            Text("سيتم حذف الحلقة نهائياً لجميع الأعضاء.")
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                animatedProgress = halaqa.completionRatio
            }
        }
    }

    // MARK: - Progress Circle

    private var progressCircle: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(AppPalette.green.opacity(0.12), lineWidth: 14)

                // Progress ring
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        AngularGradient(
                            colors: [AppPalette.green, AppPalette.gold, AppPalette.green],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                // Center text
                VStack(spacing: 4) {
                    Text("\(Int(halaqa.completionRatio * 100))%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(AppPalette.green)

                    Text("\(halaqa.totalProgress) / \(halaqa.totalTarget) \(halaqa.type.unitName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if halaqa.isCompleted {
                        Text("🎉 مبارك — تمت الختمة!")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppPalette.gold)
                    }
                }
            }
            .frame(width: 180, height: 180)
            .padding(.top, 8)

            // Type badge
            HStack(spacing: 6) {
                Image(systemName: halaqa.type.icon)
                Text(halaqa.type.rawValue)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(AppPalette.green)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(AppPalette.green.opacity(0.12), in: Capsule())
        }
    }

    // MARK: - Share Code Banner

    private var shareCodeBanner: some View {
        VStack(spacing: 8) {
            Text("رمز المشاركة")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                ForEach(Array(halaqa.shareCode.enumerated()), id: \.offset) { _, char in
                    Text(String(char))
                        .font(.title2.weight(.bold).monospaced())
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(AppPalette.socialPurple.gradient)
                        )
                }
            }

            ShareLink(item: "انضم لحلقة \"\(halaqa.name)\" في تطبيق قبلتي!\nالرمز: \(halaqa.shareCode)") {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                    Text("مشاركة الرمز")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppPalette.socialPurple)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Members List

    private var membersList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(AppPalette.green)
                Text("الأعضاء")
                    .font(.headline)
                Spacer()
                Text("\(halaqa.members.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(halaqa.members, id: \.id) { member in
                MemberRow(member: member, totalTarget: halaqa.totalTarget, unitName: halaqa.type.unitName)
            }
        }
        .padding(16)
        .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Update Section

    private var updateSection: some View {
        VStack(spacing: 14) {
            Text("تحديث تقدمك")
                .font(.headline)

            HStack(spacing: 20) {
                Button {
                    guard let member = halaqa.currentUserMember, member.progress > 0 else { return }
                    member.progress -= stepAmount
                    member.lastUpdated = .now
                    try? modelContext.save()
                    withAnimation { animatedProgress = halaqa.completionRatio }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title)
                        .foregroundStyle(AppPalette.streak)
                }

                VStack(spacing: 2) {
                    Text("\(halaqa.currentUserMember?.progress ?? 0)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())

                    Text(halaqa.type.unitName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 80)

                Button {
                    guard let member = halaqa.currentUserMember else { return }
                    member.progress += stepAmount
                    member.lastUpdated = .now
                    try? modelContext.save()
                    withAnimation { animatedProgress = halaqa.completionRatio }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundStyle(AppPalette.green)
                }
            }

            // Step picker
            HStack(spacing: 8) {
                Text("الخطوة:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach([1, 5, 10], id: \.self) { step in
                    Button {
                        stepAmount = step
                    } label: {
                        Text("+\(step)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(stepAmount == step ? .white : .secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(stepAmount == step ? AppPalette.green : AppPalette.card)
                            )
                    }
                }
            }
        }
        .padding(16)
        .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - MemberRow

private struct MemberRow: View {
    let member: HalaqaMember
    let totalTarget: Int
    let unitName: String

    private var ratio: Double {
        guard totalTarget > 0 else { return 0 }
        return min(Double(member.progress) / Double(totalTarget), 1.0)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(memberColor.gradient)
                        .frame(width: 32, height: 32)
                        .overlay {
                            Text(String(member.name.prefix(1)))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                        }

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Text(member.name)
                                .font(.subheadline.weight(.medium))
                            if member.isCurrentUser {
                                Text("(أنت)")
                                    .font(.caption2)
                                    .foregroundStyle(AppPalette.green)
                            }
                        }
                        Text("\(member.progress) \(unitName)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text("\(Int(ratio * 100))%")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(ratio >= 1 ? AppPalette.gold : .primary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))

                    Capsule()
                        .fill(memberColor.gradient)
                        .frame(width: geo.size.width * ratio)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 4)
    }

    private var memberColor: Color {
        member.isCurrentUser ? AppPalette.green : AppPalette.socialPurple
    }
}
