//
//  FlutterBridge.swift
//  shadow_action_skill
//
//  Created by Phoenix on 2/24/26.
//

import FlutterMacOS

final class FlutterBridge {
    static let shared = FlutterBridge()

    /// Set once during plugin registration (main thread). Read-only afterward.
    var channel: FlutterMethodChannel?

    /// Flutter requires all channel calls on the platform (main) thread.
    /// @MainActor on these methods ensures the compiler enforces this —
    /// callers from non-main contexts must `await`.
    @MainActor
    func send(_ method: String, arguments: Any? = nil, result: FlutterResult? = nil) {
        channel?.invokeMethod(method, arguments: arguments, result: result)
    }

    @MainActor
    func sendError(code: String, message: String?, details: Any? = nil) {
        channel?.invokeMethod("onError", arguments: [
            "code": code,
            "message": message ?? "",
            "details": details ?? NSNull()
        ])
    }

    @MainActor
    func invokeWindowEvent(_ data: [String: Any]) {
        send("onWindowEvent", arguments: data)
    }
}
