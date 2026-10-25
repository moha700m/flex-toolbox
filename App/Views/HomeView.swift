import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("عدّة فلكس").font(.plex(26, .bold)).foregroundStyle(.white)
                            Text("تفتيش · تعديل · اختبار — داخل صندوق الرمل").font(.hCaption).foregroundStyle(.white.opacity(0.85))
                        }
                        Spacer()
                        Image(systemName: "wrench.and.screwdriver.fill").font(.system(size: 36)).foregroundStyle(Theme.accent)
                    }
                    .padding(20).background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.hero))

                    Text("وش تبي تسوي؟").font(.hHeadline)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        tile("IPA", "shippingbox.fill", "افتح وعدّل IPA", Theme.navy)
                        tile("ملفات", "folder.fill", "ملفات التطبيق", Theme.ok)
                        tile("HTTP", "network", "جرّب طلبات", Theme.accent)
                        tile("الجهاز", "iphone", "معلومات النظام", Theme.warn)
                    }
                    DisclaimerCard()
                }.padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("الرئيسية")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    private func tile(_ title: String, _ icon: String, _ sub: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.title2).foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 12).fill(tint.opacity(0.14)))
            Text(title).font(.hHeadline)
            Text(sub).font(.hCaption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .card()
    }
}

struct DisclaimerCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("حدود مهمة", systemImage: "lock.shield").font(.hHeadline).foregroundStyle(Theme.warn)
            Text("التطبيق يشتغل داخل صندوق رمل iOS. ما يقدر يقرأ أو يعدّل تطبيقات ثانية مثبتة على جوالك. التعديل يكون على ملف IPA تفتحه بنفسك ثم ترجعه لـ ESign.")
                .font(.hCaption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.card()
    }
}
