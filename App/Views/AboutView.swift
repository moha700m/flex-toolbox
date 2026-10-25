import SwiftUI

struct AboutView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.largeTitle).foregroundStyle(.white)
                            .frame(width: 64, height: 64)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.hero))
                        VStack(alignment: .leading) {
                            Text("عدّة فلكس").font(.hHeadline)
                            Text("v1.0 · iOS 17+").font(.hCaption).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 4)
                }
                Section("وش تسوي؟") {
                    Text("تفتح IPA وتعدّل Info.plist والملفات وتعيد تصديره، تتصفح ملفات التطبيق، تعدّل UserDefaults، تجرب طلبات HTTP، وتشوف معلومات الجهاز وHex.").font(.hBody)
                }
                Section("حدود صريحة") {
                    bullet("ما نقدر نفتح تطبيقات ثانية مثبتة — صندوق رمل iOS.")
                    bullet("تعديل IPA يكون على الملف اللي تفتحه، بعدين ترجعه لـ ESign بنفسك.")
                    bullet("تطبيقات App Store تحتاج IPA مفكوك التشفير — مو متوفر هنا.")
                    bullet("إضافة dylib للـ IPA ما تحقنها في الثنائي تلقائياً (تحتاج load command).")
                    bullet("لا تستخدمها للغش في الألعاب أونلاين أو التلاعب بحسابات/مدفوعات.")
                }
                Section("الترخيص") {
                    Text("الخط: IBM Plex Sans Arabic (OFL). ZIPFoundation (MIT). الكود: لك للاستخدام الشخصي.")
                        .font(.hCaption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("عنّا")
        }
    }
    private func bullet(_ t: String) -> some View {
        Label(t, systemImage: "exclamationmark.circle").font(.hCaption).fixedSize(horizontal: false, vertical: true)
    }
}
