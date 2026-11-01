// Capture local release artwork through one isolated headless Chrome session.
import Foundation

struct RenderFailure: Error { let message: String }
final class CDP {
    let socket: URLSessionWebSocketTask
    var nextID = 0
    init(_ url: URL) { socket = URLSession.shared.webSocketTask(with: url); socket.maximumMessageSize = 64 * 1024 * 1024; socket.resume() }
    func call(_ method: String, _ params: [String: Any] = [:]) async throws -> [String: Any] {
        nextID += 1
        let id = nextID
        let data = try JSONSerialization.data(withJSONObject: ["id": id, "method": method, "params": params])
        try await socket.send(.string(String(decoding: data, as: UTF8.self)))
        while true {
            let message = try await socket.receive()
            let bytes: Data
            switch message {
            case .string(let text): bytes = Data(text.utf8)
            case .data(let data): bytes = data
            @unknown default: throw RenderFailure(message: "Unknown browser response")
            }
            let object = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
            guard object["id"] as? Int == id else { continue }
            if let error = object["error"] { throw RenderFailure(message: "\(method): \(error)") }
            let result = object["result"] as? [String: Any] ?? [:]
            if let exception = result["exceptionDetails"] { throw RenderFailure(message: "\(method): \(exception)") }
            return result
        }
    }
}
@main struct ReleaseRenderer {
    static func main() async throws {
        let args = CommandLine.arguments
        guard args.count == 4 else { throw RenderFailure(message: "usage: renderer port sourceDir stageDir") }
        let port = args[1], source = URL(fileURLWithPath: args[2]), output = URL(fileURLWithPath: args[3])
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/json/new?about:blank")!)
        request.httpMethod = "PUT"
        let (data, _) = try await URLSession.shared.data(for: request)
        let target = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        guard let address = target["webSocketDebuggerUrl"] as? String, let url = URL(string: address) else { throw RenderFailure(message: "Missing browser target") }
        let cdp = CDP(url)
        defer { cdp.socket.cancel(with: .normalClosure, reason: nil) }
        _ = try await cdp.call("Page.enable")
        let slots = [("release-iphone-6.3-1206x2622",1206,2622),("release-iphone-6.5-1242x2688",1242,2688),("release-ipad-13-2064x2752",2064,2752)]
        for (folder,w,h) in slots {
            _ = try await cdp.call("Emulation.setDeviceMetricsOverride", ["width":w,"height":h,"deviceScaleFactor":1,"mobile":false])
            var components = URLComponents(url: source.appendingPathComponent("release-grid.html"), resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name:"w",value:String(w)),URLQueryItem(name:"h",value:String(h))]
            _ = try await cdp.call("Page.navigate", ["url":components.url!.absoluteString])
            var ready = false
            for _ in 0..<200 {
                let result = try await cdp.call("Runtime.evaluate", ["expression":"Number(new URL(location.href).searchParams.get('w')) === \(w) && typeof window.ready !== 'undefined'","returnByValue":true])
                if (result["result"] as? [String:Any])?["value"] as? Bool == true { ready = true; break }
                try await Task.sleep(nanoseconds:100_000_000)
            }
            guard ready else { throw RenderFailure(message:"Artwork did not initialize") }
            _ = try await cdp.call("Runtime.evaluate", ["expression":"window.ready","awaitPromise":true,"returnByValue":true])
            let shot = try await cdp.call("Page.captureScreenshot", ["format":"png","optimizeForSpeed":true,"captureBeyondViewport":true,"clip":["x":0,"y":0,"width":w,"height":h*4,"scale":1]])
            guard let base64 = shot["data"] as? String, let png = Data(base64Encoded:base64) else { throw RenderFailure(message:"Missing screenshot data") }
            try png.write(to:output.appendingPathComponent(folder+".png"))
            print(folder,"four-panel grid captured")
        }
    }
}
