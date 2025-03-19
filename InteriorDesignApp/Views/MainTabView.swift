import SwiftUI
import Combine

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var resetLibraryNavigation = false
    @State private var notificationToken: Any?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(switchToLibraryTab: switchToLibraryTab)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)
            
            NavigationView {
                LibraryView(forceReset: resetLibraryNavigation)
                    .id(resetLibraryNavigation)
                    .onAppear {
                        print("DEBUG: MainTabView - LibraryView appeared with forceReset: \(resetLibraryNavigation)")
                        // Reset the flag after appearing
                        if resetLibraryNavigation {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                resetLibraryNavigation = false
                                print("DEBUG: MainTabView - Reset flag cleared")
                            }
                        }
                    }
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Label("My Designs", systemImage: "photo.on.rectangle")
            }
            .tag(1)
        }
        .onChange(of: selectedTab) { newValue in
            // Reset library navigation when switching to the library tab
            if newValue == 1 {
                print("DEBUG: MainTabView - Switching to My Designs tab, forcing navigation reset")
                forceRefreshLibraryView()
            }
        }
        .onAppear {
            print("DEBUG: MainTabView - Appeared")
            // Set up notification observer for design deletion events
            setupNotificationObservers()
        }
        .onDisappear {
            print("DEBUG: MainTabView - Disappeared")
            // Remove notification observer
            if let token = notificationToken {
                NotificationCenter.default.removeObserver(token)
                notificationToken = nil
            }
        }
    }
    
    // Set up the notification observer
    private func setupNotificationObservers() {
        // Remove any existing observer
        if let token = notificationToken {
            NotificationCenter.default.removeObserver(token)
            notificationToken = nil
        }
        
        print("DEBUG: MainTabView - Setting up DesignDeleted notification observer")
        notificationToken = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DesignDeleted"),
            object: nil,
            queue: .main) { notification in
                print("DEBUG: MainTabView - Received design deletion notification")
                // If we're already on the library tab, force a refresh
                if selectedTab == 1 {
                    print("DEBUG: MainTabView - On library tab, forcing refresh")
                    forceRefreshLibraryView()
                } else {
                    print("DEBUG: MainTabView - Not on library tab, setting flag for next appearance")
                    // Set flag to refresh when tab is selected
                    resetLibraryNavigation = true
                }
        }
        
        // Also observe DesignsUpdated notifications
        NotificationCenter.default.addObserver(
            forName: Notification.Name("DesignsUpdated"),
            object: nil,
            queue: .main) { notification in
                print("DEBUG: MainTabView - Received designs updated notification")
                // If we're already on the library tab, consider a refresh
                if selectedTab == 1 {
                    print("DEBUG: MainTabView - On library tab, considering refresh")
                }
        }
    }
    
    // Helper to force refresh the library view
    private func forceRefreshLibraryView() {
        print("DEBUG: MainTabView - FORCE REFRESH called")
        // Toggle the reset flag to force view recreation
        resetLibraryNavigation = true
        
        // Also reset UserDefaults observation path to ensure changes are picked up
        UserDefaults.standard.synchronize()
        
        // Schedule reset of the flag after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            print("DEBUG: MainTabView - Setting resetLibraryNavigation back to false")
            resetLibraryNavigation = false
            
            // Also post notification to refresh designs
            NotificationCenter.default.post(name: Notification.Name("DesignsUpdated"), object: nil)
        }
    }
    
    func switchToLibraryTab() {
        print("DEBUG: Programmatically switching to LibraryTab")
        forceRefreshLibraryView()
        selectedTab = 1
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
} 