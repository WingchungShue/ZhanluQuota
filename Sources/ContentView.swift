import SwiftUI

// MARK: - 设计系统（HIG 速查表取值）
enum DS {
    /// 剩余额度的语义色：>50% 绿 / 20~50% 橙 / <20% 红（不只靠颜色，还配图标）
    static func quotaColor(_ pct: Double?) -> Color {
        guard let p = pct else { return .secondary }
        if p >= 50 { return .green }
        if p >= 20 { return .orange }
        return .red
    }
}

// MARK: - 空状态视图（iOS 15 兼容，替代 ContentUnavailableView）
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

// MARK: - 根：底部双页签（key / 模型）
struct ContentView: View {
    @StateObject private var store = KeyStore()

    var body: some View {
        TabView {
            KeysView()
                .tabItem { Label("Key", systemImage: "key.horizontal") }
            ModelsListView(store: store)
                .tabItem { Label("Model", systemImage: "list.bullet") }
        }
        .environmentObject(store)
    }
}

// MARK: - 页签1：key 管理 + 额度
struct KeysView: View {
    @EnvironmentObject var store: KeyStore
    @State private var showAdd = false
    @State private var editing: ZKey?

    var body: some View {
        NavigationView {
            Group {
                if store.keys.isEmpty {
                    emptyState
                } else {
                    keyList
                }
            }
            .navigationTitle("Key")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showAdd = true } label: {
                        Label("添加 key", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await store.queryAll() }
                    } label: {
                        if store.batchRunning {
                            ProgressView()
                        } else {
                            Label("刷新额度", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(store.keys.isEmpty || store.batchRunning)
                }
            }
            .sheet(isPresented: $showAdd) { KeyEditView(existing: nil) }
            .sheet(item: $editing) { k in KeyEditView(existing: k) }
        }
        .navigationViewStyle(.stack)
    }

    private var emptyState: some View {
        EmptyStateView(icon: "key.horizontal",
                       title: "还没有 key",
                       message: "先在 PC 端 ZhanluDaddy 抓取 sk- token\n再回到这里添加",
                       actionTitle: "添加第一个 key",
                       action: { showAdd = true })
    }

    private var keyList: some View {
        List {
            if store.keys.count > 1 {
                Section {
                    SummaryCard(keys: store.keys)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
            Section {
                ForEach(store.keys) { k in
                    KeyRow(key: k, querying: store.querying.contains(k.id))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            editing = k
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { store.delete(k) } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                }
            } footer: {
                if store.batchRunning {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7)
                        Text("查询中…")
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await store.queryAll() }
    }
}

// MARK: - 总览卡（合计剩余 + 大数字层级）
struct SummaryCard: View {
    let keys: [ZKey]

    private var percent: Double? {
        let total = keys.compactMap { $0.quota?.maxBudget }.reduce(0, +)
        let remain = keys.compactMap { $0.quota?.remaining }.reduce(0, +)
        guard total > 0 else { return nil }
        return remain / total * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("合计剩余额度")
                .font(.footnote)
                .foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(fmt(totalRemaining))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.quotaColor(percent))
                if let p = percent {
                    Text(String(format: "%.1f%%", p))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(DS.quotaColor(percent))
                }
                Spacer()
                Text("\(keys.count) 个 key")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private var totalRemaining: Double? {
        let vals = keys.compactMap { $0.quota?.remaining }
        return vals.isEmpty ? nil : vals.reduce(0, +)
    }
}

// MARK: - key 行
struct KeyRow: View {
    let key: ZKey
    let querying: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text(key.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if querying {
                    ProgressView().scaleEffect(0.8)
                } else if let t = key.lastTime {
                    Text(t.formatted(date: .numeric, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Text(key.masked)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)

            if let q = key.quota {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(fmt(q.remaining))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(DS.quotaColor(q.remainingPercent))
                    if let p = q.remainingPercent {
                        Text(String(format: "%.1f%%", p))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(DS.quotaColor(q.remainingPercent))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("总额 \(fmt(q.maxBudget))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("已用 \(fmt(q.spend))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                if let p = q.remainingPercent {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.quaternary)
                            Capsule()
                                .fill(DS.quotaColor(q.remainingPercent))
                                .frame(width: max(4, geo.size.width * min(1, p / 100)))
                        }
                    }
                    .frame(height: 4)
                    .animation(.spring(response: 0.4, dampingFraction: 1.0), value: p)
                }
            } else if let err = key.lastError {
                Label("查询失败：\(err)", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
            } else {
                Text("下拉刷新查询额度")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 页签2：模型列表（选 key → 刷新拉取）
struct ModelsListView: View {
    @ObservedObject var store: KeyStore
    @State private var loading = false
    @State private var models: [ModelItem] = []
    @State private var err: String?
    @State private var selectedKey: UUID?
    @State private var searchText = ""
    @State private var loadedFor: UUID?

    private var filtered: [ModelItem] {
        searchText.isEmpty ? models : models.filter { $0.id.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationView {
            Group {
                if store.keys.isEmpty {
                    EmptyStateView(icon: "key.horizontal",
                                   title: "没有 key",
                                   message: "先在 Key 页添加 key\n再回来拉取模型列表")
                } else {
                    list
                }
            }
            .navigationTitle("Model")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        load()
                    } label: {
                        if loading { ProgressView() } else {
                            Label("刷新", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(selectedKey == nil || loading)
                }
            }
            .onAppear { if selectedKey == nil { selectedKey = store.keys.first?.id } }
        }
        .navigationViewStyle(.stack)
    }

    private var list: some View {
        List {
            Section {
                Picker("key", selection: $selectedKey) {
                    ForEach(store.keys) { Text($0.name).tag(Optional($0.id)) }
                }
            }
            Section {
                if loading {
                    HStack { ProgressView(); Text("拉取中…").foregroundColor(.secondary) }
                } else if let err = err {
                    Label(err, systemImage: "exclamationmark.triangle")
                        .foregroundColor(.red)
                        .font(.caption)
                } else if models.isEmpty {
                    Text("点右上角刷新拉取")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(filtered) { m in
                        Text(m.id)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            } header: {
                if !models.isEmpty {
                    Text("\(models.count) 个模型")
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "搜索模型")
        .refreshable { load() }
        .onChange(of: selectedKey) { _ in
            if let kid = selectedKey, kid != loadedFor, !models.isEmpty { load() }
        }
    }

    private func load() {
        guard let kid = selectedKey,
              let k = store.keys.first(where: { $0.id == kid }) else { return }
        loading = true; err = nil; models = []; loadedFor = kid
        Task {
            do {
                models = try await QuotaService.listModels(key: k.key)
            } catch {
                err = error.localizedDescription
            }
            loading = false
        }
    }
}

func fmt(_ v: Double?) -> String {
    guard let v = v else { return "-" }
    if abs(v) >= 1e8 { return String(format: "%.2f亿", v / 1e8) }
    if abs(v) >= 1e4 { return String(format: "%.2f万", v / 1e4) }
    return String(format: "%.2f", v)
}
