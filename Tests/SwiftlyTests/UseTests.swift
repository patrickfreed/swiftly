import Foundation
@testable import Swiftly
@testable import SwiftlyCore
import XCTest

final class UseTests: SwiftlyTests {
    static let homeName = "useTests"

    /// Execute a `use` command with the provided argument. Then validate that the configuration is updated properly and
    /// the in-use swift executable prints the the provided expectedVersion.
    func useAndValidate(argument: String, expectedVersion: ToolchainVersion) async throws {
        var use = try self.parseCommand(Use.self, ["use", argument])
        try await use.run()

        XCTAssertEqual(try Config.load().inUse, expectedVersion)

        let toolchainVersion = try self.getMockedToolchainVersion(
            at: Swiftly.currentPlatform.swiftlyBinDir.appendingPathComponent("swift")
        )
        XCTAssertEqual(toolchainVersion, expectedVersion)
    }

    /// Tests that the `use` command can switch between installed stable release toolchains.
    func testUseStable() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Self.allToolchains) {
            try await self.useAndValidate(argument: Self.oldStable.name, expectedVersion: Self.oldStable)
            try await self.useAndValidate(argument: Self.newStable.name, expectedVersion: Self.newStable)
            try await self.useAndValidate(argument: Self.newStable.name, expectedVersion: Self.newStable)
        }
    }

    /// Tests that that "latest" can be provided to the `use` command to select the installed stable release
    /// toolchain with the most recent version.
    func testUseLatestStable() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Self.allToolchains) {
            // Use an older toolchain.
            try await self.useAndValidate(argument: Self.oldStable.name, expectedVersion: Self.oldStable)

            // Use latest, assert that it switched to the latest installed stable release.
            try await self.useAndValidate(argument: "latest", expectedVersion: Self.newStable)

            // Try to use latest again, assert no error was thrown and no changes were made.
            try await self.useAndValidate(argument: "latest", expectedVersion: Self.newStable)

            // Explicitly specify the current latest toolchain, assert no errors and no changes were made.
            try await self.useAndValidate(argument: Self.newStable.name, expectedVersion: Self.newStable)

            // Switch back to the old toolchain, verify it works.
            try await self.useAndValidate(argument: Self.oldStable.name, expectedVersion: Self.oldStable)
        }
    }

    /// Tests that the latest installed patch release toolchain for a given major/minor version pair can be selected by
    /// omitting the patch version (e.g. `use 5.6`).
    func testUseLatestStablePatch() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Self.allToolchains) {
            try await self.useAndValidate(argument: Self.oldStable.name, expectedVersion: Self.oldStable)

            let oldStableVersion = Self.oldStable.asStableRelease!

            // Drop the patch version and assert that the latest patch of the provided major.minor was chosen.
            try await self.useAndValidate(
                argument: "\(oldStableVersion.major).\(oldStableVersion.minor)",
                expectedVersion: Self.oldStableNewPatch
            )

            // Assert that selecting it again doesn't change anything.
            try await self.useAndValidate(
                argument: "\(oldStableVersion.major).\(oldStableVersion.minor)",
                expectedVersion: Self.oldStableNewPatch
            )

            // Switch back to an older patch, try selecting a newer version that isn't installed, and assert
            // that nothing changed.
            try await self.useAndValidate(argument: Self.oldStable.name, expectedVersion: Self.oldStable)
            let latestPatch = Self.oldStableNewPatch.asStableRelease!.patch
            try await self.useAndValidate(
                argument: "\(oldStableVersion.major).\(oldStableVersion.minor).\(latestPatch + 1)",
                expectedVersion: Self.oldStable
            )
        }
    }

    /// Tests that the `use` command can switch between installed main snapshot toolchains.
    func testUseMainSnapshot() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Self.allToolchains) {
            // Switch to a non-snapshot.
            try await self.useAndValidate(argument: Self.newStable.name, expectedVersion: Self.newStable)
            try await self.useAndValidate(argument: Self.oldMainSnapshot.name, expectedVersion: Self.oldMainSnapshot)
            try await self.useAndValidate(argument: Self.newMainSnapshot.name, expectedVersion: Self.newMainSnapshot)
            // Verify that using the same snapshot again doesn't throw an error.
            try await self.useAndValidate(argument: Self.newMainSnapshot.name, expectedVersion: Self.newMainSnapshot)
            try await self.useAndValidate(argument: Self.oldMainSnapshot.name, expectedVersion: Self.oldMainSnapshot)
        }
    }

    /// Tests that the latest installed main snapshot toolchain can be selected by omitting the
    /// date (e.g. `use main-snapshot`).
    func testUseLatestMainSnapshot() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Self.allToolchains) {
            // Switch to a non-snapshot.
            try await self.useAndValidate(argument: Self.newStable.name, expectedVersion: Self.newStable)
            // Switch to the latest main snapshot.
            try await self.useAndValidate(argument: "main-snapshot", expectedVersion: Self.newMainSnapshot)
            // Switch to it again, assert no errors or changes were made.
            try await self.useAndValidate(argument: "main-snapshot", expectedVersion: Self.newMainSnapshot)
            // Switch to it again, this time by name. Assert no errors or changes were made.
            try await self.useAndValidate(argument: Self.newMainSnapshot.name, expectedVersion: Self.newMainSnapshot)
            // Switch to an older snapshot, verify it works.
            try await self.useAndValidate(argument: Self.oldMainSnapshot.name, expectedVersion: Self.oldMainSnapshot)
        }
    }

    /// Tests that the `use` command can switch between installed release snapshot toolchains.
    func testUseReleaseSnapshot() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Self.allToolchains) {
            // Switch to a non-snapshot.
            try await self.useAndValidate(argument: Self.newStable.name, expectedVersion: Self.newStable)
            try await self.useAndValidate(
                argument: Self.oldReleaseSnapshot.name,
                expectedVersion: Self.oldReleaseSnapshot
            )
            try await self.useAndValidate(
                argument: Self.newReleaseSnapshot.name,
                expectedVersion: Self.newReleaseSnapshot
            )
            // Verify that using the same snapshot again doesn't throw an error.
            try await self.useAndValidate(
                argument: Self.newReleaseSnapshot.name,
                expectedVersion: Self.newReleaseSnapshot
            )
            try await self.useAndValidate(
                argument: Self.oldReleaseSnapshot.name,
                expectedVersion: Self.oldReleaseSnapshot
            )
        }
    }

    /// Tests that the latest installed release snapshot toolchain can be selected by omitting the
    /// date (e.g. `use 5.7-snapshot`).
    func testUseLatestReleaseSnapshot() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Self.allToolchains) {
            // Switch to a non-snapshot.
            try await self.useAndValidate(argument: Self.newStable.name, expectedVersion: Self.newStable)
            // Switch to the latest snapshot for the given release.
            guard case let .release(major, minor) = Self.newReleaseSnapshot.asSnapshot!.branch else {
                fatalError("expected release in snapshot release version")
            }
            try await self.useAndValidate(
                argument: "\(major).\(minor)-snapshot",
                expectedVersion: Self.newReleaseSnapshot
            )
            // Switch to it again, assert no errors or changes were made.
            try await self.useAndValidate(
                argument: "\(major).\(minor)-snapshot",
                expectedVersion: Self.newReleaseSnapshot
            )
            // Switch to it again, this time by name. Assert no errors or changes were made.
            try await self.useAndValidate(
                argument: Self.newReleaseSnapshot.name,
                expectedVersion: Self.newReleaseSnapshot
            )
            // Switch to an older snapshot, verify it works.
            try await self.useAndValidate(
                argument: Self.oldReleaseSnapshot.name,
                expectedVersion: Self.oldReleaseSnapshot
            )
        }
    }

    /// Tests that the `use` command gracefully exits when executed before any toolchains have been installed.
    func testUseNoInstalledToolchains() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: []) {
            var use = try self.parseCommand(Use.self, ["use", "latest"])
            try await use.run()

            var config = try Config.load()
            XCTAssertEqual(config.inUse, nil)

            use = try self.parseCommand(Use.self, ["use", "5.6.0"])
            try await use.run()

            config = try Config.load()
            XCTAssertEqual(config.inUse, nil)
        }
    }

    /// Tests that the `use` command gracefully handles being executed with toolchain names that haven't been installed.
    func testUseNonExistent() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Self.allToolchains) {
            // Switch to a valid toolchain.
            try await self.useAndValidate(argument: Self.oldStable.name, expectedVersion: Self.oldStable)

            // Try various non-existent toolchains.
            try await self.useAndValidate(argument: "1.2.3", expectedVersion: Self.oldStable)
            try await self.useAndValidate(argument: "5.7-snapshot-1996-01-01", expectedVersion: Self.oldStable)
            try await self.useAndValidate(argument: "6.7-snapshot", expectedVersion: Self.oldStable)
            try await self.useAndValidate(argument: "main-snapshot-1996-01-01", expectedVersion: Self.oldStable)
        }
    }

    /// Tests that the `use` command works with all the installed toolchains in this test harness.
    func testUseAll() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Self.allToolchains) {
            let config = try Config.load()

            for toolchain in config.installedToolchains {
                try await self.useAndValidate(
                    argument: toolchain.name,
                    expectedVersion: toolchain
                )
            }
        }
    }

    /// Tests that the `use` command symlinks all of the executables provided in a toolchain and removes any existing
    /// symlinks from the previously active toolchain.
    func testOldSymlinksRemoved() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Self.allToolchains) {
            let spec = [
                ToolchainVersion(major: 1, minor: 2, patch: 3): ["a", "b"],
                ToolchainVersion(major: 2, minor: 3, patch: 4): ["b", "c", "d"],
                ToolchainVersion(major: 3, minor: 4, patch: 5): ["a", "c", "d", "e"],
            ]

            for (toolchain, files) in spec {
                try await self.installMockedToolchain(toolchain: toolchain, executables: files)
            }

            // Add an unrelated executable to the binary directory.
            let existingFileName = "existing"
            let existingExecutableURL = Swiftly.currentPlatform.swiftlyBinDir.appendingPathComponent(existingFileName)
            let data = "hello world\n".data(using: .utf8)!
            try data.write(to: existingExecutableURL)

            for (toolchain, files) in spec {
                var use = try self.parseCommand(Use.self, ["use", toolchain.name])
                try await use.run()

                // Verify that only the symlinks for the active toolchain remain.
                let symlinks = try FileManager.default.contentsOfDirectory(
                    atPath: Swiftly.currentPlatform.swiftlyBinDir.path
                )
                XCTAssertEqual(symlinks.sorted(), (files + [existingFileName]).sorted())

                // Verify that any all the symlinks point to the right toolchain.
                for file in files {
                    guard file != existingFileName else {
                        continue
                    }
                    let observedVersion = try self.getMockedToolchainVersion(
                        at: Swiftly.currentPlatform.swiftlyBinDir.appendingPathComponent(file)
                    )
                    XCTAssertEqual(observedVersion, toolchain)
                }
            }
        }
    }

    /// Tests that any executables that already exist in SWIFTLY_BIN_DIR.
    func testExistingExecutablesNotOverwritten() async throws {
        try await self.withMockedHome(homeName: Self.homeName, toolchains: []) {
            let existingExecutables = ["a", "b", "c"]
            let existingText = "existing"
            for fileName in existingExecutables {
                let existingExecutableURL = Swiftly.currentPlatform.swiftlyBinDir.appendingPathComponent(fileName)
                let data = existingText.data(using: .utf8)!
                try data.write(to: existingExecutableURL)
            }

            let toolchain = ToolchainVersion(major: 7, minor: 2, patch: 3)
            try await self.installMockedToolchain(
                toolchain: toolchain,
                executables: ["a", "b", "c", "d", "e"]
            )

            var use = try self.parseCommand(Use.self, ["use", toolchain.name])
            let nOutput = try await use.runWithMockedIO(input: ["n"])

            for exec in existingExecutables {
                // Ensure we were prompted for each existing executable.
                XCTAssert(nOutput.contains(where: { $0.contains(exec) }))

                // Ensure files were not overwritten.
                let existingExecutableURL = Swiftly.currentPlatform.swiftlyBinDir.appendingPathComponent(exec)
                let contents = try String(contentsOf: existingExecutableURL, encoding: .utf8)
                XCTAssertEqual(contents, existingText)
            }

            let nConfig = try Config.load()
            XCTAssertEqual(nConfig.inUse, nil)

            let yOutput = try await use.runWithMockedIO(input: ["y"])

            // Ensure we were prompted for each existing executable.
            for exec in existingExecutables {
                XCTAssert(yOutput.contains(where: { $0.contains(exec) }))

                // Ensure files were overwritten.
                let existingExecutableURL = Swiftly.currentPlatform.swiftlyBinDir.appendingPathComponent(exec)
                let contents = try String(contentsOf: existingExecutableURL, encoding: .utf8)
                XCTAssertNotEqual(contents, existingText)
            }

            let yConfig = try Config.load()
            XCTAssertEqual(yConfig.inUse, toolchain)
        }
    }

    /// Tests that running a use command without an argument prints the currently in-use toolchain.
    func testPrintInUse() async throws {
        let toolchains = [
            Self.newStable,
            Self.newMainSnapshot,
            Self.newReleaseSnapshot,
        ]
        try await self.withMockedHome(homeName: Self.homeName, toolchains: Set(toolchains)) {
            for toolchain in toolchains {
                var use = try self.parseCommand(Use.self, ["use", toolchain.name])
                try await use.run()

                var useEmpty = try self.parseCommand(Use.self, ["use"])
                let output = try await useEmpty.runWithMockedIO()

                XCTAssert(output.contains(where: { $0.contains(String(describing: toolchain)) }))
            }
        }
    }
}
