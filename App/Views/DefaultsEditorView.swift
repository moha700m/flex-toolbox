import SwiftUI

struct DefaultsEditorView: View {
    @State private var pairs: [(String, String)] = []
    @State private var newKey = ""
    @State private var newValue = ""
    @State private var message: String?

    var body: some View {
        List {
            Section {
                Text("هذي قيم UserDefaults الخاصة بتطبيق «عدّة فلكس» فقط. ما نقدر نقرأ تفضيلات تطبيقات ثانية.").font(.hCaption).foregroundStyle(.secondary)
            }
            Section("القيم") {
                ForEach(pairs, id: \.0) { pair in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(pair.0).font(.hCaption).foregroundStyle(Theme.navy)
                        TextField("قيمة", text: binding(for: pair.0))
                            .font(.hBody)
                            .onSubmit { save(pair.0) }
                        HStack {
                            Button("احفظ") { save(pair.0) }
                            Spacer()
                            Button("احذف", role: .destructive) { remove(pair.0) }
                        }.font(.hCaption)
                    }
                }
            }
            Section("أضف") {
                TextField("المفتاح", text: $newKey).font(.hBody)
                TextField("القيمة (نص)", text: $newValue).font(.hBody)
                Button("أضف") {
                    guard !newKey.isEmpty else { return }
                    UserDefaults.standard.set(newValue, forKey: newKey)
                    newKey = ""; newValue = ""; refresh()
                }
            }
            if let m = message { Section { Text(m).font(.hCaption) } }
        }
        .navigationTitle("UserDefaults")
        .onAppear(perform: refresh)
        .toolbar { Button("حدّث") { refresh() } }
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { pairs.first(where: { $0.0 == key })?.1 ?? "" },
            set: { v in
                if let i = pairs.firstIndex(where: { $0.0 == key }) { pairs[i].1 = v }
            })
    }

    private func refresh() {
        let dict = UserDefaults.standard.dictionaryRepresentation()
        let skip: Set<String> = ["AppleLanguages", "AppleLocale", "NSLanguages", "AddingEmojiKeybordHandled",
                                  "AKLastIDMSEnvironment", "CarCapabilities", "PKKeychainVersionKey"]
        pairs = dict.keys
            .filter { !skip.contains($0) && !$0.hasPrefix("com.apple.") && !$0.hasPrefix("NS") && !$0.hasPrefix("PK") }
            .sorted()
            .map { ($0, stringify(dict[$0]!)) }
    }

    private func stringify(_ v: Any) -> String {
        if let s = v as? String { return s }
        if let n = v as? NSNumber { return n.stringValue }
        if let d = try? JSONSerialization.data(withJSONObject: v, options: [.fragmentsAllowed]),
           let s = String(data: d, encoding: .utf8) { return s }
        return String(describing: v)
    }

    private func save(_ key: String) {
        let val = pairs.first(where: { $0.0 == key })?.1 ?? ""
        if let n = Int(val) { UserDefaults.standard.set(n, forKey: key) }
        else if val == "true" || val == "false" { UserDefaults.standard.set(val == "true", forKey: key) }
        else { UserDefaults.standard.set(val, forKey: key) }
        message = "حُفظ \(key)"
    }

    private func remove(_ key: String) {
        UserDefaults.standard.removeObject(forKey: key)
        refresh()
    }
}
