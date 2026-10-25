import SwiftUI

struct ToolsHubView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink { HTTPTesterView() } label: {
                    Label("مختبر HTTP", systemImage: "network")
                }
                NavigationLink { DeviceInfoView() } label: {
                    Label("معلومات الجهاز", systemImage: "iphone")
                }
                NavigationLink { HexPasteView() } label: {
                    Label("عارض Hex / نص", systemImage: "text.alignleft")
                }
            }
            .navigationTitle("أدوات")
        }
    }
}

struct HTTPTesterView: View {
    @State private var method = "GET"
    @State private var url = "https://httpbin.org/get"
    @State private var headers: [HTTPHeader] = [HTTPHeader(name: "Accept", value: "application/json")]
    @State private var body = ""
    @State private var result: HTTPResult?
    @State private var error: String?
    @State private var busy = false
    @State private var history: [String] = UserDefaults.standard.stringArray(forKey: "httpHistory") ?? []
    private let methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD"]

    var body: some View {
        Form {
            Section("الطلب") {
                Picker("الطريقة", selection: $method) { ForEach(methods, id: \.self) { Text($0) } }
                TextField("الرابط", text: $url).font(.mono).textInputAutocapitalization(.never).autocorrectionDisabled()
            }
            Section("الترويسات") {
                ForEach($headers) { $h in
                    HStack {
                        TextField("اسم", text: $h.name).font(.hCaption)
                        TextField("قيمة", text: $h.value).font(.hCaption)
                    }
                }
                .onDelete { headers.remove(atOffsets: $0) }
                Button("أضف ترويسة") { headers.append(HTTPHeader()) }
            }
            if method != "GET" && method != "HEAD" {
                Section("المحتوى") {
                    TextEditor(text: $body).font(.mono).frame(minHeight: 80)
                }
            }
            Section {
                Button {
                    Task { await send() }
                } label: {
                    if busy { ProgressView() } else { Label("أرسل", systemImage: "paperplane.fill") }
                }
                .disabled(busy)
            }
            if let r = result {
                Section("النتيجة — \(r.status) · \(r.durationMS)ms · \(IPATools.humanSize(r.byteCount))") {
                    DisclosureGroup("الترويسات") {
                        ForEach(r.headers.keys.sorted(), id: \.self) { k in
                            LabeledContent(k, value: r.headers[k] ?? "")
                        }
                    }
                    Text(r.prettyBody).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                }
            }
            if let e = error { Section { Text(e).foregroundStyle(Theme.danger) } }
            if !history.isEmpty {
                Section("السجل") {
                    ForEach(history, id: \.self) { h in
                        Button(h) { url = h }.font(.hCaption).foregroundStyle(.primary)
                    }
                    Button("امسح السجل", role: .destructive) {
                        history = []; UserDefaults.standard.set(history, forKey: "httpHistory")
                    }
                }
            }
        }
        .navigationTitle("HTTP")
    }

    private func send() async {
        busy = true; error = nil; result = nil
        let spec = HTTPRequestSpec(method: method, urlString: url, headers: headers, body: body)
        do {
            let r = try await HTTPClient.send(spec)
            result = r
            if !history.contains(url) {
                history.insert(url, at: 0)
                if history.count > 20 { history = Array(history.prefix(20)) }
                UserDefaults.standard.set(history, forKey: "httpHistory")
            }
        } catch { self.error = error.localizedDescription }
        busy = false
    }
}

struct DeviceInfoView: View {
    @State private var snap = DeviceInfo.snapshot()
    var body: some View {
        List {
            Section("الجهاز") {
                row("المعرّف", snap.model)
                row("الاسم", snap.name)
                row("النظام", snap.system)
                row("الشاشة", snap.screen)
            }
            Section("التخزين والذاكرة") {
                row("المساحة الكلية", DeviceInfo.humanBytes(snap.totalDisk))
                row("المساحة الحرة", DeviceInfo.humanBytes(snap.freeDisk))
                row("الذاكرة", DeviceInfo.humanBytes(Int64(snap.totalMemory)))
            }
            Section("أخرى") {
                row("البطارية", snap.battery < 0 ? "—" : "\(Int(snap.battery * 100))% · \(snap.batteryState)")
                row("اللغة", snap.locale)
                row("المنطقة الزمنية", snap.timezone)
            }
            Section {
                Text("هذي معلومات جهازك عبر واجهات النظام العامة. ما فيه أي وصول لجذر الجهاز.").font(.hCaption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("الجهاز")
        .toolbar { Button("حدّث") { snap = DeviceInfo.snapshot() } }
    }
    private func row(_ k: String, _ v: String) -> some View {
        LabeledContent(k) { Text(v).font(.hBody).textSelection(.enabled) }
    }
}

struct HexPasteView: View {
    @State private var input = ""
    @State private var hex = ""
    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $input).font(.hBody).frame(maxHeight: 160)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.3)))
                .padding(12)
            Button("حوّل لـ Hex") {
                hex = HexDump.make(Data(input.utf8))
            }.buttonStyle(PrimaryButton()).padding(.horizontal, 16)
            ScrollView {
                Text(hex.isEmpty ? "الصق نص أو اكتب شي فوق…" : hex)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .textSelection(.enabled)
            }
        }
        .navigationTitle("Hex / نص")
        .background(Color(uiColor: .systemGroupedBackground))
    }
}
