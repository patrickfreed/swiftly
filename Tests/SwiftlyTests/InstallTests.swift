import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import XCTest

final class InstallTests: SwiftlyTests {
    /// Tests that `swiftly install latest` successfully installs the latest stable release of Swift.
    ///
    /// It stops short of verifying that it actually installs the _most_ recently released version, which is the intended
    /// behavior, since determining which version is the latest is non-trivial and would require duplicating code
    /// from within swiftly itself.
    func testInstallLatest() async throws {
        try await self.withTestHome {
            var cmd = try self.parseCommand(Install.self, ["install", "latest"])
            try await cmd.run()

            let config = try Config.load()

            XCTAssertTrue(!config.installedToolchains.isEmpty)

            let installedToolchain = config.installedToolchains.first!

            guard case let .stable(release) = installedToolchain else {
                XCTFail("expected swiftly install latest to insall release toolchain but got \(installedToolchain)")
                return
            }

            // As of writing this, 5.7.0 is the latest stable release. Assert it is at least that new.
            XCTAssertTrue(release >= ToolchainVersion.StableRelease(major: 5, minor: 7, patch: 0))

            try await validateInstalledToolchains([installedToolchain], description: "install latest")
        }
    }

    /// Tests that `swiftly install a.b` installs the latest patch version of Swift a.b.
    func testInstallLatestPatchVersion() async throws {
        try await self.withTestHome {
            var cmd = try self.parseCommand(Install.self, ["install", "5.6"])
            try await cmd.run()

            let config = try Config.load()

            XCTAssertTrue(!config.installedToolchains.isEmpty)

            let installedToolchain = config.installedToolchains.first!

            guard case let .stable(release) = installedToolchain else {
                XCTFail("expected swiftly install latest to insall release toolchain but got \(installedToolchain)")
                return
            }

            // As of writing this, 5.6.3 is the latest 5.6 patch release. Assert it is at least that new.
            XCTAssertTrue(release >= ToolchainVersion.StableRelease(major: 5, minor: 6, patch: 3))

            try await validateInstalledToolchains([installedToolchain], description: "install latest")
        }
    }

    /// Tests that swiftly can install different stable release versions by their full a.b.c versions.
    func testInstallReleases() async throws {
        try await self.withTestHome {
            var installedToolchains: Set<ToolchainVersion> = []

            var cmd = try self.parseCommand(Install.self, ["install", "5.7.0"])
            try await cmd.run()

            installedToolchains.insert(ToolchainVersion(major: 5, minor: 7, patch: 0))
            try await validateInstalledToolchains(
                installedToolchains,
                description: "install a stable release toolchain"
            )

            cmd = try self.parseCommand(Install.self, ["install", "5.6.1"])
            try await cmd.run()

            installedToolchains.insert(ToolchainVersion(major: 5, minor: 6, patch: 1))
            try await validateInstalledToolchains(
                installedToolchains,
                description: "install another stable release toolchain"
            )
        }
    }

    /// Tests that swiftly can install main and release snapshots by their full snapshot names.
    func testInstallSnapshots() async throws {
        try await self.withTestHome {
            var installedToolchains: Set<ToolchainVersion> = []

            var cmd = try self.parseCommand(Install.self, ["install", "main-snapshot-2022-09-10"])
            try await cmd.run()

            installedToolchains.insert(ToolchainVersion(snapshotBranch: .main, date: "2022-09-10"))
            try await validateInstalledToolchains(
                installedToolchains,
                description: "install a main snapshot toolchain"
            )

            cmd = try self.parseCommand(Install.self, ["install", "5.7-snapshot-2022-08-30"])
            try await cmd.run()

            installedToolchains.insert(ToolchainVersion(snapshotBranch: .release(major: 5, minor: 7), date: "2022-08-30"))
            try await validateInstalledToolchains(
                installedToolchains,
                description: "install a 5.7 snapshot toolchain"
            )
        }
    }

    /// Tests that `swiftly install main-snapshot` installs the latest available main snapshot.
    func testInstallLatestMainSnapshot() async throws {
        try await self.withTestHome {
            var cmd = try self.parseCommand(Install.self, ["install", "main-snapshot"])
            try await cmd.run()

            let config = try Config.load()

            XCTAssertTrue(!config.installedToolchains.isEmpty)

            let installedToolchain = config.installedToolchains.first!

            guard case let .snapshot(snapshot) = installedToolchain, snapshot.branch == .main else {
                XCTFail("expected to install latest main snapshot toolchain but got \(installedToolchain)")
                return
            }

            // As of writing this, 2022-09-12 is the date of the latest main snapshot. Assert it is at least that new.
            XCTAssertTrue(snapshot.date >= "2022-09-12")

            try await validateInstalledToolchains(
                [installedToolchain],
                description: "install the latest main snapshot toolchain"
            )
        }
    }

