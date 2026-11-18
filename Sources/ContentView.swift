import SwiftUI

// MARK: - 设计系统（HIG 速查表取值）
enum DS {
    /// 系统语义色（SwiftUI 直接用系统色，自动适配深浅色与增强对比）
    static let green = Color.green
    static let orange = Color.orange
    static let red = Color.red
    static let blue = Color.blue

    /// 剩余额度的语义色：>50% 绿 / 20~50% 橙 / <20% 红（不只靠颜色，还配图标）
    static func quotaColor(_ pct: Double?) -> Color {
        guard let p = pct else { return .secondary }
        if p >= 50 { return .green }
        if p >= 20 { return .orange }
        return .red
    }
}

// MARK: - 主列表
struct ContentView: View {
    @EnvironmentObject var store: KeyStore
    @State private var showAdd = false
    @State private var editing: ZKey?
    @State private var showModels = false

    var body: some View {
        NavigationStack {
            Group {
                if store.keys.isEmpty {
                    emptyState
                } else {
                    keyList
                }
            }
            .navigationTitle("ZhanluQuota")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showModels = true } label: {
                        Label("模型列表", systemImage: "list.bullet")
                    }
                    .disabled(store.keys.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: {
                        Label("添加 key", systemImage: "plus")
                    }
                }
            }
            .refreshable { await store.queryAll() }
            .sheet(isPresented: $showAdd) { KeyEditView(existing: nil) }
            .sheet(item: $editing) { k in KeyEditView(existing: k) }
            .sheet(isPresented: $showModels) { ModelsListView(store: store) }
        }
    }

    // MARK: 空状态：说明 + 主行动按钮一步可见（渐进式披露的最外层）
    private var emptyState: some View {
        ContentUnavailableView {
            Label("还没有 key", systemImage: "key.horizontal")
        } description: {
            Text("先在 PC 端 ZhanluDaddy 抓取 sk- token\n再回到这里添加")
        } actions: {
            Button {
                showAdd = true
            } label: {
                Text("添加第一个 key")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: key 列表
    private var keyList: some View {
        List {
            // 总览卡：所有 key 剩余合计，主任务路径一步可见
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
                        .swipeActions(edge: .leading) {
                            Button {
                                Task { await store.query(k) }
                            } label: {
                                Label("查询", systemImage: "arrow.clockwise")
                            }
                            .tint(.green)
                        }
                }
            } footer: {
                HStack {
                    Text("下拉全部刷新 · 左滑单查 · 点行编辑")
                    Spacer()
                    if store.batchRunning {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.7)
                            Text("查询中").font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - 总览卡（合计剩余 + 大数字层级）
struct SummaryCard: View {
    let keys: [ZKey]

    private var totalRemaining: Double? {
        let vals = keys.compactMap { $0.quota?.remaining }
        return vals.isEmpty ? nil : vals.reduce(0, +)
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

    private var percent: Double? {
        let total = keys.compactMap { $0.quota?.maxBudget }.reduce(0, +)
        let remain = keys.compactMap { $0.quota?.remaining }.reduce(0, +)
        guard total > 0 else { return nil }
        return remain / total * 100
    }
}

// MARK: - key 行（剩余大数字为主视觉，其余渐进披露）
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
                // 进度条：颜色+宽度双通道传达余量（不只靠颜色）
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
                Text("未查询 · 左滑查询")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 模型列表页
struct ModelsListView: View {
    @ObservedObject var store: KeyStore
    @Environment(\.dismiss) private var dismiss
    @State private var loading = false
    @State private var models: [ModelItem] = []
    @State private var err: String?
    @State private var selectedKey: UUID?
    @State private var searchText = ""

    private var filtered: [ModelItem] {
        searchText.isEmpty ? models : models.filter { $0.id.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.keys.isEmpty {
                    ContentUnavailableView("没有 key", systemImage: "key.horizontal",
                                           description: Text("先添加 key 再拉取模型列表"))
                } else {
                    list
                }
            }
            .navigationTitle("模型列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        load()
                    } label: {
                        if loading { ProgressView() } else { Image(systemName: "arrow.clockwise") }
                    }
                    .disabled(selectedKey == nil || loading)
                }
            }
            .onAppear { if selectedKey == nil { selectedKey = store.keys.first?.id } }
        }
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
        .onChange(of: selectedKey) { _ in
            if !models.isEmpty { load() }
        }
    }

    private func load() {
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
    }
}

func fmt(_ v: Double?) -> String {
    guard let v = v else { return "-" }
    if abs(v) >= 1e8 { return String(format: "%.2f亿", v / 1e8) }
    if abs(v) >= 1e4 { return String(format: "%.2f万", v / 1e4) }
    return String(format: "%.2f", v)
}
