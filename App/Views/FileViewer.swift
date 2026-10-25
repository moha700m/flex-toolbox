import SwiftUI

struct FileViewer: View {
    let url: URL
    @State private var text = ""
    @State private var hex = ""
    @State private var mode = "auto"
    @State private var message: String?
    @State private var share: SharePayload?
    @State private var sqliteTables: [SQLiteTable] = []
    @State private var sqlitePreview: SQLiteQueryResult?
    @State private var selectedTable: String?

    var body: some View {
        Group {
            switch FileBrowser.kind(of: url) {
            case "sqlite": sqliteView
            case "image":
                if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                    Image(uiImage: img).resizable().scaledToFit().padding()
                } else { Text("ما قدرت أعرض الصورة") }
            default: textOrHex
            }
        }
        .navigationTitle(url.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                if FileBrowser.kind(of: url) == "plist" || FileBrowser.kind(of: url) == "json" || FileBrowser.kind(of: url) == "text" {
                    Button("احفظ") { save() }
                }
                Button { share = SharePayload(items: [url]) } label: { Image(systemName: "square.and.arrow.up") }
            }
        }
        .onAppear(perform: load)
        .sheet(item: $share) { ShareSheet(items: $0.items) }
        .safeAreaInset(edge: .bottom) {
            if let m = message { Text(m).font(.hCaption).padding(8).frame(maxWidth: .infinity).background(.ultraThinMaterial) }
        }
    }

    private var textOrHex: some View {
        VStack(spacing: 0) {
            Picker("وضع", selection: $mode) {
                Text("نص").tag("text")
                Text("Hex").tag("hex")
            }.pickerStyle(.segmented).padding(8)
            if mode == "hex" {
                ScrollView {
                    Text(hex).font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading).padding(8).textSelection(.enabled)
                }
            } else {
                TextEditor(text: $text).font(.system(.body, design: .monospaced)).padding(4)
            }
        }
    }

    private var sqliteView: some View {
        List {
            Section("الجداول") {
                if sqliteTables.isEmpty { Text("ما فيه جداول أو الملف تالف").foregroundStyle(.secondary) }
                ForEach(sqliteTables) { t in
                    Button(t.name) {
                        selectedTable = t.name
                        sqlitePreview = try? SQLiteBrowser.preview(at: url, table: t.name)
                    }.foregroundStyle(selectedTable == t.name ? Theme.navy : .primary)
                }
            }
            if let p = sqlitePreview {
                Section("معاينة (\(p.rows.count) صف)") {
                    ScrollView(.horizontal) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                ForEach(p.columns, id: \.self) { c in
                                    Text(c).font(.hCaption).bold().frame(width: 120, alignment: .leading)
                                }
                            }
                            Divider()
                            ForEach(Array(p.rows.enumerated()), id: \.offset) { _, row in
                                HStack {
                                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                                        Text(cell).font(.system(.caption2, design: .monospaced))
                                            .frame(width: 120, alignment: .leading).lineLimit(2)
                                    }
                                }
                            }
                        }.padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private func load() {
        let kind = FileBrowser.kind(of: url)
        mode = (kind == "binary") ? "hex" : "text"
        if kind == "sqlite" {
            sqliteTables = (try? SQLiteBrowser.tables(at: url)) ?? []
            return
        }
        if let data = try? Data(contentsOf: url) {
            hex = HexDump.make(data)
            if kind == "plist", let obj = PlistTools.read(data),
               let xml = PlistTools.serialize(obj), let s = String(data: xml, encoding: .utf8) {
                text = s
            } else if kind == "json", let pretty = PlistTools.prettyJSON(data) {
                text = pretty
            } else {
                text = String(data: data, encoding: .utf8) ?? "(ثنائي — استخدم وضع Hex)"
                if String(data: data, encoding: .utf8) == nil { mode = "hex" }
            }
        }
    }

    private func save() {
        let kind = FileBrowser.kind(of: url)
        do {
            if kind == "json" {
                guard PlistTools.isValidJSON(text) else { message = "JSON غير صالح"; return }
                try FileBrowser.writeText(text, to: url)
            } else if kind == "plist" {
                guard let data = text.data(using: .utf8), let obj = PlistTools.read(data),
                      let out = PlistTools.serialize(obj) else { message = "plist غير صالح"; return }
                try out.write(to: url, options: .atomic)
            } else {
                try FileBrowser.writeText(text, to: url)
            }
            message = "تم الحفظ"
        } catch { message = error.localizedDescription }
    }
}