    /// Tests that `swiftly install a.b-snapshot` installs the latest available a.b release snapshot.
    func testInstallLatestReleaseSnapshot() async throws {
        try await self.withTestHome {
            var cmd = try self.parseCommand(Install.self, ["install", "5.7-snapshot"])
            try await cmd.run()

            let config = try Config.load()

            XCTAssertTrue(!config.installedToolchains.isEmpty)

            let installedToolchain = config.installedToolchains.first!

            guard case let .snapshot(snapshot) = installedToolchain, snapshot.branch == .release(major: 5, minor: 7) else {
                XCTFail("expected swiftly install 5.7-snapshot to install snapshot toolchain but got \(installedToolchain)")
                return
            }

            // As of writing this, 2022-08-30 is the date of the latest 5.7 snapshot. Assert it is at least that new.
            XCTAssertTrue(snapshot.date >= "2022-08-30")

            try await validateInstalledToolchains(
                [installedToolchain],
                description: "install the latest 5.7 snapshot toolchain"
            )
        }
    }

    /// Tests that swiftly can install both stable release toolchains and snapshot toolchains.
    func testInstallReleaseAndSnapshots() async throws {
        try await self.withTestHome {
            var cmd = try self.parseCommand(Install.self, ["install", "main-snapshot-2022-09-10"])
            try await cmd.run()

            cmd = try self.parseCommand(Install.self, ["install", "5.7-snapshot-2022-08-30"])
            try await cmd.run()

            cmd = try self.parseCommand(Install.self, ["install", "5.7.0"])
            try await cmd.run()

            try await validateInstalledToolchains(
                [
                    ToolchainVersion(snapshotBranch: .main, date: "2022-09-10"),
                    ToolchainVersion(snapshotBranch: .release(major: 5, minor: 7), date: "2022-08-30"),
                    ToolchainVersion(major: 5, minor: 7, patch: 0),
                ],
                description: "install both snapshots and releases"
            )
        }
    }

    func duplicateTest(_ version: String) async throws {
        try await self.withTestHome {
            var cmd = try self.parseCommand(Install.self, ["install", version])
            try await cmd.run()

            let before = try Config.load()

            let startTime = Date()
            cmd = try self.parseCommand(Install.self, ["install", version])
            try await cmd.run()

            // Assert that swiftly didn't attempt to download a new toolchain.
            XCTAssertTrue(startTime.timeIntervalSinceNow.magnitude < 5)

            let after = try Config.load()
            XCTAssertEqual(before, after)
        }
    }

    /// Tests that attempting to install stable releases that are already installed doesn't result in an error.
    func testInstallDuplicateReleases() async throws {
        try await self.duplicateTest("5.7.0")
        try await self.duplicateTest("latest")
    }

    /// Tests that attempting to install main snapshots that are already installed doesn't result in an error.
    func testInstallDuplicateMainSnapshots() async throws {
        try await self.duplicateTest("main-snapshot-2022-09-10")
        try await self.duplicateTest("main-snapshot")
    }

    /// Tests that attempting to install release snapshots that are already installed doesn't result in an error.
    func testInstallDuplicateReleaseSnapshots() async throws {
        try await self.duplicateTest("5.7-snapshot-2022-08-30")
        try await self.duplicateTest("5.7-snapshot")
    }

    /// Verify that the installed toolchain will be used if no toolchains currently are installed.
    func testInstallUsesFirstToolchain() async throws {
        try await self.withTestHome {
            let config = try Config.load()
            XCTAssertTrue(config.inUse == nil)
            try await validateInUse(expected: nil)

            var cmd = try self.parseCommand(Install.self, ["install", "5.7.0"])
            try await cmd.run()

            try await validateInUse(expected: ToolchainVersion(major: 5, minor: 7, patch: 0))

            var install56 = try self.parseCommand(Install.self, ["install", "5.6.0"])
            try await install56.run()

            // Verify that 5.7.0 is still in use.
            try await self.validateInUse(expected: ToolchainVersion(major: 5, minor: 7, patch: 0))
        }
    }
}
