import SwiftUI

struct KeyEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: KeyStore
    let existing: ZKey?

    @State private var name = ""
    @State private var key = ""
    @State private var testing = false
    @State private var testResult: String?

    private var keyTrimmed: String { key.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名称（本机 / 同事A）", text: $name)
                } header: {
                    Text("名称")
                }
                Section {
                    TextEditor(text: $key)
                        .frame(minHeight: 80)
                        .font(.system(.footnote, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Label {
                        Text("从剪贴板粘贴")
                    } icon: {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .onTapGesture {
                        if let s = UIPasteboard.general.string {
                            key = s.trimmingCharacters(in: .whitespacesAndNewlines)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                } header: {
                    Text("key（sk- 会话 token）")
                } footer: {
                    Text("只在 PC 端 ZhanluDaddy 抓取后获取，仅存本机")
                }
                Section {
                    Button {
                        test()
                    } label: {
                        HStack {
                            if testing { ProgressView().scaleEffect(0.8) }
                            Label(testing ? "查询中…" : "试查询",
                                  systemImage: testing ? "" : "bolt.horizontal")
                        }
                    }
                    .disabled(keyTrimmed.isEmpty || testing)
                } footer: {
                    if let r = testResult {
                        Text(r)
                    } else {
                        Text("保存前先验证 key 是否有效")
                    }
                }
                Section {
                    Text(Gateway.baseURL)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                } header: {
                    Text("网关")
                }
            }
            .navigationTitle(existing == nil ? "添加 key" : "编辑 key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var k = existing ?? ZKey(name: name, key: keyTrimmed)
                        k.name = name.isEmpty ? "未命名" : name
                        k.key = keyTrimmed
                        store.upsert(k)
                        dismiss()
                    }
                    .disabled(keyTrimmed.isEmpty)
                }
            }
            .onAppear {
                if let e = existing {
                    name = e.name; key = e.key
                }
            }
        }
    }

    private func test() {
        testing = true
        testResult = nil
        Task {
            do {
                let q = try await QuotaService.query(key: keyTrimmed)
                testResult = "✅ 有效 · 剩余 \(fmt(q.remaining)) / 总额 \(fmt(q.maxBudget))"
            } catch {
                testResult = "❌ \(error.localizedDescription)"
            }
            testing = false
        }
    }
}
