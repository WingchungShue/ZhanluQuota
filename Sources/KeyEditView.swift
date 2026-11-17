import SwiftUI

struct KeyEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: KeyStore
    let existing: ZKey?

    @State private var name = ""
    @State private var key = ""
    @State private var mode: GatewayMode = .cloud
    @State private var testing = false
    @State private var testResult: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("名称") {
                    TextField("例如：本机 / 同事A", text: $name)
                }
                Section("key（sk- 会话 token）") {
                    TextEditor(text: $key)
                        .frame(minHeight: 80)
                        .font(.caption)
                    Button("从剪贴板粘贴") {
                        if let s = UIPasteboard.general.string { key = s.trimmingCharacters(in: .whitespacesAndNewlines) }
                    }
                }
                Section("网关模式") {
                    Picker("模式", selection: $mode) {
                        ForEach(GatewayMode.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text(mode.baseURL).font(.caption2).foregroundColor(.secondary)
                }
                if let r = testResult {
                    Section("试查询结果") { Text(r).font(.caption) }
                }
            }
            .navigationTitle(existing == nil ? "添加 key" : "编辑 key")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var k = existing ?? ZKey(name: name, key: key, mode: mode)
                        k.name = name.isEmpty ? "未命名" : name
                        k.key = key.trimmingCharacters(in: .whitespacesAndNewlines)
                        k.mode = mode
                        store.upsert(k)
                        dismiss()
                    }
                    .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        testing = true
                        testResult = nil
                        Task {
                            do {
                                let q = try await QuotaService.query(key: key, mode: mode)
                                testResult = "✅ 剩余 \(fmt(q.remaining)) / 总额 \(fmt(q.maxBudget))"
                            } catch {
                                testResult = "❌ \(error.localizedDescription)"
                            }
                            testing = false
                        }
                    } label: {
                        HStack {
                            if testing { ProgressView().scaleEffect(0.8) }
                            Text("保存前先试一下")
                        }
                    }
                    .disabled(key.isEmpty || testing)
                }
            }
            .onAppear {
                if let e = existing {
                    name = e.name; key = e.key; mode = e.mode
                }
            }
        }
    }
}
