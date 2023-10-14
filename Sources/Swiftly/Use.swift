import ArgumentParser
import SwiftlyCore

internal struct Use: SwiftlyCommand {
    public static var configuration = CommandConfiguration(
        abstract: "Set the active toolchain. If no toolchain is provided, print the currently in-use toolchain, if any."
    )

    @Argument(help: ArgumentHelp(
        "The toolchain to use.",
        discussion: """

        If no toolchain is provided, the currently in-use toolchain will be printed, if any:

            $ swiftly use

        The string "latest" can be provided to use the most recent stable version release:

            $ swiftly use latest

        A specific toolchain can be selected by providing a full toolchain name, for example \
        a stable release version with patch (e.g. a.b.c):

            $ swiftly use 5.4.2

        Or a snapshot with date:

            $ swiftly use 5.7-snapshot-2022-06-20
            $ swiftly use main-snapshot-2022-06-20

        The latest patch release of a specific minor version can be used by omitting the \
        patch version:

            $ swiftly use 5.6

        Likewise, the latest snapshot associated with a given development branch can be \
        used by omitting the date:

            $ swiftly use 5.7-snapshot
            $ swiftly use main-snapshot
        """
    ))
    var toolchain: String?

    internal mutating func run() async throws {
        var config = try Config.load()

        guard let toolchain = self.toolchain else {
            if let inUse = config.inUse {
                SwiftlyCore.print("\(inUse) (in use)")
            }
            return
        }

        let selector = try ToolchainSelector(parsing: toolchain)

        guard let toolchain = config.listInstalledToolchains(selector: selector).max() else {
            SwiftlyCore.print("No installed toolchains match \"\(toolchain)\"")
            return
        }

        try await Self.execute(toolchain, &config)
    }

    /// Use a toolchain. This method modifies and saves the input config.
    internal static func execute(_ toolchain: ToolchainVersion, _ config: inout Config) async throws {
        let previousToolchain = config.inUse

        guard toolchain != previousToolchain else {
            SwiftlyCore.print("\(toolchain) is already in use")
            return
        }

        guard try Swiftly.currentPlatform.use(toolchain, currentToolchain: previousToolchain) else {
            return
        }
        config.inUse = toolchain
        try config.save()

        var message = "Set the active toolchain to \(toolchain)"
        if let previousToolchain {
            message += " (was \(previousToolchain))"
        }

        SwiftlyCore.print(message)
    }
}
