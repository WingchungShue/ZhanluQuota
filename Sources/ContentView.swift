import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: KeyStore
    @State private var showAdd = false
    @State private var editing: ZKey?
    @State private var batchRunning = false
    @State private var showModels = false

    var body: some View {
        NavigationStack {
            List {
                if store.keys.isEmpty {
                    Text("还没有 key\n点右上角 + 添加，或先从 PC 端 ZhanluDaddy 抓取")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .listRowSeparator(.hidden)
                }
                ForEach(store.keys) { k in
                    KeyRow(key: k, querying: store.querying.contains(k.id))
                        .contentShape(Rectangle())
                        .onTapGesture { editing = k }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { store.delete(k) } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                Task { await store.query(k) }
                            } label: {
                                Label("查询", systemImage: "arrow.clockwise")
                            }
                            .tint(.green)
                        }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("湛卢额度")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 16) {
                        Button {
                            Task {
                                batchRunning = true
                                await store.queryAll()
                                batchRunning = false
                            }
                        } label: {
                            if batchRunning { ProgressView() } else { Text("全部查询") }
                        }
                        .disabled(store.keys.isEmpty || batchRunning)
                        Button { showModels = true } label: {
                            Image(systemName: "list.bullet")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .refreshable { await store.queryAll() }
            .sheet(isPresented: $showAdd) { KeyEditView(existing: nil) }
            .sheet(item: $editing) { k in KeyEditView(existing: k) }
            .sheet(isPresented: $showModels) { ModelsListView(store: store) }
        }
    }
}

/// 模型列表页：选一个 key 拉取该 key 可用的模型目录
struct ModelsListView: View {
    @ObservedObject var store: KeyStore
    @Environment(\.dismiss) private var dismiss
    @State private var loading = false
    @State private var models: [ModelItem] = []
    @State private var err: String?
    @State private var selectedKey: UUID?

    var body: some View {
        NavigationStack {
            List {
                if !store.keys.isEmpty {
                    Section("用哪个 key 拉取") {
                        Picker("key", selection: $selectedKey) {
                            ForEach(store.keys) { Text($0.name).tag(Optional($0.id)) }
                        }
                        .pickerStyle(.menu)
                    }
                }
                Section {
                    if loading {
                        HStack { ProgressView(); Text("拉取中…").foregroundColor(.secondary) }
                    } else if let err = err {
                        Text("❌ \(err)").font(.caption).foregroundColor(.red)
                    } else if models.isEmpty {
                        Text("选择 key 后点右上角刷新").foregroundColor(.secondary)
                    } else {
                        ForEach(models) { m in
                            Text(m.id).font(.system(.footnote, design: .monospaced))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("模型列表")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        guard let kid = selectedKey,
                              let k = store.keys.first(where: { $0.id == kid }) else { return }
                        loading = true; err = nil; models = []
                        Task {
                            do {
                                models = try await QuotaService.listModels(key: k.key)
                            } catch {
                                err = error.localizedDescription
                            }
                            loading = false
                        }
                    } label: { Image(systemName: "arrow.clockwise") }
                    .disabled(selectedKey == nil || loading)
                }
            }
            .onAppear {
                if selectedKey == nil { selectedKey = store.keys.first?.id }
            }
        }
    }
}

struct KeyRow: View {
    let key: ZKey
    let querying: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(key.name).font(.headline)
                Spacer()
                if querying { ProgressView().scaleEffect(0.8) }
            }
            Text(key.masked).font(.caption).foregroundColor(.secondary)
            if let q = key.quota {
                HStack(spacing: 14) {
                    Label(fmt(q.remaining), systemImage: "battery.100")
                        .foregroundColor(.green)
                    Text("总额 \(fmt(q.maxBudget))").foregroundColor(.secondary)
                    Text("已用 \(fmt(q.spend))").foregroundColor(.secondary)
                    if let p = q.remainingPercent {
                        Text(String(format: "%.1f%%", p)).foregroundColor(.green)
                    }
                }
                .font(.caption)
            }
            if let err = key.lastError {
                Text("查询失败：\(err)").font(.caption).foregroundColor(.red)
            }
            if let t = key.lastTime {
                Text("更新于 " + t.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

func fmt(_ v: Double?) -> String {
    guard let v = v else { return "-" }
    if abs(v) >= 1e8 { return String(format: "%.2f亿", v / 1e8) }
    if abs(v) >= 1e4 { return String(format: "%.2f万", v / 1e4) }
    return String(format: "%.2f", v)
}
