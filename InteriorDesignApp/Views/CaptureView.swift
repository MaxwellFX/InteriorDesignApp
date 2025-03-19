import SwiftUI
import PhotosUI

struct CaptureView: View {
    @State private var selectedImage: UIImage? = nil
    @State private var isShowingImagePicker = false
    @State private var isShowingCamera = false
    @State private var selectedStyle: DesignStyle? = nil
    @State private var customPrompt: String = ""
    @State private var isGenerating = false
    @State private var showSuccessMessage = false
    
    var switchToLibraryTab: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Image selection area
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .frame(height: 300)
                    
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        VStack {
                            Image(systemName: "photo")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("Select a room photo")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .onTapGesture {
                    isShowingImagePicker = true
                }
                
                // Camera and photo library buttons
                HStack(spacing: 30) {
                    Button(action: {
                        isShowingCamera = true
                    }) {
                        VStack {
                            Image(systemName: "camera.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                            Text("Camera")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        isShowingImagePicker = true
                    }) {
                        VStack {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title)
                                .foregroundColor(.blue)
                            Text("Gallery")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                
                // Design style selection
                VStack(alignment: .leading, spacing: 10) {
                    Text("Select Design Style")
                        .font(.headline)
                        .padding(.leading)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(DesignStyle.styles) { style in
                                Button(action: {
                                    selectedStyle = style
                                    customPrompt = style.prompt
                                }) {
                                    VStack {
                                        ZStack {
                                            Circle()
                                                .fill(style.color.opacity(0.2))
                                                .frame(width: 60, height: 60)
                                            
                                            Image(systemName: style.iconName)
                                                .font(.system(size: 30))
                                                .foregroundColor(style.color)
                                        }
                                        .overlay(
                                            Circle()
                                                .stroke(selectedStyle?.id == style.id ? style.color : Color.clear, lineWidth: 2)
                                        )
                                        
                                        Text(style.name)
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Custom prompt
                VStack(alignment: .leading, spacing: 10) {
                    Text("Design Instructions")
                        .font(.headline)
                        .padding(.leading)
                    
                    TextEditor(text: $customPrompt)
                        .frame(height: 100)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                
                // Generate button
                Button(action: {
                    print("DEBUG: Generate Design button tapped")
                    generateDesign()
                }) {
                    if isGenerating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("Generate Design")
                                .fontWeight(.semibold)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canGenerate ? Color.blue : Color.blue.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.horizontal)
                .disabled(!canGenerate || isGenerating)
                
                // Success message
                if showSuccessMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Design added to My Designs")
                            .foregroundColor(.green)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.vertical)
            .navigationTitle("Create Design")
            .onAppear {
                print("DEBUG: CaptureView appeared")
                // Reset generating state when we come back to this view
                isGenerating = false
            }
            .onDisappear {
                print("DEBUG: CaptureView disappeared")
            }
        }
        .sheet(isPresented: $isShowingImagePicker, onDismiss: {
            print("DEBUG: Image picker dismissed")
        }) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .photoLibrary)
        }
        .sheet(isPresented: $isShowingCamera, onDismiss: {
            print("DEBUG: Camera dismissed")
        }) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .camera)
        }
        .onChange(of: selectedImage) { newImage in
            print("DEBUG: Selected image changed: \(newImage != nil ? "Image present" : "No image")")
        }
        .onChange(of: selectedStyle) { newStyle in
            print("DEBUG: Selected style changed to: \(newStyle?.name ?? "None")")
        }
    }
    
    private var canGenerate: Bool {
        selectedImage != nil && !customPrompt.isEmpty && selectedStyle != nil
    }
    
    private func generateDesign() {
        guard let image = selectedImage, !customPrompt.isEmpty, let style = selectedStyle else { return }
        
        print("DEBUG: Starting design generation for style: \(style.name)")
        isGenerating = true
        
        // Create a processing design with a new UUID that will be preserved
        let designId = UUID() // Generate a single UUID to use consistently
        let processingDesign = SavedDesign(
            id: designId, // Pass the UUID explicitly
            originalImage: image,
            styleName: style.name,
            prompt: customPrompt
        )
        
        // Save processing design to storage - the ID will be preserved
        let savedId = StorageService.shared.saveProcessingDesign(processingDesign)
        print("DEBUG: Created processing design with ID: \(savedId)")
        
        // Make a local copy of the data we need to avoid captured self reference issues
        let localPrompt = customPrompt
        let localStyle = style.name
        
        // Start API call in the background
        DispatchQueue.global(qos: .userInitiated).async {
            CozeAPIService.shared.generateDesign(image: image, prompt: localPrompt) { result in
                DispatchQueue.main.async {
                    // Reset state immediately when we get a result
                    isGenerating = false
                    showSuccessMessage = true
                    
                    // Hide success message after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        showSuccessMessage = false
                    }
                    
                    switch result {
                    case .success(let generatedImage):
                        // Update the design with the generated image
                        StorageService.shared.updateDesignWithResult(id: designId, generatedImage: generatedImage)
                        print("DEBUG: Design successfully generated and updated with ID: \(designId)")
                        
                        // Navigate to ResultView with the generated image and the SAME designId
                        self.presentResultView(
                            originalImage: image,
                            generatedImage: generatedImage,
                            styleName: localStyle,
                            prompt: localPrompt,
                            designId: designId
                        )
                        
                    case .failure(let error):
                        // Get specific error message
                        var errorMessage = error.localizedDescription
                        var isRateLimitError = false
                        
                        // Check for rate limit errors
                        if let apiError = error as? CozeAPIError, 
                           case .rateLimited(let message) = apiError {
                            errorMessage = "API Rate Limit Exceeded: Please try again later."
                            isRateLimitError = true
                            print("DEBUG: Rate limit error detected: \(message)")
                        }
                        
                        print("DEBUG: Error generating design: \(errorMessage)")
                        
                        // Auto-delete the design after notifying user
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            print("DEBUG: Auto-deleting failed design with ID: \(designId)")
                            StorageService.shared.deleteDesign(with: designId)
                            
                            // Show a toast message with the error before navigating
                            let toastMessage = isRateLimitError ? 
                                "Rate limit exceeded. Please try again later." : 
                                "Design generation failed. Please try again."
                                
                            // Alert user about the failure
                            self.showFailureAlert(message: toastMessage)
                        }
                        
                        // Switch to the library tab
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.navigateToLibrary()
                        }
                    }
                }
            }
        }
    }
    
    // Helper method to present ResultView
    private func presentResultView(originalImage: UIImage, generatedImage: UIImage, styleName: String, prompt: String, designId: UUID) {
        // Find the root view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            
            // Create a SwiftUI view for the ResultView
            let resultView = ResultView(
                originalImage: originalImage,
                generatedImage: generatedImage,
                styleName: styleName,
                prompt: prompt,
                designId: designId
            )
            
            // Create a UIHostingController to wrap the SwiftUI view
            let hostingController = UIHostingController(rootView: resultView)
            
            // Present the view controller
            rootViewController.present(hostingController, animated: true)
            
            print("DEBUG: Presented ResultView for design ID: \(designId)")
        }
    }
    
    // Helper method to navigate to library
    private func navigateToLibrary() {
        print("DEBUG: Switching to Library tab with processing design")
        // Clear selected image to allow a new design to be created
        selectedImage = nil
        selectedStyle = nil
        customPrompt = ""
        
        // Switch to library tab
        switchToLibraryTab()
    }
    
    // Helper method to show failure alert
    private func showFailureAlert(message: String) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            
            let alert = UIAlertController(
                title: "Generation Failed", 
                message: message,
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(
                title: "OK", 
                style: .default
            ))
            
            rootViewController.present(alert, animated: true)
        }
    }
}

struct CaptureView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CaptureView(switchToLibraryTab: {})
        }
    }
} 