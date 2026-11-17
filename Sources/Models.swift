import Foundation

/// 网关：移动云（公网）。内网 HTTP 在 iOS 上不可达，不做内网模式。
enum Gateway {
    static let baseURL = "https://ecloud.10086.cn/api/query/aigateway"
    static let modelsURL = baseURL + "/v1/models"
    static let authHeader = "Authorization"
}

/// 一次额度查询结果（PC 端 budget_fields 同款，缺省值按公式兜底）
struct QuotaResult: Codable {
    var maxBudget: Double?
    var spend: Double?
    var remaining: Double?

    var remainingPercent: Double? {
        guard let m = maxBudget, m > 0, let r = remaining else { return nil }
        return r / m * 100.0
    }

    static func from(dict: [String: Any]) -> QuotaResult? {
        func num(_ v: Any?) -> Double? {
            if let n = v as? NSNumber { return n.doubleValue }
            if let s = v as? String { return Double(s) }
            return nil
        }
        // 先顶层，再 data/budget/result 包裹层（与 PC _extract_budget 一致）
        let layers: [[String: Any]] = [dict] + ["data", "budget", "result"].compactMap { dict[$0] as? [String: Any] }
        for layer in layers {
            let maxb = num(layer["maxBudget"]) ?? num(layer["max_budget"])
            let spend = num(layer["spend"])
            let remain = num(layer["remainingBudget"]) ?? num(layer["remaining_budget"])
            if maxb != nil || remain != nil {
                var r = remain
                if r == nil, let m = maxb, let s = spend { r = m - s }
                return QuotaResult(maxBudget: maxb, spend: spend, remaining: r)
            }
        }
        return nil
    }
}

/// 一条保存的 key
struct ZKey: Identifiable, Codable {
    var id = UUID()
    var name: String
    var key: String
    var quota: QuotaResult?
    var lastTime: Date?
    var lastError: String?

    var masked: String {
        guard key.count > 14 else { return key }
        return "\(key.prefix(10))…\(key.suffix(4))"
    }
}

/// 模型条目（GET /v1/models 返回）
struct ModelItem: Identifiable, Codable {
    var id: String
}
