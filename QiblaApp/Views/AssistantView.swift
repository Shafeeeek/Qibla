import SwiftUI

// MARK: - AssistantView

struct AssistantView: View {
    @State private var gemini = GeminiService()
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    // Quick suggestion chips
    private let suggestions = [
        "ما حكم الجمع بين الصلاتين؟",
        "أذكار الصباح",
        "حديث عن فضل الصلاة",
        "كيف أحسب زكاة المال؟",
        "دعاء الاستخارة",
        "تفسير سورة الفاتحة"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if gemini.messages.isEmpty {
                    welcomeView
                } else {
                    chatList
                }

                inputBar
            }
            .background(AppPalette.background)
            .navigationTitle("مساعد قبلتي")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !gemini.messages.isEmpty {
                        Button(role: .destructive) {
                            withAnimation { gemini.clearChat() }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Welcome View

    private var welcomeView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 30)

                // Icon
                ZStack {
                    Circle()
                        .fill(AppPalette.green.opacity(0.12))
                        .frame(width: 90, height: 90)
                    Image(systemName: "sparkle")
                        .font(.system(size: 38))
                        .foregroundStyle(AppPalette.green)
                }

                VStack(spacing: 8) {
                    Text("مساعد قبلتي الذكي")
                        .font(.title2.weight(.bold))

                    Text("اسألني عن الفقه والعبادات والأحاديث والأذكار")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Suggestion chips
                VStack(spacing: 10) {
                    Text("جرّب أن تسأل:")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tertiary)

                    FlowLayout(spacing: 8) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button {
                                inputText = suggestion
                                sendMessage()
                            } label: {
                                Text(suggestion)
                                    .font(.caption)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .foregroundStyle(AppPalette.green)
                                    .background(
                                        AppPalette.green.opacity(0.1),
                                        in: Capsule()
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(AppPalette.green.opacity(0.2), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Features list
                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(icon: "book.fill", color: AppPalette.green, title: "الفقه والعبادات", subtitle: "أحكام الصلاة والوضوء والزكاة")
                    FeatureRow(icon: "text.quote", color: AppPalette.gold, title: "الأحاديث النبوية", subtitle: "بحث وشرح مع ذكر المصادر")
                    FeatureRow(icon: "sparkles", color: AppPalette.socialPurple, title: "الأذكار والأدعية", subtitle: "أذكار مناسبة لكل موقف")
                    FeatureRow(icon: "book.closed.fill", color: AppPalette.chartMaghrib, title: "تفسير القرآن", subtitle: "شرح الآيات وتفسيرها")
                }
                .padding(16)
                .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 20)

                Spacer().frame(height: 20)
            }
        }
    }

    // MARK: - Chat List

    private var chatList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(gemini.messages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: gemini.messages)
                    }

                    if gemini.isLoading {
                        HStack(spacing: 8) {
                            TypingIndicator()
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .id("loading")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            .onChange(of: gemini.messages.count) { _, _ in
                withAnimation {
                    if gemini.isLoading {
                        proxy.scrollTo("loading", anchor: .bottom)
                    } else if let lastId = gemini.messages.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 10) {
                // Text field
                HStack(spacing: 8) {
                    TextField("اكتب سؤالك هنا...", text: $inputText, axis: .vertical)
                        .lineLimit(1...4)
                        .focused($isInputFocused)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                // Send button
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(canSend ? AppPalette.green : .gray.opacity(0.3))
                        .rotationEffect(.degrees(180)) // Flip for RTL feel
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !gemini.isLoading
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        Task {
            await gemini.send(text)
        }
    }
}

// MARK: - ChatBubble

private struct ChatBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isUser { Spacer(minLength: 50) }

            if !isUser {
                // Assistant avatar
                ZStack {
                    Circle()
                        .fill(AppPalette.green.opacity(0.15))
                        .frame(width: 30, height: 30)
                    Image(systemName: "sparkle")
                        .font(.caption)
                        .foregroundStyle(AppPalette.green)
                }
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.subheadline)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .foregroundStyle(isUser ? .white : .primary)
                    .background(
                        isUser
                            ? AnyShapeStyle(LinearGradient(
                                colors: [AppPalette.green, AppPalette.green.opacity(0.8)],
                                startPoint: .topTrailing,
                                endPoint: .bottomLeading
                              ))
                            : AnyShapeStyle(AppPalette.card),
                        in: BubbleShape(isUser: isUser)
                    )
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = message.content
                        } label: {
                            Label("نسخ", systemImage: "doc.on.doc")
                        }
                        
                        ShareLink(item: message.content) {
                            Label("مشاركة", systemImage: "square.and.arrow.up")
                        }
                    }

                Text(timeString(message.timestamp))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
            }

            if !isUser { Spacer(minLength: 50) }
        }
        .transition(.asymmetric(
            insertion: .scale(scale: 0.8, anchor: isUser ? .bottomTrailing : .bottomLeading).combined(with: .opacity),
            removal: .opacity
        ))
    }

    private func timeString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ar")
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }
}

// MARK: - BubbleShape

private struct BubbleShape: Shape {
    let isUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
        let tailRadius: CGFloat = 6
        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .path(in: rect)
            // Simplified: we use standard rounded rect for both sides
            // The visual distinction comes from color + alignment
    }
}

// MARK: - TypingIndicator

private struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(AppPalette.green.opacity(0.5))
                    .frame(width: 7, height: 7)
                    .offset(y: animating ? -4 : 4)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever()
                        .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear { animating = true }
    }
}

// MARK: - FeatureRow

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - FlowLayout

/// Simple horizontal wrapping layout for suggestion chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .init(frame.size))
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), frames)
    }
}

// APIKeySheet Removed

// MARK: - Preview

#Preview {
    AssistantView()
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
        .preferredColorScheme(.dark)
}
