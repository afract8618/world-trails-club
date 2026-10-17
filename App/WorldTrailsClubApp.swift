import SwiftUI
import WorldTrailsCore

@main
struct WorldTrailsClubApp: App {
    @State private var launch = LaunchState.make()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                switch launch {
                case .ready(let model):
                    RootView()
                        .environment(model)
                        .task { await model.purchases.refreshEntitlements() }
                        .onChange(of: scenePhase) { _, phase in
                            switch phase {
                            case .active: model.sessionDidBegin()
                            case .background: model.sessionDidEnd()
                            default: break
                            }
                        }
                case .failed(let message):
                    ErrorStateView(message: message) { launch = LaunchState.make() }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.paper)
                }
            }
            .tint(Theme.terracotta)
        }
    }
}

@MainActor
enum LaunchState {
    case ready(AppModel)
    case failed(String)

    static func make() -> LaunchState {
        let args = ProcessInfo.processInfo.arguments
        let isUITest = args.contains("-uitest")
        do {
            let pack = try ContentLoader.loadBundled()
            let store: ProgressStore?
            if isUITest {
                // UI tests start from a clean, throwaway save every launch.
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("uitest-progress.json")
                store = ProgressStore(fileURL: url)
                store?.reset()
            } else {
                store = try? ProgressStore.defaultStore()
            }
            let model = AppModel(pack: pack, store: store, ads: SimulatedAdService(),
                                 purchases: PurchaseManager(), sinks: [LogAnalyticsSink()])
            return .ready(model)
        } catch {
            return .failed((error as? LocalizedError)?.errorDescription ?? "The game content couldn't be loaded.")
        }
    }
}
