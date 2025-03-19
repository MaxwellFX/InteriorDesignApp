import SwiftUI
import Combine

// Thumbnail view component showing design and its status
struct DesignThumbnailView: View {
    let design: SavedDesign
    
    var body: some View {
        VStack(alignment: .center, spacing: 5) {
            // Design image with fixed square dimensions
            ZStack {
                    if let generatedImage = design.generatedImage {
                        Image(uiImage: generatedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                        .frame(width: 150, height: 150) // Fixed square dimensions
                        .cornerRadius(12)
                        .clipped()
                } else {
                    // Show original image with overlay for processing or failed designs
                    Image(uiImage: design.originalImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 150, height: 150) // Fixed square dimensions
                        .cornerRadius(12)
                        .clipped()
                    
                    // Status overlays
                    if case .processing = design.status {
                        // Processing overlay
                    ZStack {
                        Color.black.opacity(0.7)
                            .cornerRadius(12)
                        
                            VStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(1.0)
                                    .tint(.white)
                                    .padding(.bottom, 2)
                                
                                Text("PROCESSING")
                                    .font(.caption2)
                                    .bold()
                                    .foregroundColor(.white)
                            }
                        }
                    } else if case .failed = design.status {
                        // Failed overlay with dark red background
                        ZStack {
                            Color.red.opacity(0.8)
                                .cornerRadius(12)
                            
                            VStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 20))
                                .foregroundColor(.white)
                                    .padding(.bottom, 2)
                                
                                Text("GENERATION FAILED")
                                    .font(.caption2)
                                .bold()
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                    .padding(.horizontal, 4)
                            }
                        }
                    }
                }
            }
            
            // Caption with style name
            Text(design.styleName)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }
}

// Custom NavigationLink wrapper for designs
struct DesignLinkView: View {
    let design: SavedDesign
    @Binding var isDetailNavigationActive: Bool
    @State private var showToast = false
    @State private var toastMessage = ""
    
    var body: some View {
        if let generatedImage = design.generatedImage {
            // Completed design - can navigate
            NavigationLink(destination: DesignDetailView(design: design)) {
                DesignThumbnailView(design: design)
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            // Processing or failed design - show toast instead of navigating
            Button(action: {
            if case .processing = design.status {
                    showToastMessage("Design is still processing...")
                } else if case .failed = design.status {
                    showToastMessage("Design generation failed")
                }
            }) {
                DesignThumbnailView(design: design)
            }
            .buttonStyle(PlainButtonStyle())
            .overlay(
                Group {
                    if showToast {
                        VStack {
                            Text(toastMessage)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .foregroundColor(.primary)
                                .font(.caption)
                                .cornerRadius(8)
                                .shadow(radius: 1)
                        }
                        .transition(.move(edge: .bottom))
                        .animation(.easeInOut)
                        .zIndex(1)
                    }
                }, alignment: .bottom
            )
        }
    }
    
    private func showToastMessage(_ message: String) {
        toastMessage = message
        
        withAnimation {
            showToast = true
        }
        
        // Hide toast after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showToast = false
            }
        }
    }
}

// Main LibraryView struct
struct LibraryView: View {
    var forceReset: Bool = false
    @State private var savedDesigns: [SavedDesign] = []
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var navigationActive = false
    @State private var refreshTrigger = UUID() // Add refresh trigger
    
    // Navigation state control
    @State private var isDetailNavigationActive = false
    
    // Notification tokens (multiple tokens)
    @State private var deletedNotificationToken: Any?
    @State private var updatedNotificationToken: Any?
    
