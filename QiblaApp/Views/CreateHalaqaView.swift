import SwiftUI
import SwiftData

// MARK: - CreateHalaqaView

struct CreateHalaqaView: View {
    enum Mode { case create, join }

    let mode: Mode
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Create fields
    @State private var halaqaName = ""
    @State private var selectedType: HalaqaType = .quranKhatma
    @State private var customTarget = ""
    @State private var userName: String = ""

    // Join fields
    @State private var joinCode = ""
    @State private var joinError: String?

    // Shared
    @State private var showingError = false

    var body: some View {
        NavigationStack {
            Form {
                if mode == .create {
                    createContent
                } else {
                    joinContent
                }

                // User name (shared)
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .foregroundStyle(AppPalette.green)
                            .frame(width: 24)
                        TextField("اسمك في الحلقة", text: $userName)
                    }
                } header: {
                    Text("اسمك")
                } footer: {
                    Text("سيظهر هذا الاسم للأعضاء الآخرين في الحلقة.")
                }
            }
            .navigationTitle(mode == .create ? "إنشاء حلقة" : "الانضمام لحلقة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode == .create ? "إنشاء" : "انضمام") {
                        mode == .create ? createHalaqa() : joinHalaqa()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
            .alert("خطأ", isPresented: $showingError) {
                Button("حسناً", role: .cancel) {}
            } message: {
                Text(joinError ?? "حدث خطأ غير معروف")
            }
            .onAppear {
                userName = UserDefaults.standard.string(forKey: "halaqaUserName") ?? ""
            }
        }
    }

    // MARK: - Create Content

    private var createContent: some View {
        Group {
            Section("تفاصيل الحلقة") {
                HStack(spacing: 12) {
                    Image(systemName: "text.cursor")
                        .foregroundStyle(AppPalette.green)
                        .frame(width: 24)
                    TextField("اسم الحلقة", text: $halaqaName)
                }
            }

            Section("نوع الحلقة") {
                Picker("النوع", selection: $selectedType) {
                    ForEach(HalaqaType.allCases) { type in
                        HStack {
                            Image(systemName: type.icon)
                            Text(type.rawValue)
                        }
                        .tag(type)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section {
                HStack(spacing: 12) {
                    Image(systemName: "target")
                        .foregroundStyle(AppPalette.gold)
                        .frame(width: 24)
                    TextField("الهدف (اختياري)", text: $customTarget)
                        .keyboardType(.numberPad)
                }
            } header: {
                Text("الهدف")
            } footer: {
                Text("الافتراضي: \(selectedType.defaultTarget) \(selectedType.unitName)")
            }
        }
    }

    // MARK: - Join Content

    private var joinContent: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .foregroundStyle(AppPalette.socialPurple)
                    .frame(width: 24)
                TextField("أدخل رمز الحلقة", text: $joinCode)
                    .textInputAutocapitalization(.characters)
                    .font(.title3.monospaced())
            }
        } header: {
            Text("رمز الحلقة")
        } footer: {
            Text("اطلب الرمز من صاحب الحلقة (٦ أحرف)")
        }
    }

    // MARK: - Validation

    private var isValid: Bool {
        if userName.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        if mode == .create {
            return !halaqaName.trimmingCharacters(in: .whitespaces).isEmpty
        } else {
            return joinCode.trimmingCharacters(in: .whitespaces).count == 6
        }
    }

    // MARK: - Actions

    private func createHalaqa() {
        let store = HalaqaStore(modelContext: modelContext)
        store.userName = userName
        let target = Int(customTarget) ?? selectedType.defaultTarget
        store.createHalaqa(
            name: halaqaName.trimmingCharacters(in: .whitespaces),
            type: selectedType,
            target: target,
            creatorName: userName.trimmingCharacters(in: .whitespaces)
        )
        dismiss()
    }

    private func joinHalaqa() {
        let store = HalaqaStore(modelContext: modelContext)
        store.userName = userName
        let result = store.joinHalaqa(
            code: joinCode.trimmingCharacters(in: .whitespaces),
            userName: userName.trimmingCharacters(in: .whitespaces)
        )
        switch result {
        case .success:
            dismiss()
        case .notFound:
            joinError = "لم يتم العثور على حلقة بهذا الرمز. تأكد من صحة الرمز وأعد المحاولة."
            showingError = true
        case .alreadyJoined:
            joinError = "أنت عضو بالفعل في هذه الحلقة."
            showingError = true
        }
    }
}

// MARK: - Preview

#Preview("Create") {
    CreateHalaqaView(mode: .create)
        .modelContainer(for: [Halaqa.self, HalaqaMember.self], inMemory: true)
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
        .preferredColorScheme(.dark)
}

#Preview("Join") {
    CreateHalaqaView(mode: .join)
        .modelContainer(for: [Halaqa.self, HalaqaMember.self], inMemory: true)
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
        .preferredColorScheme(.dark)
}
