import SwiftUI

struct ResultView: View {
    let originalImage: UIImage
    let generatedImage: UIImage
    let styleName: String
    let prompt: String
    let designId: UUID
    
    @State private var sliderValue: CGFloat = 0.5
    @State private var viewMode: ViewMode = .slider // Default to slider view as it's better
    @State private var isSaved = false
    @Environment(\.presentationMode) var presentationMode
    
    // Flag to control auto-save behavior
    private let autoSaveEnabled = true
    
    enum ViewMode {
        case sideBySide, slider
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // View mode toggle
                Picker("View Mode", selection: $viewMode) {
                    Text("Side by Side").tag(ViewMode.sideBySide)
                    Text("Slider").tag(ViewMode.slider)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Before/After images
                if viewMode == .sideBySide {
                    HStack(spacing: 8) {
                        VStack {
                            Image(uiImage: originalImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit) // Changed to fit to avoid overflow
                                .frame(maxHeight: 220) // Reduced height
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            Text("Before")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack {
                            Image(uiImage: generatedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit) // Changed to fit to avoid overflow
                                .frame(maxHeight: 220) // Reduced height
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
                            Image(uiImage: generatedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit) // Changed to fit to avoid overflow
                                .frame(width: geo.size.width, height: 350)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            // Original image (overlay with mask)
                            Image(uiImage: originalImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit) // Changed to fit to avoid overflow
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
                                .position(x: geo.size.width * sliderValue, y: geo.size.height / 2)
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            let newX = value.location.x
                                            sliderValue = min(max(newX / geo.size.width, 0), 1)
                                        }
                                )
                        }
                    }
                    .frame(height: 350) // Reduced height
                    
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
                
                // Design details
                VStack(alignment: .leading, spacing: 10) {
                    Text("Design Details")
                        .font(.headline)
                    
                    // Removed style name display since it's just a predefined prompt
                    
                    Text("Prompt:")
                        .foregroundColor(.secondary)
                    
                    Text(prompt)
                        .font(.system(size: 14)) // Smaller font
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Action buttons
                VStack(spacing: 15) {
                    Button(action: {
                        saveDesign()
                    }) {
                        HStack {
                            Image(systemName: isSaved ? "checkmark" : "square.and.arrow.down")
                            Text(isSaved ? "Saved to Gallery" : "Save Design")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isSaved)
                    
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
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            .onAppear {
                print("DEBUG: ResultView appeared")
                
                // Auto-save the design if enabled
                if autoSaveEnabled && !isSaved {
                    print("DEBUG: Auto-saving design")
                    saveDesign()
                }
            }
        }
        .navigationTitle("Design Result")
    }
    
    private func saveDesign() {
        print("DEBUG: Saving design with style: \(styleName)")
        print("DEBUG: Using existing design ID: \(designId)")
        
        // Create a new SavedDesign object with passed ID
        let design = SavedDesign(
            id: designId, // Use the passed design ID
            originalImage: originalImage,
            generatedImage: generatedImage,
            styleName: styleName,
            prompt: prompt
        )
        
        // Save to StorageService
        StorageService.shared.saveDesign(design)
        
        // Update UI
        isSaved = true
    }
    
    private func shareDesign() {
        // Create a composite image to share
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: originalImage.size.width * 2, height: originalImage.size.height))
        let compositeImage = renderer.image { ctx in
            originalImage.draw(in: CGRect(x: 0, y: 0, width: originalImage.size.width, height: originalImage.size.height))
            generatedImage.draw(in: CGRect(x: originalImage.size.width, y: 0, width: originalImage.size.width, height: originalImage.size.height))
        }
        
        // Share the composite image
        let activityVC = UIActivityViewController(activityItems: [compositeImage], applicationActivities: nil)
        
        // Present the share sheet
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
} 