    // Grid layout - fixed 2-column layout like the side-by-side comparison
    private let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]
    
    // Combine subscription
    @State private var subscription: AnyCancellable?
    
    var body: some View {
        ScrollView {
            VStack {
                if savedDesigns.isEmpty {
                    // Empty state
            VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 70))
                            .foregroundColor(.gray)
                            .padding(.bottom, 10)
                        
                        Text("No Designs Yet")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("Your saved designs will appear here")
                                .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                } else {
                    // Designs grid
                    LazyVGrid(columns: columns, spacing: 16, content: {
                        ForEach(savedDesigns) { design in
                            DesignLinkView(design: design, isDetailNavigationActive: $isDetailNavigationActive)
                                .id("\(design.id)_\(refreshTrigger)")
                        }
                    })
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                }
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity) // Center everything
        }
        .id(refreshTrigger) // Force view refresh when trigger changes
        .navigationTitle("My Designs")
        .overlay(
            // Toast message
            Group {
                if showToast {
                    VStack {
                        Spacer()
                        Text(toastMessage)
                            .padding()
                            .background(Color(.systemGray6))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                            .shadow(radius: 3)
                            .padding(.bottom, 30)
                    }
                    .transition(.move(edge: .bottom))
                    .animation(.easeInOut)
                    .zIndex(1)
                }
            }
        )
        .onAppear {
            print("DEBUG: LibraryView appeared, forceReset: \(forceReset)")
            
            // Reset navigation state if needed
            if forceReset {
                print("DEBUG: LibraryView - Force reset triggered, resetting navigation state")
                isDetailNavigationActive = false
                refreshDesigns()
            } else {
                print("DEBUG: LibraryView - No force reset needed")
            }
            
            // Always force refresh on appear - this is critical for deletion to work
            print("DEBUG: LibraryView - Force refreshing designs on appear")
            refreshDesigns()
            
            // Set up Combine subscription if needed
            print("DEBUG: LibraryView - Setting up publisher subscription")
            setupSubscription()
            
            // Clean up any existing observers to avoid duplicates
            print("DEBUG: LibraryView - Cleaning up existing observers")
            removeAllObservers()
            
            // Set up notification observers for design updates and deletions
            print("DEBUG: LibraryView - Setting up DesignDeleted notification observer")
            deletedNotificationToken = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("DesignDeleted"), 
                object: nil, 
                queue: .main) { notification in
                    print("DEBUG: LibraryView - Received DesignDeleted notification")
                    
                    // Force reload designs and refresh UI
                    print("DEBUG: LibraryView - Refreshing designs in response to deletion")
                    self.refreshDesigns()
                    
                    // Show a confirmation toast
                    print("DEBUG: LibraryView - Showing deletion success toast")
                    self.showToastMessage("Design deleted successfully")
            }
            
            // Also observe general design updates
            print("DEBUG: LibraryView - Setting up DesignsUpdated notification observer")
            updatedNotificationToken = NotificationCenter.default.addObserver(
                forName: Notification.Name("DesignsUpdated"), 
                object: nil, 
                queue: .main) { notification in
                    print("DEBUG: LibraryView - Received DesignsUpdated notification")
                    
                    // Force reload designs
                    print("DEBUG: LibraryView - Refreshing designs in response to update")
                    self.refreshDesigns()
            }
        }
        .onDisappear {
            print("DEBUG: LibraryView is disappearing")
            
            // Clean up subscription when view disappears
            subscription?.cancel()
            subscription = nil
            
            // Remove all notification observers
            removeAllObservers()
            
            print("DEBUG: LibraryView disappeared and cleaned up resources")
        }
    }
    
    private func setupSubscription() {
        // Cancel existing subscription
        subscription?.cancel()
        
        // Create new subscription
        subscription = StorageService.shared.designsPublisher
            .receive(on: RunLoop.main)
            .sink { designs in
                print("DEBUG: LibraryView received \(designs.count) designs from publisher")
                self.savedDesigns = designs
            }
    }
    
    // Centralized refresh method
    private func refreshDesigns() {
        print("DEBUG: LibraryView - Starting design refresh")
        
        // Force view refresh
        let oldTrigger = refreshTrigger
        refreshTrigger = UUID()
        print("DEBUG: LibraryView - Changed refresh trigger")
        
        // Direct check of UserDefaults
        print("DEBUG: LibraryView - Performing direct UserDefaults check")
        let userDefaults = UserDefaults.standard
        let designsKey = "savedDesigns"
        if let rawDesignsMetadata = userDefaults.array(forKey: designsKey) as? [[String: Any]] {
            print("DEBUG: LibraryView - Found \(rawDesignsMetadata.count) designs directly in UserDefaults")
            
            // This is a critical step - update UserDefaults synchronization
            userDefaults.synchronize()
        } else {
            print("DEBUG: LibraryView - No designs found in UserDefaults")
        }
        
        // Force reload from StorageService
        print("DEBUG: LibraryView - Calling StorageService.loadAllDesigns()")
        let designs = StorageService.shared.loadAllDesigns()
        print("DEBUG: LibraryView - Received \(designs.count) designs from StorageService")
        
        // Compare with previous designs to detect changes
        let oldCount = savedDesigns.count
        let newCount = designs.count
        
        if oldCount != newCount {
            print("DEBUG: LibraryView - Design count changed from \(oldCount) to \(newCount)")
            
            if oldCount > newCount {
                print("DEBUG: LibraryView - Design deletion detected")
                
                // Try to identify which design was deleted
                let oldIds = Set(savedDesigns.map { $0.id })
                let newIds = Set(designs.map { $0.id })
                let deletedIds = oldIds.subtracting(newIds)
                
                if !deletedIds.isEmpty {
                    print("DEBUG: LibraryView - Detected deleted design IDs: \(deletedIds)")
                }
            } else {
                print("DEBUG: LibraryView - New design(s) detected")
            }
        } else {
            print("DEBUG: LibraryView - Design count unchanged: \(designs.count)")
        }
        
        // Update the UI
        print("DEBUG: LibraryView - Updating UI with refreshed designs")
        self.savedDesigns = designs
        
        // Also reset navigation state if it seems to be in a bad state
        if !designs.isEmpty && isDetailNavigationActive {
            print("DEBUG: LibraryView - Resetting navigation state")
            isDetailNavigationActive = false
        }
        
        print("DEBUG: LibraryView - Design refresh completed")
    }
    
    // Helper to clean up notification observers
    private func removeAllObservers() {
        // Remove design deleted observer
        if let token = deletedNotificationToken {
            print("DEBUG: LibraryView removing DesignDeleted notification observer")
            NotificationCenter.default.removeObserver(token)
            deletedNotificationToken = nil
        }
        
        // Remove designs updated observer
        if let token = updatedNotificationToken {
            print("DEBUG: LibraryView removing DesignsUpdated notification observer")
            NotificationCenter.default.removeObserver(token)
            updatedNotificationToken = nil
        }
    }
    
    private func showToastMessage(_ message: String) {
        toastMessage = message
        
        withAnimation {
            showToast = true
        }
        
        // Hide toast after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showToast = false
            }
        }
    }
} 