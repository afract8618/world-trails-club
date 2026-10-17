import SwiftUI
import WorldTrailsCore

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Group {
            if model.progress.hasCompletedOnboarding {
                MainTabView()
            } else {
                WelcomeView()
            }
        }
        .fullScreenCover(item: $model.activeRequest) { request in
            RoundFlowView(request: request)
                .environment(model)
        }
        .sheet(isPresented: $model.showPaywall) {
            PlusView().environment(model)
        }
        .overlay(alignment: .top) {
            if let error = model.saveError {
                Text(error)
                    .font(Theme.caption)
                    .padding(10)
                    .background(Theme.danger.opacity(0.15), in: Capsule())
                    .padding(.top, 8)
                    .accessibilityAddTraits(.isStaticText)
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
            WorldMapView()
                .tabItem { Label("Map", systemImage: "map") }
            PassportView()
                .tabItem { Label("Passport", systemImage: "book.closed") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }
}
