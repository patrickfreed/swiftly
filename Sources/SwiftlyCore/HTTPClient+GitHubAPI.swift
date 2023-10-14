import _StringProcessing
import AsyncHTTPClient
import Foundation

extension SwiftlyHTTPClient {
    /// Get a JSON response from the GitHub REST API.
    /// This will use the authorization token set, if any.
    public func getFromGitHub<T: Decodable>(url: String) async throws -> T {
        var headers: [String: String] = [:]
        if let token = self.githubToken ?? ProcessInfo.processInfo.environment["SWIFTLY_GITHUB_TOKEN"] {
            headers["Authorization"] = "Bearer \(token)"
        }

        return try await self.getFromJSON(url: url, type: T.self, headers: headers)
    }

    /// Function used to iterate over pages of GitHub tags/releases and map + filter them down.
    /// The `fetch` closure is used to retrieve the next page of results. It accepts the page number as its argument.
    /// The `filterMap` closure maps the input GitHub tag to an output. If it returns nil, it will not be included
    /// in the returned array.
    internal func mapGitHubTags<T>(
        limit: Int?,
        filterMap: (GitHubTag) throws -> T?,
        fetch: (Int) async throws -> [GitHubTag]
    ) async throws -> [T] {
        var page = 1
        var found: [T] = []

        let limit = limit ?? Int.max

        while true {
            let results = try await fetch(page)
            guard !results.isEmpty else {
                return found
            }

            for githubRelease in results {
                guard let out = try filterMap(githubRelease) else {
                    continue
                }
                found.append(out)

                guard found.count < limit else {
                    return found
                }
            }

            page += 1
        }
    }

    /// Get a list of releases on the apple/swift GitHub repository.
    /// The releases are returned in "pages" of `perPage` releases (default 100). The page argument specifies the
    /// page number.
    ///
    /// The results are returned in lexicographic order.
    internal func getReleases(page: Int, perPage: Int = 100) async throws -> [GitHubTag] {
        let url = "https://api.github.com/repos/apple/swift/releases?per_page=\(perPage)&page=\(page)"
        let releases: [GitHubRelease] = try await self.getFromGitHub(url: url)
        return releases.filter { !$0.prerelease }.map { $0.toGitHubTag() }
    }

    /// Get a list of tags on the apple/swift GitHub repository.
    /// The tags are returned in pages of 100. The page argument specifies the page number.
    ///
    /// The results are returned in lexicographic order.
    internal func getTags(page: Int) async throws -> [GitHubTag] {
        let url = "https://api.github.com/repos/apple/swift/tags?per_page=100&page=\(page)"
        return try await self.getFromGitHub(url: url)
    }
}

/// Model of a GitHub REST API release object.
/// See: https://docs.github.com/en/rest/releases/releases?apiVersion=2022-11-28#list-releases
private struct GitHubRelease: Decodable {
    fileprivate let name: String
    fileprivate let prerelease: Bool

    fileprivate func toGitHubTag() -> GitHubTag {
        GitHubTag(name: self.name, commit: nil)
    }
}

/// Model of a GitHub REST API tag/release object.
internal struct GitHubTag: Decodable {
    internal struct Commit: Decodable {
        internal let sha: String
    }

    /// The name of the release.
    /// e.g. "Swift a.b[.c] Release" or "swift-5.7-DEVELOPMENT-SNAPSHOT-2022-08-30-a".
    internal let name: String

    /// The commit associated with the tag.
    /// This is not present for releases.
    internal let commit: Commit?

    internal func parseStableRelease() throws -> ToolchainVersion.StableRelease? {
        // names look like Swift a.b.c Release
        let parts = self.name.split(separator: " ")
        guard parts.count >= 2 else {
            return nil
        }

        // versions can be a.b.c or a.b for .0 releases
        let versionParts = parts[1].split(separator: ".")
        guard
            versionParts.count >= 2,
            let major = Int(versionParts[0]),
            let minor = Int(versionParts[1])
        else {
            return nil
        }

        let patch: Int
        if versionParts.count == 3 {
            guard let p = Int(versionParts[2]) else {
                return nil
            }
            patch = p
        } else {
            patch = 0
        }

        return ToolchainVersion.StableRelease(major: major, minor: minor, patch: patch)
    }

    private static let snapshotRegex: Regex<(Substring, Substring?, Substring?, Substring)> =
        try! Regex("swift(?:-(\\d+)\\.(\\d+))?-DEVELOPMENT-SNAPSHOT-(\\d{4}-\\d{2}-\\d{2})")

    internal func parseSnapshot() throws -> ToolchainVersion.Snapshot? {
        guard let match = try Self.snapshotRegex.firstMatch(in: self.name) else {
            return nil
        }

        let branch: ToolchainVersion.Snapshot.Branch
        if let majorString = match.output.1, let minorString = match.output.2 {
            guard let major = Int(majorString), let minor = Int(minorString) else {
                throw Error(message: "malformatted release branch: \"\(majorString).\(minorString)\"")
            }
            branch = .release(major: major, minor: minor)
        } else {
            branch = .main
        }

        return ToolchainVersion.Snapshot(branch: branch, date: String(match.output.3))
    }
}
