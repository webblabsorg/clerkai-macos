import Foundation

final class AppleScriptRunner {
    static let shared = AppleScriptRunner()

    private init() {}

    func run(_ source: String) throws -> NSAppleEventDescriptor? {
        guard let script = NSAppleScript(source: source) else {
            throw AppleScriptError.invalidScript
        }

        var errorDict: NSDictionary?
        let result = script.executeAndReturnError(&errorDict)

        if let errorDict {
            throw AppleScriptError.executionFailed(errorDict)
        }

        return result
    }

    func runString(_ source: String) throws -> String? {
        let result = try run(source)

        if let stringValue = result?.stringValue {
            return stringValue
        }

        if let descriptor = result, descriptor.descriptorType == typeAEList {
            return descriptor.stringValue
        }

        return nil
    }

    func runBoolean(_ source: String) throws -> Bool {
        let result = try run(source)
        return result?.booleanValue ?? false
    }
}

enum AppleScriptError: LocalizedError {
    case invalidScript
    case executionFailed(NSDictionary)

    var errorDescription: String? {
        switch self {
        case .invalidScript:
            return "Invalid AppleScript"
        case .executionFailed(let dict):
            if let message = dict[NSAppleScript.errorMessage] as? String {
                return message
            }
            return "AppleScript execution failed"
        }
    }
}
