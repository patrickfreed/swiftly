import ArgumentParser
import Foundation
import TSCBasic
import TSCUtility

import SwiftlyCore

fileprivate struct SwiftlyRelease: Decodable {
    fileprivate let name: String
}

internal struct SelfUpdate: SwiftlyCommand {
    public static var configuration = CommandConfiguration(
        abstract: "Update the version of swiftly itself."
    )

    private var httpClient = SwiftlyHTTPClient()

    private enum CodingKeys: CodingKey {}

    internal mutating func run() async throws {
        SwiftlyCore.print("Checking for updates...")

        let release: SwiftlyRelease = try await self.httpClient.getFromGitHub(
            url: "https://api.github.com/repos/swift-server/swiftly/releases/latest"
        )

        // guard release.name > Swiftly.configuration.version else {
        //     SwiftlyCore.print("Already up to date.")
        //     return
        // }

        SwiftlyCore.print("A new version is available: \(release.name)")

        let config = try Config.load()
        let executableName = Swiftly.currentPlatform.getExecutableName(forArch: config.platform.getArchitecture())
        let downloadURL = URL(string: "https://github.com/swift-server/swiftly/releases/latest/download/\(executableName)")!

        let tmpFile = Swiftly.currentPlatform.getTempFilePath()
        FileManager.default.createFile(atPath: tmpFile.path, contents: nil)
        defer {
            try? FileManager.default.removeItem(at: tmpFile)
        }

        let animation = PercentProgressAnimation(
            stream: stdoutStream,
            header: "Downloading swiftly \(release.name)"
        )
        do {
            try await httpClient.downloadFile(
                url: downloadURL,
                to: tmpFile,
                reportProgress: { progress in
                    let downloadedMiB = Double(progress.receivedBytes) / (1024.0 * 1024.0)
                    let totalMiB = Double(progress.totalBytes!) / (1024.0 * 1024.0)

                    animation.update(
                        step: progress.receivedBytes,
                        total: progress.totalBytes!,
                        text: "Downloaded \(String(format: "%.1f", downloadedMiB)) MiB of \(String(format: "%.1f", totalMiB)) MiB"
                    )
                }
            )
        } catch {
            animation.complete(success: false)
            throw error
        }
        animation.complete(success: true)

        let swiftlyExecutable = Swiftly.currentPlatform.swiftlyBinDir.appendingPathComponent("swiftly", isDirectory: false)
        try FileManager.default.removeItem(at: swiftlyExecutable)
        try FileManager.default.moveItem(at: tmpFile, to: swiftlyExecutable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: swiftlyExecutable.path)
        SwiftlyCore.print("Successfully updated swiftly to \(release.name) (was \(Swiftly.configuration.version))")
    }
}
