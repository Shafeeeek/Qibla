import Foundation
@preconcurrency import UserNotifications

// MARK: - NotificationService

final class NotificationService: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationService()
    
    private let tips = [
        "لا تنسَ ذكر الله، ألا بذكر الله تطمئن القلوب.",
        "صلِّ على النبي محمد ﷺ، من صلى عليه صلاة صلى الله عليه بها عشراً.",
        "جدد نيتك دائماً، إنما الأعمال بالنيات.",
        "الاستغفار يفتح الأبواب المغلقة ويجلب الرزق.",
        "حافظ على صلاتك، فهي عماد الدين وأول ما يُسأل عنه العبد.",
        "تبسمك في وجه أخيك صدقة، انشر الإيجابية لمن حولك.",
        "اقرأ وردك اليومي من القرآن، فهو نور لك في الدنيا والآخرة.",
        "الدعاء مخ العبادة، لا تتردد في مناجاة ربك.",
        "بر الوالدين من أعظم القربات إلى الله.",
        "الصدقة تطفئ غضب الرب وتدفع البلاء.",
        "حافظ على أذكار الصباح والمساء لتحفظك طوال اليوم.",
        "رضا الله في رضا الوالدين، احرص على برهما.",
        "تفاءل بالخير تجده، وأحسن الظن بالله دائماً.",
        "الكلمة الطيبة صدقة، فاحرص على انتقاء كلماتك.",
        "من لزم الاستغفار جعل الله له من كل هم فرجاً ومن كل ضيق مخرجاً.",
        "اجعل لك خبيئة من عمل صالح لا يعلمها إلا الله.",
        "الصلاة على وقتها من أحب الأعمال إلى الله.",
        "استحضر عظمة الله في كل خطوة تخطوها.",
        "القرآن الكريم شفاء لما في الصدور، فلا تهجره.",
        "صيام التطوع (كالإثنين والخميس) فيه أجر عظيم."
    ]
    
    /// Azkar to show in pre-Adhan reminders (10 min before prayer)
    private let preAdhanAzkar: [String: [String]] = [
        "الفجر": [
            "سبحان الله وبحمده، سبحان الله العظيم.",
            "اللهم إني أسألك علماً نافعاً ورزقاً طيباً وعملاً متقبلاً.",
            "أصبحنا وأصبح الملك لله، والحمد لله.",
            "اللهم بك أصبحنا وبك أمسينا وبك نحيا وبك نموت وإليك النشور."
        ],
        "الظهر": [
            "لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير.",
            "سبحان الله والحمد لله ولا إله إلا الله والله أكبر.",
            "اللهم صلِّ وسلم على نبينا محمد ﷺ.",
            "اللهم أعنّي على ذكرك وشكرك وحسن عبادتك."
        ],
        "العصر": [
            "أستغفر الله العظيم الذي لا إله إلا هو الحي القيوم وأتوب إليه.",
            "سبحان الله وبحمده، عدد خلقه ورضا نفسه وزنة عرشه ومداد كلماته.",
            "اللهم إني أعوذ بك من الهم والحزن والعجز والكسل.",
            "لا حول ولا قوة إلا بالله العلي العظيم."
        ],
        "المغرب": [
            "اللهم إني أسألك العفو والعافية في الدنيا والآخرة.",
            "أمسينا وأمسى الملك لله، والحمد لله.",
            "اللهم بك أمسينا وبك أصبحنا وبك نحيا وبك نموت وإليك المصير.",
            "اللهم ما أمسى بي من نعمة فمنك وحدك لا شريك لك."
        ],
        "العشاء": [
            "اللهم إني أعوذ بك من عذاب جهنم ومن عذاب القبر.",
            "اللهم قني عذابك يوم تبعث عبادك.",
            "بسم الله الذي لا يضر مع اسمه شيء في الأرض ولا في السماء وهو السميع العليم.",
            "اللهم عافني في بدني، اللهم عافني في سمعي، اللهم عافني في بصري."
        ]
    ]
    
    override private init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - Foreground Presentation Delegate
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Allow notifications to show as banners with sound even when the app is active
        completionHandler([.banner, .sound, .badge, .list])
    }
    
    // MARK: - Permissions
    
    func requestPermission(completion: @escaping @Sendable (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    func checkAuthorizationStatus(completion: @escaping @Sendable (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status = settings.authorizationStatus
            DispatchQueue.main.async {
                completion(status)
            }
        }
    }
    
    // MARK: - Test Notification
    
    func sendTestNotification(completion: (@Sendable (Bool) -> Void)? = nil) {
        let content = UNMutableNotificationContent()
        content.title = "قبلتي 🌙"
        content.body = "لا تنسَ ذكر الله، ألا بذكر الله تطمئن القلوب. (إشعار تجريبي يعمل بنجاح ✅)"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "test_notification_\(UUID().uuidString)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                completion?(error == nil)
            }
        }
    }
    
    // MARK: - Daily Tips Scheduling
    
    func scheduleDailyTips() {
        cancelDailyTips()
        
        let times: [(hour: Int, minute: Int)] = [(10, 0), (18, 0)] // 10 AM and 6 PM
        let calendar = Calendar.current
        let now = Date()
        
        // Schedule for today (if slot is in future) and next 30 days
        for day in 0...30 {
            guard let targetDate = calendar.date(byAdding: .day, value: day, to: now) else { continue }
            let calComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)
            
            for time in times {
                var dateComponents = DateComponents()
                dateComponents.year = calComponents.year
                dateComponents.month = calComponents.month
                dateComponents.day = calComponents.day
                dateComponents.hour = time.hour
                dateComponents.minute = time.minute
                
                // If scheduling for today, skip if the time has already passed
                if let scheduledDate = calendar.date(from: dateComponents), scheduledDate <= now {
                    continue
                }
                
                let content = UNMutableNotificationContent()
                content.title = "تذكير للمسلم 🌙"
                content.body = tips.randomElement() ?? tips[0]
                content.sound = .default
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
                let identifier = "tip_\(calComponents.year ?? 0)_\(calComponents.month ?? 0)_\(calComponents.day ?? 0)_\(time.hour)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                
                UNUserNotificationCenter.current().add(request)
            }
        }
    }
    
    func cancelDailyTips() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let tipIds = requests.map(\.identifier).filter { $0.hasPrefix("tip_") }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: tipIds)
        }
    }
    
    // MARK: - Prayer Times Scheduling
    
    func schedulePrayerNotifications(items: [PrayerTime]) {
        cancelPrayerNotifications()
        
        let now = Date()
        let calendar = Calendar.current
        
        for item in items {
            // Only schedule for future prayers today
            guard item.date > now else { continue }
            // Do not schedule sunrise as prayer call
            if item.name == "الشروق" { continue }
            
            let content = UNMutableNotificationContent()
            content.title = "حان الآن موعد صلاة \(item.name) 🕌"
            if item.name == "الفجر" {
                content.body = "الصلاة خيرٌ من النوم.. بارك الله في يومك."
            } else {
                content.body = "حي على الصلاة، حي على الفلاح."
            }
            content.sound = .default
            
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let identifier = "prayer_\(item.id)_\(comps.year ?? 0)_\(comps.month ?? 0)_\(comps.day ?? 0)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    func cancelPrayerNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let prayerIds = requests.map(\.identifier).filter { $0.hasPrefix("prayer_") }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: prayerIds)
        }
    }
    
    // MARK: - Pre-Adhan Reminders (10 minutes before)
    
    func schedulePreAdhanReminders(items: [PrayerTime]) {
        cancelPreAdhanReminders()
        
        let now = Date()
        let calendar = Calendar.current
        let reminderMinutes: TimeInterval = -10 * 60 // 10 minutes before
        
        for item in items {
            // Skip sunrise — not a prayer
            if item.name == "الشروق" { continue }
            
            // Calculate the reminder time (10 min before)
            let reminderDate = item.date.addingTimeInterval(reminderMinutes)
            
            // Only schedule if the reminder time is still in the future
            guard reminderDate > now else { continue }
            
            let content = UNMutableNotificationContent()
            content.title = "باقي ١٠ دقائق على أذان \(item.name) 🕌"
            
            // Pick a random dhikr for this prayer
            let azkarList = preAdhanAzkar[item.name] ?? preAdhanAzkar["الظهر"]!
            content.body = azkarList.randomElement() ?? azkarList[0]
            content.sound = .default
            
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let identifier = "preprayer_\(item.id)_\(comps.year ?? 0)_\(comps.month ?? 0)_\(comps.day ?? 0)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    func cancelPreAdhanReminders() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix("preprayer_") }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
