//
//  Zipper.swift
//  swift-create-xcframework
//
//  Created by Rob Amos on 13/5/20.
//

import Foundation
import PackageModel
import TSCBasic
import Workspace

struct Zipper {
    
    // MARK: - Properties
    
    let package: PackageInfo
    
    init (package: PackageInfo) {
        self.package = package
    }
    
    
    // MARK: - Zippering
    
    func zip (target: String, version: String?, file: Foundation.URL) throws -> Foundation.URL {
        
        let suffix = self.versionSuffix(target: target, default: version) ?? ""
        let zipPath = file.path.replacingOccurrences(of: "\\.xcframework$", with: "\(suffix).zip", options: .regularExpression)
        let zipURL = URL(fileURLWithPath: zipPath)
        
        let process = TSCBasic.Process (
            arguments: self.zipCommand(source: file, target: zipURL),
            outputRedirection: .none
        )
        
        print("\nPackaging \(file.path) into \(zipURL.path)\n\n")
        try process.launch()
        let result = try process.waitUntilExit()

        switch result.exitStatus {
        case let .terminated(code: code):
            if code != 0 {
                throw XcodeBuilder.Error.nonZeroExit(code)
            }
        case let .signalled(signal: signal):
            throw XcodeBuilder.Error.signalExit(signal)
        }

        return zipURL
    }
    
    private func zipCommand (source: Foundation.URL, target: Foundation.URL) -> [String] {
        return [
            "ditto",
            "-c",
            "-k",
            "--keepParent",
            source.path,
            target.path
        ]
    }
    
    private func versionSuffix (target: String, default fallback: String?) -> String? {
        
        // find the package that contains our target
        guard let packageRef = self.package.graph.packages.first(where: { $0.targets.contains(where: { $0.name == target } ) }) else { return nil }

        // ok lets ask the workspace for that package's version
        guard let resources = try? UserManifestResources(swiftCompiler: self.package.toolchain.swiftCompiler) else { return nil }
        let workspace = Workspace.create(forRootPackage: AbsolutePath(self.package.rootDirectory.path), manifestLoader: ManifestLoader(manifestResources: resources))

        guard
            let dependency = try? workspace.managedDependencies.dependency(forNameOrIdentity: packageRef.name),
            case let .checkout(checkout) = dependency.state,
            let version = checkout.version
        else {
            return fallback.flatMap { "-" + $0 }
        }

        return "-" + version.description
    }
    
    
    // MARK: - Cleaning
    
    func clean (file: Foundation.URL) throws {
        try FileManager.default.removeItem(at: file)
    }
}
