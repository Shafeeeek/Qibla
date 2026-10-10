import SwiftUI
import UIKit

// MARK: - SettingsView

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var testNotificationSent = false

    private var lm: LocationManager { appState.locationManager }

    private var locationLabel: String {
        if lm.cityName.isEmpty {
            switch lm.authorizationStatus {
            case .notDetermined:       return "لم يُحدد بعد"
            case .denied, .restricted: return "غير مصرح — اضغط لفتح الإعدادات"
            default:                   return "جاري التحديد…"
            }
        }
        return lm.countryName.isEmpty
            ? lm.cityName
            : "\(lm.cityName)، \(lm.countryName)"
    }

    var body: some View {
        NavigationStack {
            Form {
                // ── Location ──────────────────────────────────────────────
                Section("الموقع") {
                    SettingsRow(
                        title: "الموقع الحالي",
                        value: locationLabel,
                        systemImage: "mappin.circle.fill",
                        color: AppPalette.gold
                    )

                    if lm.authorizationStatus == .denied ||
                       lm.authorizationStatus == .restricted {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label("فتح إعدادات الموقع", systemImage: "gear")
                                .foregroundStyle(AppPalette.gold)
                        }
                    }
                }

                // ── Calculation method ────────────────────────────────────
                Section("طريقة حساب المواقيت") {
                    Picker(
                        "طريقة الحساب",
                        selection: Binding(
                            get: { appState.calculationMethod },
                            set: { appState.calculationMethod = $0 }
                        )
                    ) {
                        ForEach(CalculationMethod.allCases) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                // ── Notifications ─────────────────────────────────────────
                Section {
                    Toggle(isOn: Binding(
                        get: { appState.prayerNotificationsEnabled },
                        set: { appState.setPrayerNotifications(enabled: $0) }
                    )) {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                                .foregroundStyle(AppPalette.green)
                                .imageScale(.large)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("تنبيهات مواقيت الصلاة")
                                    .font(.body)
                                Text("إشعار وتنبيه عند دخول وقت كل صلاة")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(AppPalette.gold)

                    Toggle(isOn: Binding(
                        get: { appState.preAdhanRemindersEnabled },
                        set: { appState.setPreAdhanReminders(enabled: $0) }
                    )) {
                        HStack {
                            Image(systemName: "clock.badge")
                                .foregroundStyle(AppPalette.gold)
                                .imageScale(.large)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("أذكار قبل الأذان")
                                    .font(.body)
                                Text("إشعار بذكر وتذكير قبل كل أذان بعشر دقائق")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(AppPalette.gold)

                    Toggle(isOn: Binding(
                        get: { appState.tipsNotificationsEnabled },
                        set: { appState.setTipsNotifications(enabled: $0) }
                    )) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(AppPalette.gold)
                                .imageScale(.large)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("نصائح وإرشادات يومية")
                                    .font(.body)
                                Text("تذكير بذكر الله وأحاديث نبوية مرتين يومياً")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(AppPalette.gold)

                    Button {
                        NotificationService.shared.sendTestNotification { success in
                            Task { @MainActor in
                                if success {
                                    withAnimation {
                                        testNotificationSent = true
                                    }
                                    try? await Task.sleep(for: .seconds(3))
                                    withAnimation {
                                        testNotificationSent = false
                                    }
                                } else {
                                    appState.showNotificationPermissionAlert = true
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: testNotificationSent ? "checkmark.circle.fill" : "bell.badge")
                                .foregroundStyle(testNotificationSent ? AppPalette.green : AppPalette.gold)
                                .imageScale(.large)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(testNotificationSent ? "تم إرسال الإشعار التجريبي بنجاح" : "إرسال إشعار تجريبي (فحص)")
                                    .font(.body)
                                    .foregroundStyle(testNotificationSent ? AppPalette.green : AppPalette.gold)
                                Text("اضغط هنا لتجربة وصول التنبيهات إلى جهازك")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("الإشعارات والتنبيهات")
                } footer: {
                    Text("يمكنك الضغط على زر الفحص للتأكد من وصول الإشعارات وظهورها على هاتفك فوراً.")
                        .font(.caption2)
                }

                // ── App Info & Developer ──────────────────────────────────
                Section("عن التطبيق والمطور") {
                    SettingsRow(
                        title: "إصدار التطبيق",
                        value: "1.0.0",
                        systemImage: "info.circle.fill",
                        color: AppPalette.gold
                    )

                    SettingsRow(
                        title: "المطور",
                        value: "Shafeek Tech",
                        systemImage: "chevron.left.forwardslash.chevron.right",
                        color: AppPalette.green
                    )
                }

                // ── Legal, Terms & Copyright (Shafeek Tech) ───────────────
                Section {
                    NavigationLink {
                        CopyrightView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "c.circle.fill")
                                .foregroundStyle(AppPalette.gold)
                                .imageScale(.large)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("حقوق الملكية الفكرية")
                                    .font(.body)
                                Text("© Shafeek Tech — جميع الحقوق محفوظة")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    NavigationLink {
                        TermsOfServiceView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text.fill")
                                .foregroundStyle(AppPalette.gold)
                                .imageScale(.large)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("شروط وبنود الاستخدام")
                                    .font(.body)
                                Text("الاتفاقية والأحكام العامة للاستخدام")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "hand.raised.fill")
                                .foregroundStyle(AppPalette.green)
                                .imageScale(.large)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("سياسة الخصوصية وحماية البيانات")
                                    .font(.body)
                                Text("معالجة الموقع الجغرافي محلياً 100%")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    NavigationLink {
                        LicensesView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                                .foregroundStyle(AppPalette.gold)
                                .imageScale(.large)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("التراخيص والبرمجيات المفتوحة")
                                    .font(.body)
                                Text("تراخيص البرمجيات والمكتبات المعتمدة")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("الحقوق والبنود القانونية")
                } footer: {
                    VStack(alignment: .center, spacing: 6) {
                        Text("تم تطوير وتصميم التطبيق بعناية بواسطة Shafeek Tech")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)

                        Text("Shafeek Tech © 2025 All Rights Reserved")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(AppPalette.gold.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("الإعدادات")
            .alert("الإشعارات غير مفعلة", isPresented: Bindable(appState).showNotificationPermissionAlert) {
                Button("فتح إعدادات النظام") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) ?? URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("إلغاء", role: .cancel) {}
            } message: {
                Text("يرجى منح إذن الإشعارات لتطبيق قبلتي من إعدادات جهازك لتصلك تنبيهات الصلاة والنصائح اليومية.")
            }
        }
    }
}

// MARK: - SettingsRow

private struct SettingsRow: View {
    let title:       String
    var value:       String?
    let systemImage: String
    let color:       Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .imageScale(.large)
                .frame(width: 24)

            Text(title)

            Spacer()

            if let value {
                Text(value)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Copyright View (Shafeek Tech)

private struct CopyrightView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    RubElHizbShape()
                        .stroke(AppPalette.gold, lineWidth: 1.5)
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "c.circle.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppPalette.gold)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Shafeek Tech")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppPalette.gold)
                        Text("حقوق الملكية الفكرية والعلامة التجارية")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 6)

                Divider().overlay(AppPalette.cardBorder)

                legalParagraph(
                    title: "ملكية التطبيق والمحتوى",
                    bodyText: "كافة حقوق الملكية الفكرية، بما في ذلك البرمجيات، الأكواد المصدرية، التصاميم البصرية، الهوية الفنية، والواجهات الرسومية الخاصة بهذا التطبيق، مملوكة بالكامل وحصرياً لـ Shafeek Tech ومحمية بموجب قوانين الملكية الفكرية وحقوق المؤلف والمعاهدات الدولية ذات الصلة."
                )

                legalParagraph(
                    title: "العلامات التجارية",
                    bodyText: "اسم \"Shafeek Tech\" والشعارات والتصاميم المرتبطة بها هي علامات تجارية مسجلة أو محمية لصالح Shafeek Tech. يُحظر نسخها، تكرارها، أو استخدامها بأي شكل من الأشكال دون إذن خطي مسبق."
                )

                legalParagraph(
                    title: "حماية الشفرة البرمجية",
                    bodyText: "لا يجوز الهندسة العكسية للتطبيق أو فك تجميعه أو اقتباس أجزاء من الكود المصدري أو إنشاء أعمال مشتقة منه دون موافقة صريحة من Shafeek Tech."
                )

                Spacer()
            }
            .padding(20)
        }
        .background(AppPalette.background.ignoresSafeArea())
        .navigationTitle("حقوق الملكية")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Terms Of Service View

private struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.plaintext.fill")
                        .font(.title)
                        .foregroundStyle(AppPalette.gold)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("شروط وبنود الاستخدام")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.white)
                        Text("اتفاقية المستخدم — Shafeek Tech")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 6)

                Divider().overlay(AppPalette.cardBorder)

                legalParagraph(
                    title: "١. القبول بالبنود والشروط",
                    bodyText: "باستخدامك لهذا التطبيق المقدم من Shafeek Tech، فإنك تقر وتوافق على الالتزام الكامل بكافة البنود والشروط الموضحة هنا. إذا كنت لا توافق على هذه البنود، فيُرجى التوقف عن استخدام التطبيق."
                )

                legalParagraph(
                    title: "٢. طبيعة الخدمة ودقة الحسابات",
                    bodyText: "يقوم التطبيق بحساب مواقيت الصلاة واتجاه القبلة بناءً على الإحداثيات الجغرافية وخوارزميات الحساب الفلكية المعتمدة عالمياً (مثل الهيئة المصرية العامة للمساحة، أم القرى، وغيرها). بالرغم من حرص Shafeek Tech على تحري أعلى درجات الدقة، فإن النتائج تظل إرشادية وتخضع لدقة حساسات الجهاز ومجاله المغناطيسي المحيط."
                )

                legalParagraph(
                    title: "٣. الاستخدام المشروع والتعبدي",
                    bodyText: "تم تطوير هذا التطبيق كأداة إسلامية غير ربحية وتعبدية لمساعدة المسلمين في أداء الصلاة والتعرف على القبلة. يُمنع استغلال التطبيق في أي أغراض تخالف القوانين أو الآداب العامة."
                )

                legalParagraph(
                    title: "٤. التحديثات والتعديلات",
                    bodyText: "تحتفظ Shafeek Tech بالحق في تحسين، تعديل، أو تحديث مزايا التطبيق وشروطه من وقت لآخر لضمان جودة الأداء ومواكبة أحدث معايير الأمان ونظام iOS."
                )

                Spacer()
            }
            .padding(20)
        }
        .background(AppPalette.background.ignoresSafeArea())
        .navigationTitle("شروط الاستخدام")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Privacy Policy View

private struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.title)
                        .foregroundStyle(AppPalette.green)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("سياسة الخصوصية")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.white)
                        Text("حماية البيانات والخصوصية لدى Shafeek Tech")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 6)

                Divider().overlay(AppPalette.cardBorder)

                legalParagraph(
                    title: "١. احترام الخصوصية التام",
                    bodyText: "في Shafeek Tech، نضع خصوصيتك في مقدمة أولوياتنا. هذا التطبيق مصمم ليعمل بمبدأ الخصوصية أولاً (Privacy by Design)، حيث لا نقوم بجمع أو حفظ أو بيع أي بيانات تعريف شخصية."
                )

                legalParagraph(
                    title: "٢. استخدام بيانات الموقع الجغرافي",
                    bodyText: "يحتاج التطبيق إلى إذن الموقع الجغرافي حصراً لغرضين محددين: تحديد زاوية القبلة الدقيقة وحساب مواقيت الصلوات الخمس. تتم جميع الحسابات محلياً على جهازك ولا يتم إرسال موقعك الجغرافي إطلاقاً إلى أي خوادم خارجية."
                )

                legalParagraph(
                    title: "٣. الإشعارات المحلية",
                    bodyText: "تتم جدولة تنبيهات الأذان والأذكار عبر نظام التشغيل الداخلي لجهازك (Local Notifications) دون الحاجة لأي خادم وسيط أو معالجة خارجية."
                )

                legalParagraph(
                    title: "٤. أمان البيانات",
                    bodyText: "لا توجد أي أدوات تتبع (Trackers) أو إعلانات تجارية داخل التطبيق لضمان تجربة روحانية آمنة وخالية تماماً من المشتتات."
                )

                Spacer()
            }
            .padding(20)
        }
        .background(AppPalette.background.ignoresSafeArea())
        .navigationTitle("سياسة الخصوصية")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Licenses View

