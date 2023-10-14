import Foundation
import SwiftlyCore

/// Struct modelling the config.json file used to track installed toolchains,
/// the current in-use tooolchain, and information about the platform.
///
/// TODO: implement cache
public struct Config: Codable, Equatable {
    public struct PlatformDefinition: Codable, Equatable {
        /// The name of the platform as it is used in the Swift download URLs.
        /// For instance, for Ubuntu 16.04 this would return “ubuntu1604”.
        /// For macOS / Xcode, this would return “xcode”.
        public let name: String

        /// The full name of the platform as it is used in the Swift download URLs.
        /// For instance, for Ubuntu 16.04 this would return “ubuntu16.04”.
        public let nameFull: String

        /// A human-readable / pretty-printed version of the platform’s name, used for terminal
        /// output and logging.
        /// For example, “Ubuntu 18.04” would be returned on Ubuntu 18.04.
        public let namePretty: String

        /// The CPU architecture of the platform. If omitted, assumed to be x86_64.
        public let architecture: String?

        public func getArchitecture() -> String {
            return self.architecture ?? "x86_64"
        }
    }

    public var inUse: ToolchainVersion?
    public var installedToolchains: Set<ToolchainVersion>
    public var platform: PlatformDefinition

    internal init(inUse: ToolchainVersion?, installedToolchains: Set<ToolchainVersion>, platform: PlatformDefinition) {
        self.inUse = inUse
        self.installedToolchains = installedToolchains
        self.platform = platform
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        return encoder
    }

    /// Read the config file from disk.
    public static func load() throws -> Config {
        do {
            let data = try Data(contentsOf: Swiftly.currentPlatform.swiftlyConfigFile)
            return try JSONDecoder().decode(Config.self, from: data)
        } catch {
            let msg = """
            Could not load swiftly's configuration file at \(Swiftly.currentPlatform.swiftlyConfigFile.path) due to
            error: \"\(error)\".
            To use swiftly, modify the configuration file to fix the issue or perform a clean installation.
            """
            throw Error(message: msg)
        }
    }

    /// Write the contents of this `Config` struct to disk.
    public func save() throws {
        let outData = try Self.makeEncoder().encode(self)
        try outData.write(to: Swiftly.currentPlatform.swiftlyConfigFile, options: .atomic)
    }

    public func listInstalledToolchains(selector: ToolchainSelector?) -> [ToolchainVersion] {
        guard let selector else {
            return Array(self.installedToolchains)
        }

        if case .latest = selector {
            var ts: [ToolchainVersion] = []
            if let t = self.installedToolchains.filter({ $0.isStableRelease() }).max() {
                ts.append(t)
            }
            return ts
        }

        return self.installedToolchains.filter { toolchain in
            selector.matches(toolchain: toolchain)
        }
    }

    /// Load the config, pass it to the provided closure, and then
    /// save the modified config to disk.
    public static func update(f: (inout Config) throws -> Void) throws {
        var config = try Config.load()
        try f(&config)
        // only save the updates if the prior closure invocation succeeded
        try config.save()
    }
}

extension ToolchainVersion: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.name)
    }
}

extension ToolchainVersion: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let str = try container.decode(String.self)
        self = try ToolchainVersion(parsing: str)
    }
}
