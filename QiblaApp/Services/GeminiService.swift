import Foundation

// MARK: - ChatMessage

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp: Date

    enum Role: String {
        case user
        case assistant
        case system
    }

    init(role: Role, content: String, timestamp: Date = .now) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

// MARK: - GeminiService

/// Lightweight service that calls the Gemini REST API directly.
@MainActor
@Observable
final class GeminiService {

    var isLoading = false
    var messages: [ChatMessage] = []

    private let defaultAPIKey = "AIzaSyCv5WOTguuvZ6etSJW4IC2Ok-rhAOOz6Vk"
    private let primaryModel = "gemini-3.6-flash"
    private let fallbackModels = ["gemini-3.5-flash"]

    private var currentApiKey: String {
        let userKey = UserDefaults.standard.string(forKey: "gemini_api_key")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return userKey.isEmpty ? defaultAPIKey : userKey
    }

    private let systemInstruction = """
    أنت مساعد إسلامي متخصص يعمل داخل تطبيق "قبلتي".

    ## هويتك
    - اسمك "مساعد قبلتي" وأنت مساعد ذكي في الشؤون الإسلامية.
    - تجيب باللغة العربية دائماً.
    - أسلوبك ودود ومحترم ومبسّط.

    ## تخصصاتك
    1. الفقه والعبادات: الإجابة عن أسئلة الصلاة والوضوء والطهارة والزكاة والصيام والحج.
    2. الأحاديث النبوية: البحث عن أحاديث وشرحها مع ذكر المصدر (البخاري، مسلم، الترمذي، إلخ).
    3. الأذكار والأدعية: اقتراح أذكار مناسبة للمواقف المختلفة.
    4. القرآن الكريم: شرح الآيات وتفسيرها.
    5. النصائح الإيمانية: تقديم نصائح عملية للالتزام بالعبادات.

    ## قواعد مهمة
    - إذا لم تكن متأكداً من حكم فقهي، قل "الله أعلم" واقترح مراجعة عالم متخصص.
    - اذكر المصادر والمراجع عند الإمكان.
    - لا تفتي في المسائل الخلافية المعقدة، بل اعرض آراء المذاهب المختلفة بحياد.
    - لا تجب على أسئلة خارج نطاق تخصصك (السياسة، الطب، إلخ). وجّه المستخدم بلطف.
    - اختصر الإجابات ما أمكن مع الحفاظ على الدقة.
    - استخدم الإيموجي بشكل خفيف لتحسين القراءة (📖 🕌 🤲 ✨).
    """

    // MARK: - Send Message

    func send(_ text: String) async {
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        isLoading = true

        defer { isLoading = false }
        do {
            let reply = try await callGeminiAPI(messages: messages)
            messages.append(ChatMessage(role: .assistant, content: reply))
        } catch {
            messages.append(ChatMessage(role: .assistant, content: "❌ حدث خطأ: \(error.localizedDescription)\n\nتأكد من صحة مفتاح API واتصال الإنترنت."))
        }
    }

    // MARK: - Clear Chat

    func clearChat() {
        messages.removeAll()
    }

    // MARK: - Gemini REST API Call

    private func callGeminiAPI(messages: [ChatMessage]) async throws -> String {
        let modelsToTry = [primaryModel] + fallbackModels
        var lastError: Error = GeminiError.invalidResponse

        for model in modelsToTry {
            do {
                return try await requestGeneration(model: model, messages: messages)
            } catch let error as GeminiError {
                lastError = error
                switch error {
                case .rateLimited, .serverError:
                    // Try next model if service is overloaded or rate limited
                    continue
                default:
                    throw error
                }
            } catch {
                lastError = error
                throw error
            }
        }

        throw lastError
    }

    private func requestGeneration(model: String, messages: [ChatMessage]) async throws -> String {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(currentApiKey)") else {
            throw GeminiError.invalidURL
        }

        // Build conversation contents for Gemini REST API
        var contents: [[String: Any]] = []
        for msg in messages {
            let role: String
            switch msg.role {
            case .user: role = "user"
            case .assistant: role = "model"
            case .system: continue
            }
            contents.append([
                "role": role,
                "parts": [["text": msg.content]]
            ])
        }

        let requestBody: [String: Any] = [
            "system_instruction": [
                "parts": [["text": systemInstruction]]
            ],
            "contents": contents,
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 2048
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            if httpResponse.statusCode == 400 {
                throw GeminiError.badRequest(errorBody)
            } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw GeminiError.unauthorized
            } else if httpResponse.statusCode == 429 {
                throw GeminiError.rateLimited
            } else {
                throw GeminiError.serverError(httpResponse.statusCode, errorBody)
            }
        }

        // Parse response from Gemini API
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw GeminiError.parsingFailed
        }

        let texts = parts.compactMap { $0["text"] as? String }
        let reply = texts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !reply.isEmpty else {
            throw GeminiError.parsingFailed
        }

        return reply
    }
}

// MARK: - GeminiError

enum GeminiError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case rateLimited
    case badRequest(String)
    case serverError(Int, String)
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:           return "رابط API غير صحيح"
        case .invalidResponse:      return "استجابة غير متوقعة من الخادم"
        case .unauthorized:         return "مفتاح API غير صحيح أو منتهي الصلاحية"
        case .rateLimited:          return "تم تجاوز حد الاستخدام. حاول مرة أخرى لاحقاً"
        case .badRequest(let msg):  return "طلب غير صحيح: \(msg.prefix(100))"
        case .serverError(let c, _): return "خطأ في الخادم (رمز \(c))"
        case .parsingFailed:        return "فشل في قراءة الرد"
        }
    }
}
