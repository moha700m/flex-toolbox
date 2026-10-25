import SwiftUI

struct FilesHubView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("حاوية التطبيق (صندوق الرمل)") {
                    NavigationLink { DirectoryView(root: FileBrowser.documents, title: "Documents") } label: {
                        Label("Documents", systemImage: "doc.on.doc")
                    }
                    NavigationLink { DirectoryView(root: FileBrowser.library, title: "Library") } label: {
                        Label("Library", systemImage: "books.vertical")
                    }
                    NavigationLink { DirectoryView(root: FileBrowser.tmp, title: "tmp") } label: {
                        Label("tmp", systemImage: "clock")
                    }
                }
                Section("محررات") {
                    NavigationLink { DefaultsEditorView() } label: {
                        Label("UserDefaults", systemImage: "slider.horizontal.3")
                    }
                    NavigationLink { ImportAnyFileView() } label: {
                        Label("افتح ملف (plist/json/sqlite/hex)", systemImage: "doc.badge.magnifyingglass")
                    }
                }
                Section {
                    Text("هذي ملفات تطبيق «عدّة فلكس» نفسه فقط. ملفات التطبيقات الثانية محمية من iOS.").font(.hCaption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("الملفات")
        }
    }
}

struct DirectoryView: View {
    let root: URL
    let title: String
    @State private var nodes: [FileNode] = []
    @State private var error: String?
    @State private var share: SharePayload?

    var body: some View {
        List {
            ForEach(nodes) { n in
                if n.isDirectory {
                    NavigationLink { DirectoryView(root: n.url, title: n.name) } label: { row(n) }
                } else {
                    NavigationLink { FileViewer(url: n.url) } label: { row(n) }
                }
            }
            .onDelete { idx in
                for i in idx {
                    try? FileBrowser.delete(nodes[i].url)
                }
                refresh()
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { refresh() } label: { Image(systemName: "arrow.clockwise") }
            }
        }
        .onAppear(perform: refresh)
        .alert("خطأ", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("حسناً", role: .cancel) {}
        } message: { Text(error ?? "") }
        .sheet(item: $share) { ShareSheet(items: $0.items) }
    }

    private func row(_ n: FileNode) -> some View {
        HStack {
            Image(systemName: n.isDirectory ? "folder.fill" : icon(for: n)).foregroundStyle(Theme.navy)
            VStack(alignment: .leading) {
                Text(n.name).font(.hBody)
                if !n.isDirectory { Text(IPATools.humanSize(n.size)).font(.hCaption).foregroundStyle(.secondary) }
            }
        }
    }

    private func icon(for n: FileNode) -> String {
        switch FileBrowser.kind(of: n.url) {
        case "plist": return "list.bullet.rectangle"
        case "json": return "curlybraces"
        case "sqlite": return "cylinder.split.1x2"
        case "image": return "photo"
        case "text": return "doc.plaintext"
        default: return "doc"
        }
    }

    private func refresh() {
        do { nodes = try FileBrowser.list(root) }
        catch { self.error = error.localizedDescription }
    }
}

struct ImportAnyFileView: View {
    @State private var picking = false
    @State private var picked: URL?
    var body: some View {
        VStack(spacing: 16) {
            Text("اختر أي ملف من الملفات (plist / json / sqlite / ثنائي) عشان نفتحه هنا.").font(.hBody).foregroundStyle(.secondary).multilineTextAlignment(.center).padding()
            Button { picking = true } label: { Label("اختر ملف", systemImage: "doc") }.buttonStyle(PrimaryButton()).padding(.horizontal, 40)
            if let u = picked { NavigationLink("افتح \(u.lastPathComponent)") { FileViewer(url: u) }.font(.hHeadline) }
            Spacer()
        }
        .navigationTitle("فتح ملف")
        .fileImporter(isPresented: $picking, allowedContentTypes: [.item, .data, .json, .propertyList]) { r in
            if case .success(let u) = r {
                let scoped = u.startAccessingSecurityScopedResource()
                // Copy into Documents so we keep access.
                let dest = FileBrowser.documents.appendingPathComponent(u.lastPathComponent)
                try? FileManager.default.removeItem(at: dest)
                try? FileManager.default.copyItem(at: u, to: dest)
                if scoped { u.stopAccessingSecurityScopedResource() }
                picked = dest
            }
        }
    }
}
