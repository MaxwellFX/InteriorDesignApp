import SwiftUI

// This is a design detail view for saved designs
struct DesignDetailView: View {
    let design: SavedDesign
    @State private var viewMode: ViewMode = .slider
    @State private var sliderValue: CGFloat = 0.5
    @Environment(\.presentationMode) var presentationMode
    @State private var hasLoadedView = false
    @State private var showingDeleteConfirmation = false
    
    // View mode enum
    enum ViewMode {
        case slider
        case sideBySide
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // View mode selector - only show for completed designs
                if design.generatedImage != nil {
                    Picker("View Mode", selection: $viewMode) {
                        Text("Slider").tag(ViewMode.slider)
                        Text("Side by Side").tag(ViewMode.sideBySide)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                }
                
                // Style name
                Text(design.styleName)
                    .font(.title)
                    .fontWeight(.semibold)
                
                // Image comparison - only show if we have a generated image
                if design.generatedImage != nil {
                    if viewMode == .sideBySide {
                        // Side-by-side comparison
                        HStack(spacing: 15) {
                            VStack {
                                Image(uiImage: design.originalImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 220)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                
                                Text("Before")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack {
                                Image(uiImage: design.generatedImage!)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 220)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                
                                Text("After")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        // Slider comparison view
                        ZStack {
                            GeometryReader { geo in
                                // Generated image (background)
                                Image(uiImage: design.generatedImage!)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: geo.size.width, height: 350)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                
                                // Original image (overlay with mask)
                                Image(uiImage: design.originalImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: geo.size.width, height: 350)
                                    .clipShape(
                                        Rectangle()
                                            .size(
                                                width: geo.size.width * sliderValue,
                                                height: 350
                                            )
                                            .offset(x: 0, y: 0)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                
                                // Divider line
                                Rectangle()
                                    .fill(Color.white)
                                    .frame(width: 2, height: 350)
                                    .position(x: geo.size.width * sliderValue, y: 175)
                                
                                // Drag handle
                                Circle()
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(.white)
                                    .shadow(radius: 3)
                                    .position(x: geo.size.width * sliderValue, y: 175)
                                    .gesture(
                                        DragGesture()
                                            .onChanged { value in
                                                let newX = value.location.x
                                                sliderValue = min(max(newX / geo.size.width, 0), 1)
                                            }
                                    )
                            }
                        }
                        .frame(height: 350)
                        
                        // Labels
                        HStack {
                            Text("Before")
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("After")
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 30)
                    }
                } else {
                    // Error case - no generated image
                    VStack(spacing: 20) {
                        Image(uiImage: design.originalImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        Text("Original Image")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if case .failed(let error) = design.status {
                            VStack(spacing: 10) {
                                Text("Generation Failed")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                    .padding(.top, 5)
                                
                                Text("Error Message:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text(error)
                                    .font(.body)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal)
                        } else {
                            Text("Generated image not available")
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding()
                        }
                    }
                    .padding()
                }
                
                // Design details
                VStack(alignment: .leading, spacing: 10) {
                    Text("Design Details")
                        .font(.headline)
                    
                    Text("Prompt:")
                        .foregroundColor(.secondary)
                    
                    Text(design.prompt)
                        .font(.system(size: 14))
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    HStack {
                        Text("Created:")
                            .foregroundColor(.secondary)
                        Text(design.createdAt, style: .date)
                            .font(.subheadline)
                    }
                    
                    if case .failed(let error) = design.status {
                        Text("Status: Failed")
                            .foregroundColor(.red)
                            .padding(.top, 5)
                        
                        Text("Error: \(error)")
                            .font(.footnote)
                            .foregroundColor(.red)
                            .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Action buttons
                VStack(spacing: 15) {
                    // Share button - only if we have a generated image
                    if design.generatedImage != nil {
                        Button(action: {
                            shareDesign()
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Delete button
                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Design")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .alert(isPresented: $showingDeleteConfirmation) {
                        Alert(
                            title: Text("Delete Design"),
                            message: Text("Are you sure you want to delete this design? This action cannot be undone."),
                            primaryButton: .destructive(Text("Delete")) {
                                deleteDesign()
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
                .padding(.bottom)
            }
            .padding(.vertical)
        }
        .navigationTitle("Design")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            print("DEBUG: DesignDetailView fully appeared - \(design.styleName)")
            // Set flag that we've loaded the view
            hasLoadedView = true
        }
        .onDisappear {
            print("DEBUG: DesignDetailView disappeared - \(design.styleName)")
        }
    }
    
    private func shareDesign() {
        guard let generatedImage = design.generatedImage else { return }
        
        // Create a composite image to share
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: design.originalImage.size.width * 2, height: design.originalImage.size.height))
        let compositeImage = renderer.image { ctx in
            design.originalImage.draw(in: CGRect(x: 0, y: 0, width: design.originalImage.size.width, height: design.originalImage.size.height))
            generatedImage.draw(in: CGRect(x: design.originalImage.size.width, y: 0, width: design.originalImage.size.width, height: design.originalImage.size.height))
        }
        
        // Share the composite image
        let activityVC = UIActivityViewController(activityItems: [compositeImage], applicationActivities: nil)
        
        // Present the share sheet
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
    
    private func deleteDesign() {
        guard let designId = design.id as UUID? else {
            print("DEBUG: DesignDetailView - Error: Invalid design ID")
            return
        }
        
        print("DEBUG: DesignDetailView - Starting deletion for design ID: \(designId)")
        
        // Dismiss the view first
        presentationMode.wrappedValue.dismiss()
        print("DEBUG: DesignDetailView - View dismissed")
        
        // Then perform deletion after a slight delay to ensure navigation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("DEBUG: DesignDetailView - Executing deletion for ID: \(designId)")
            
            // Execute ID-based deletion through the StorageService
            StorageService.shared.deleteDesign(with: designId)
            
            // Force UI update through notifications
            print("DEBUG: DesignDetailView - Posting notifications")
            NotificationCenter.default.post(name: NSNotification.Name("DesignDeleted"), object: nil)
            NotificationCenter.default.post(name: Notification.Name("DesignsUpdated"), object: nil)
        }
    }
} 