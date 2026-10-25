import SwiftUI

@main
struct FlexToolboxApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar_SA"))
                .tint(Theme.navy)
        }
    }
}

struct RootView: View {
    @AppStorage("seenOnboard") private var seen = false
    var body: some View {
        Group {
            if seen { MainTabs() }
            else { OnboardView { seen = true } }
        }
    }
}

struct OnboardView: View {
    var onDone: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(Theme.hero).frame(width: 120, height: 120)
                Image(systemName: "wrench.and.screwdriver.fill").font(.system(size: 48)).foregroundStyle(.white)
            }
            Text("عدّة فلكس").font(.hTitle)
            Text("أدوات تفتيش وتعديل داخل حدود تطبيقك. تقدر تفتح IPA وتعدّل Info.plist وتعيد تصديره، وتتصفح ملفاتك، وتجرّب طلبات HTTP.")
                .font(.hBody).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 28)
            VStack(alignment: .leading, spacing: 10) {
                limitRow("ما نقدر نطلع على تطبيقات ثانية مثبتة — نظام iOS يمنع.")
                limitRow("نعدّل فقط IPAs اللي أنت تفتحها من الملفات ثم تعيدها لـ ESign.")
                limitRow("تطبيقات الـ App Store تحتاج IPA مفكوك، وهذا مو دورنا.")
            }.padding(.horizontal, 24)
            Spacer()
            Button("فهمت، يلا") { onDone() }.buttonStyle(PrimaryButton()).padding(.horizontal, 24)
            Text("إرشاد تقني، مو اختراق").font(.hCaption).foregroundStyle(.secondary).padding(.bottom, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
    }
    private func limitRow(_ t: String) -> some View {
        Label(t, systemImage: "exclamationmark.triangle.fill")
            .font(.hCaption).foregroundStyle(Theme.warn).fixedSize(horizontal: false, vertical: true)
    }
}

struct MainTabs: View {
    @State private var tab = UserDefaults.standard.string(forKey: "screen") ?? "home"
    var body: some View {
        TabView(selection: $tab) {
            HomeView().tabItem { Label("الرئيسية", systemImage: "house.fill") }.tag("home")
            IPAHubView().tabItem { Label("IPA", systemImage: "shippingbox.fill") }.tag("ipa")
            FilesHubView().tabItem { Label("ملفات", systemImage: "folder.fill") }.tag("files")
            ToolsHubView().tabItem { Label("أدوات", systemImage: "wrench.and.screwdriver") }.tag("tools")
            AboutView().tabItem { Label("عنّا", systemImage: "info.circle") }.tag("about")
        }
    }
}
