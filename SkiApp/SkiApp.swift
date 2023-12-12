//
//  Skisensor2App.swift
//  SkiApp

import SwiftUI
import Sentry


@main
struct SkiApp: App {
    init() {
        SentrySDK.start { options in
            options.dsn = "https://def07200321ba7480a50f1cf68ddf02d@o524370.ingest.sentry.io/4506316297076736"
            options.debug = true // Enabled debug when first installing is always helpful
            options.tracesSampleRate = 0.05

            // Uncomment the following lines to add more data to your events
            // options.attachScreenshot = true // This adds a screenshot to the error events
            // options.attachViewHierarchy = true // This adds the view hierarchy to the error events
        }
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
