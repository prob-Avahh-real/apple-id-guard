import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = GuardViewModel()

    var body: some View {
        TabView {
            DashboardView(viewModel: viewModel)
                .tabItem {
                    Label("盾牌", systemImage: "shield.lefthalf.filled")
                }

            AlertsView(viewModel: viewModel)
                .tabItem {
                    Label("告警", systemImage: "bell.badge")
                }

            ImportView(viewModel: viewModel)
                .tabItem {
                    Label("导入", systemImage: "doc.text.magnifyingglass")
                }

            SettingsView(viewModel: viewModel)
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
        .task {
            _ = await NotificationService.requestAuthorization()
            BackgroundScheduler.register(handler: viewModel)
            BackgroundScheduler.scheduleNextRefresh(settings: viewModel.settings)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                viewModel.reload()
            }
        }
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
