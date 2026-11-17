import Foundation

enum QuotaError: LocalizedError {
    case allFailed(String)
    var errorDescription: String? {
        switch self {
        case .allFailed(let msg): return msg
        }
    }
}

/// 移动云网关服务：额度查询 + 模型列表（Bearer 鉴权）
enum QuotaService {
    static func quotaEndpoints() -> [String] {
        // external-ide 是实测命中的，放最前（与 PC 端方案C 顺序一致）
        [Gateway.baseURL + "/gateway/api/v1/external-ide/budget-info",
         Gateway.baseURL + "/kilocode/budget/info"]
    }

    static func query(key: String) async throws -> QuotaResult {
        var lastStatus = -1
        for urlString in quotaEndpoints() {
            guard let url = URL(string: urlString) else { continue }
            var req = URLRequest(url: url, timeoutInterval: 15)
            req.httpMethod = "GET"
            req.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
            req.setValue("zhanlu-quota-ios/1.0", forHTTPHeaderField: "User-Agent")
            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
                lastStatus = status
                guard status == 200,
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let quota = QuotaResult.from(dict: obj) else { continue }
                return quota
            } catch {
                lastStatus = -1
                continue
            }
        }
        throw QuotaError.allFailed(lastStatus == -1 ? "网络不可达" : "HTTP \(lastStatus)")
    }

    /// 拉取模型列表（与 PC 端 /v1/models 同款）
    static func listModels(key: String) async throws -> [ModelItem] {
        guard let url = URL(string: Gateway.modelsURL) else {
            throw QuotaError.allFailed("URL 无效")
        }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "GET"
        req.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
        req.setValue("zhanlu-quota-ios/1.0", forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard status == 200 else { throw QuotaError.allFailed("HTTP \(status)") }
        struct Resp: Codable { var data: [ModelItem]? }
        guard let r = try? JSONDecoder().decode(Resp.self, from: data),
              let items = r.data else { throw QuotaError.allFailed("响应解析失败") }
        return items.sorted { $0.id < $1.id }
    }
}
