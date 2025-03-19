import SwiftUI
import UIKit
import Photos

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var sourceType: UIImagePickerController.SourceType
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = context.coordinator
        
        // Check if the source type is available
        if UIImagePickerController.isSourceTypeAvailable(sourceType) {
            imagePicker.sourceType = sourceType
        } else {
            print("DEBUG: Source type \(sourceType.rawValue) is not available")
            // Default to photo library if camera isn't available
            imagePicker.sourceType = .photoLibrary
        }
        
        // Configure based on source type
        if sourceType == .camera {
            // Set camera user interface style to minimize warnings
            imagePicker.cameraDevice = .rear
            imagePicker.cameraCaptureMode = .photo
            imagePicker.showsCameraControls = true
        }
        
        imagePicker.allowsEditing = true
        return imagePicker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePicker>) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
            super.init()
            print("DEBUG: ImagePicker coordinator initialized for source type: \(parent.sourceType.rawValue)")
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            print("DEBUG: Image was selected from picker")
            
            if let editedImage = info[.editedImage] as? UIImage {
                parent.selectedImage = editedImage
                print("DEBUG: Using edited image")
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImage = originalImage
                print("DEBUG: Using original image")
            } else {
                print("DEBUG: No image found in picker info")
            }
            
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            print("DEBUG: Image picker was cancelled")
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
} 