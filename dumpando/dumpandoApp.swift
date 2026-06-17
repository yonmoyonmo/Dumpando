//
//  dumpandoApp.swift
//  dumpando
//
//  Created by yonmo on 6/17/26.
//

import SwiftUI
import SwiftData
import Foundation

@main
struct dumpandoApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            BrainDumpItem.self,
            LoopSession.self,
            LoopTask.self,
        ])
        let modelConfiguration = ModelConfiguration(
            "dumpando-v1",
            schema: schema,
            url: Self.storeURL(),
            allowsSave: true,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }

    private static func storeURL() -> URL {
        let fileManager = FileManager.default
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directoryURL = baseURL.appendingPathComponent("dumpando", isDirectory: true)

        if !fileManager.fileExists(atPath: directoryURL.path) {
            try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        return directoryURL.appendingPathComponent("dumpando-v1.store")
    }
}
