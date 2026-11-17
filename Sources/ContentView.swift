import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: KeyStore
    @State private var showAdd = false
    @State private var editing: ZKey?
    @State private var batchRunning = false

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
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .refreshable { await store.queryAll() }
            .sheet(isPresented: $showAdd) { KeyEditView(existing: nil) }
            .sheet(item: $editing) { k in KeyEditView(existing: k) }
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
                Text(key.mode.label)
                    .font(.caption2)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(key.mode == .cloud ? Color.blue.opacity(0.15) : Color.orange.opacity(0.15))
                    .foregroundColor(key.mode == .cloud ? .blue : .orange)
                    .cornerRadius(4)
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
