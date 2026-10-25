import SwiftUI
import UniformTypeIdentifiers

struct IPAHubView: View {
    @State private var picking = false
    @State private var bundle: IPABundle?
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Group {
                if let b = bundle {
                    IPADetailView(bundle: b, onClose: { IPATools.cleanup(b); bundle = nil })
                } else {
                    empty
                }
            }
            .navigationTitle("مفتش IPA")
            .fileImporter(isPresented: $picking, allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .data]) { result in
                switch result {
                case .success(let url): open(url)
                case .failure(let e): error = e.localizedDescription
                }
            }
            .overlay { if busy { ProgressView("نفك الضغط…").padding().background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16)) } }
            .alert("خطأ", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("حسناً", role: .cancel) {}
            } message: { Text(error ?? "") }
            .onAppear {
                if UserDefaults.standard.bool(forKey: "demoIPA"), bundle == nil {
                    // CI screenshots stay on empty state with clear copy.
                }
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 18) {
            Image(systemName: "shippingbox.fill").font(.system(size: 64)).foregroundStyle(Theme.navy)
            Text("افتح ملف IPA").font(.hTitle)
            Text("من تطبيق الملفات. بنفكّه، نعرض Info.plist والأطر والملفات، وتقدر تعدّل وتعيد التصدير لـ ESign.")
                .font(.hBody).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 28)
            Button { picking = true } label: { Label("اختر IPA", systemImage: "doc.badge.plus") }
                .buttonStyle(PrimaryButton()).padding(.horizontal, 40)
            DisclaimerCard().padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
    }

    private func open(_ url: URL) {
        busy = true
        Task.detached {
            do {
                let b = try IPATools.open(url)
                await MainActor.run { bundle = b; busy = false }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; busy = false }
            }
        }
    }
}

struct IPADetailView: View {
    let bundle: IPABundle
    var onClose: () -> Void
    @State private var dict: [String: Any]
    @State private var displayName: String
    @State private var bundleID: String
    @State private var version: String
    @State private var build: String
    @State private var entries: [IPAFileEntry]
    @State private var share: SharePayload?
    @State private var message: String?
    @State private var addingFile = false
    @State private var filter = ""

    init(bundle: IPABundle, onClose: @escaping () -> Void) {
        self.bundle = bundle
        self.onClose = onClose
        _dict = State(initialValue: bundle.infoDict)
        let s = bundle.summary
        _displayName = State(initialValue: s.displayName)
        _bundleID = State(initialValue: s.bundleID)
        _version = State(initialValue: s.version)
        _build = State(initialValue: s.build)
        _entries = State(initialValue: bundle.entries)
    }

    private var filtered: [IPAFileEntry] {
        filter.isEmpty ? entries : entries.filter { $0.path.localizedCaseInsensitiveContains(filter) }
    }