private struct LicensesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title)
                        .foregroundStyle(AppPalette.gold)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("التراخيص البرمجية")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.white)
                        Text("Shafeek Tech Open Source Notices")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 6)

                Divider().overlay(AppPalette.cardBorder)

                legalParagraph(
                    title: "ترخيص التطبيق",
                    bodyText: "هذا التطبيق مرخص ومحمي بموجب حقوق الطبع والنشر الخاصة بـ Shafeek Tech. جميع الحقوق محفوظة لعام 2025."
                )

                legalParagraph(
                    title: "الخوارزميات الفلكية المعتمدة",
                    bodyText: "تعتمد حسابات زوايا ميل الشمس ومواقع الأجرام السماوية على صيغ ومعادلات فلكية رياضية دقيقة مبنية على أعمال جان ميوس (Jean Meeus) في الحسابات الفلكية، معتمدة ومطابقة لمواقيت الهيئات الإسلامية الرسمية."
                )

                legalParagraph(
                    title: "أطر عمل Apple المعتمدة",
                    bodyText: "تم بناء التطبيق باستخدام أحدث تقنيات وأطر عمل Apple الرسمية: SwiftUI, CoreLocation, SwiftData, و WidgetKit مع مراعاة أعلى معايير الجودة والأداء."
                )

                Spacer()
            }
            .padding(20)
        }
        .background(AppPalette.background.ignoresSafeArea())
        .navigationTitle("التراخيص")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Helper Function for Legal Paragraphs

private func legalParagraph(title: String, bodyText: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(.headline.weight(.semibold))
            .foregroundStyle(AppPalette.goldLight)

        Text(bodyText)
            .font(.callout)
            .foregroundStyle(Color.white.opacity(0.85))
            .lineSpacing(4)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(AppPalette.cardBorder, lineWidth: 0.8)
    )
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(AppState())
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
        .preferredColorScheme(.dark)
}
