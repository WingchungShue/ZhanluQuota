import Foundation

enum QuotaError: LocalizedError {
    case allFailed(String)
    var errorDescription: String? {
        switch self {
        case .allFailed(let msg): return msg
        }
    }
}

/// 额度查询：与 PC 方案C query_quota 一致，Bearer 鉴权 + 候选 endpoint 逐个尝试
enum QuotaService {
    static func endpoints(for mode: GatewayMode) -> [String] {
        // external-ide 是实测命中的，放最前（与 PC 端顺序一致）
        [mode.baseURL + "/gateway/api/v1/external-ide/budget-info",
         mode.baseURL + "/kilocode/budget/info"]
    }

    static func query(key: String, mode: GatewayMode) async throws -> QuotaResult {
        var lastStatus = -1
        for urlString in endpoints(for: mode) {
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
}