    var body: some View {
        List {
            Section("ملخص") {
                LabeledContent("التطبيق", value: bundle.appName)
                LabeledContent("الحجم الإجمالي", value: IPATools.humanSize(entries.reduce(0) { $0 + $1.size }))
                LabeledContent("أدنى iOS", value: bundle.summary.minOS.isEmpty ? "—" : bundle.summary.minOS)
            }
            Section("عدّل Info.plist") {
                TextField("اسم العرض", text: $displayName).font(.hBody)
                TextField("معرف الحزمة", text: $bundleID).font(.mono)
                TextField("الإصدار", text: $version).font(.hBody)
                TextField("رقم البناء", text: $build).font(.hBody)
                Button { applyEdits() } label: { Label("احفظ التعديلات في الـ IPA", systemImage: "checkmark.circle.fill") }
            }
            Section("الصلاحيات (\(bundle.summary.permissions.count))") {
                if bundle.summary.permissions.isEmpty { Text("ما فيه").foregroundStyle(.secondary) }
                ForEach(bundle.summary.permissions, id: \.0) { p in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(p.0).font(.hCaption).foregroundStyle(Theme.navy)
                        Text(p.1).font(.hBody)
                    }
                }
            }
            Section("URL Schemes") {
                if bundle.summary.urlSchemes.isEmpty { Text("ما فيه").foregroundStyle(.secondary) }
                ForEach(bundle.summary.urlSchemes, id: \.self) { Text($0).font(.mono) }
            }
            Section("الأطر وملفات dylib") {
                if bundle.dylibs.isEmpty { Text("ما لقينا").foregroundStyle(.secondary) }
                ForEach(bundle.dylibs, id: \.self) { Text($0.replacingOccurrences(of: "Payload/\(bundle.appName)/", with: "")).font(.hCaption) }
            }
            if let ents = bundle.entitlementsXML {
                Section("Entitlements") {
                    Text(ents).font(.mono).textSelection(.enabled)
                }
            } else {
                Section("Entitlements") { Text("غير موجودة (IPA غير موقّع غالباً)").foregroundStyle(.secondary) }
            }
            Section {
                ForEach(filtered.prefix(400)) { e in
                    HStack {
                        Image(systemName: e.isDirectory ? "folder.fill" : "doc")
                            .foregroundStyle(e.isDirectory ? Theme.warn : Theme.navy)
                        VStack(alignment: .leading) {
                            Text(e.path).font(.hCaption).lineLimit(2)
                            if !e.isDirectory { Text(IPATools.humanSize(e.size)).font(.plex(11)).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        if !e.isDirectory && !e.path.hasSuffix("Info.plist") {
                            Button(role: .destructive) { deleteEntry(e) } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless)
                        }
                    }
                }
            } header: {
                Text("شجرة الملفات (\(entries.count))")
            } footer: {
                Text("نعرض أول ٤٠٠ نتيجة من البحث. احذف بحذر — بعض الملفات ضرورية للتطبيق.")
            }
            Section {
                Button { addingFile = true } label: { Label("أضف ملف / dylib", systemImage: "plus.circle") }
                Button { exportIPA() } label: { Label("صدّر IPA معدّل", systemImage: "square.and.arrow.up") }
                    .buttonStyle(PrimaryButton(color: Theme.ok))
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 4)
                if let m = message { Text(m).font(.hCaption).foregroundStyle(.secondary) }
            }
        }
        .searchable(text: $filter, prompt: "ابحث في الملفات")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("إغلاق") { onClose() } }
        }
        .sheet(item: $share) { ShareSheet(items: $0.items) }
        .fileImporter(isPresented: $addingFile, allowedContentTypes: [.data, .item]) { result in
            if case .success(let url) = result { add(url) }
        }
    }

    private func applyEdits() {
        dict["CFBundleDisplayName"] = displayName
        dict["CFBundleIdentifier"] = bundleID
        dict["CFBundleShortVersionString"] = version
        dict["CFBundleVersion"] = build
        do {
            try IPATools.writeInfoPlist(bundle, dict: dict)
            message = "تم حفظ Info.plist"
        } catch { message = error.localizedDescription }
    }

    private func deleteEntry(_ e: IPAFileEntry) {
        do {
            try IPATools.deleteFile(in: bundle, relativePath: e.path)
            entries.removeAll { $0.path == e.path || $0.path.hasPrefix(e.path) }
            message = "حُذف \(e.path)"
        } catch { message = error.localizedDescription }
    }

    private func add(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let rel = "Payload/\(bundle.appName)/Frameworks/\(url.lastPathComponent)"
        do {
            try IPATools.addFile(in: bundle, from: url, relativePath: rel)
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            entries.append(IPAFileEntry(path: rel, size: size))
            entries.sort { $0.path < $1.path }
            message = "أُضيف \(url.lastPathComponent) — ملاحظة: إضافة dylib بدون تعديل load command في الثنائي ما تحقنه تلقائياً."
        } catch { message = error.localizedDescription }
    }

    private func exportIPA() {
        applyEdits()
        do {
            let name = "\(displayName.isEmpty ? "App" : displayName)-edited.ipa"
            let url = try IPATools.export(bundle, named: name)
            share = SharePayload(items: [url])
            message = "جاهز للمشاركة مع ESign"
        } catch { message = error.localizedDescription }
    }
}
