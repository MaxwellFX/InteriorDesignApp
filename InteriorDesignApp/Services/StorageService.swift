import Foundation
import UIKit
import Combine

class StorageService {
    static let shared = StorageService()
    
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let designsKey = "savedDesigns"
    
    // Combine publisher for designs
    private let designsSubject = CurrentValueSubject<[SavedDesign], Never>([])
    var designsPublisher: AnyPublisher<[SavedDesign], Never> {
        designsSubject.eraseToAnyPublisher()
    }
    
    // Flag to indicate if a new design was just saved
    var hasNewDesign = false
    
    // Designs in memory for background processing
    private var inMemoryDesigns: [UUID: SavedDesign] = [:]
    
    private init() {
        print("DEBUG: StorageService initialized")
        
        // Get raw counts from UserDefaults
        if let rawDesigns = userDefaults.array(forKey: designsKey) as? [[String: Any]] {
            print("DEBUG: StorageService - on init: found \(rawDesigns.count) designs in UserDefaults")
        } else {
            print("DEBUG: StorageService - on init: no designs found in UserDefaults")
        }
        
        // Load designs initially
        let designs = loadAllDesignsInternal()
        print("DEBUG: StorageService - on init: loaded \(designs.count) designs into memory")
        
        // Update the publisher
        designsSubject.send(designs)
        
        // Verify UserDefaults after initialization
        verifyUserDefaultsState()
    }
    
    // Add a method to verify UserDefaults state
    private func verifyUserDefaultsState() {
        // Force synchronize first
        userDefaults.synchronize()
        
        // Get raw data from UserDefaults
        guard let rawMetadata = userDefaults.array(forKey: designsKey) as? [[String: Any]] else {
            print("DEBUG: StorageService - VERIFY: No metadata found in UserDefaults")
            return
        }
        
        print("DEBUG: StorageService - VERIFY: Found \(rawMetadata.count) designs in UserDefaults")
        
        // Print all design IDs for debugging
        print("DEBUG: StorageService - VERIFY: All design IDs in UserDefaults:")
        for (index, metadata) in rawMetadata.enumerated() {
            if let metadataId = metadata["id"] as? String {
                print("DEBUG: StorageService - VERIFY: Index \(index): \(metadataId)")
            } else {
                print("DEBUG: StorageService - VERIFY: Index \(index): Invalid ID")
            }
        }
    }
    
    // Save a design that's still processing (no generated image yet)
    func saveProcessingDesign(_ design: SavedDesign) -> UUID {
        print("DEBUG: StorageService - Saving processing design")
        
        // Keep the design's existing ID
        let designId = design.id
        
        // Save original image to documents directory
        let originalImagePath = saveImage(design.originalImage, name: "original_\(designId.uuidString)")
        
        // Create metadata to save in UserDefaults with processing status
        let designMetadata: [String: Any] = [
            "id": designId.uuidString,
            "originalImagePath": originalImagePath,
            "styleName": design.styleName,
            "prompt": design.prompt,
            "createdAt": design.createdAt.timeIntervalSince1970,
            "status": "processing"
        ]
        
        // Get existing designs
        var existingDesigns = getDesignsMetadata()
        existingDesigns.append(designMetadata)
        
        // Save updated list
        userDefaults.set(existingDesigns, forKey: designsKey)
        
        // Keep design in memory for updates
        inMemoryDesigns[designId] = design
        
        // Set flag to indicate a new design was saved
        hasNewDesign = true
        
        // Notify subscribers of the change
        notifyDesignsChanged()
        
        print("DEBUG: StorageService - Processing design saved with ID: \(designId)")
        return designId
    }
    
    // Update a processing design with completion
    func updateDesignWithResult(id: UUID, generatedImage: UIImage) {
        print("DEBUG: StorageService - Updating design with result for ID: \(id)")
        // Find the design metadata
        var designsMetadata = getDesignsMetadata()
        guard let index = designsMetadata.firstIndex(where: { ($0["id"] as? String)?.lowercased() == id.uuidString.lowercased() }) else {
            print("DEBUG: Could not find design with ID \(id) to update")
            return
        }
        
        // Save generated image
        let generatedImagePath = saveImage(generatedImage, name: "generated_\(id.uuidString)")
        
        // Update metadata
        var updatedMetadata = designsMetadata[index]
        updatedMetadata["generatedImagePath"] = generatedImagePath
        updatedMetadata["status"] = "completed"
        designsMetadata[index] = updatedMetadata
        
        // Save updated list
        userDefaults.set(designsMetadata, forKey: designsKey)
        
        // Update in-memory design if it exists
        if var design = inMemoryDesigns[id] {
            design.updateWithGeneratedImage(generatedImage)
            inMemoryDesigns[id] = design
        }
        
        // Notify subscribers of the change
        notifyDesignsChanged()
        
        print("DEBUG: StorageService - Design \(id) successfully updated with generated image")
    }
    
    // Update a processing design with error
    func updateDesignWithError(id: UUID, errorMessage: String) {
        print("DEBUG: StorageService - Updating design with error for ID: \(id)")
        // Find the design metadata
        var designsMetadata = getDesignsMetadata()
        guard let index = designsMetadata.firstIndex(where: { ($0["id"] as? String)?.lowercased() == id.uuidString.lowercased() }) else {
            print("DEBUG: Could not find design with ID \(id) to update with error")
            return
        }
        
        // Update metadata
        var updatedMetadata = designsMetadata[index]
        updatedMetadata["status"] = "failed"
        updatedMetadata["errorMessage"] = errorMessage
        designsMetadata[index] = updatedMetadata
        
        // Save updated list
        userDefaults.set(designsMetadata, forKey: designsKey)
        
        // Update in-memory design if it exists
        if var design = inMemoryDesigns[id] {
            design.updateWithError(errorMessage)
            inMemoryDesigns[id] = design
        }
        
        // Notify subscribers of the change
        notifyDesignsChanged()
    }
    
    // Public method - now just returns the publisher
    func loadAllDesigns() -> [SavedDesign] {
        // Return current value from the internal method
        return loadAllDesignsInternal()
    }
    
    // Private method that does the actual loading
    private func loadAllDesignsInternal() -> [SavedDesign] {
        print("DEBUG: StorageService - Loading all designs")
        let designsMetadata = getDesignsMetadata()
        
        var designs: [SavedDesign] = []
        var invalidDesignsToRemove: [Int] = []
        
        for (index, metadata) in designsMetadata.enumerated() {
            guard
                let idString = metadata["id"] as? String,
                let originalImagePath = metadata["originalImagePath"] as? String,
                let styleName = metadata["styleName"] as? String,
                let prompt = metadata["prompt"] as? String,
                let createdAtTimestamp = metadata["createdAt"] as? TimeInterval
            else {
                print("DEBUG: StorageService - Marking invalid design metadata for removal at index \(index)")
                invalidDesignsToRemove.append(index)
                continue
            }
            
            // Check if original image exists
            guard let originalImage = loadImage(from: originalImagePath) else {
                print("DEBUG: StorageService - Original image missing for design \(idString), marking for removal")
                invalidDesignsToRemove.append(index)
                continue
            }
            
            guard let uuid = UUID(uuidString: idString) else {
                print("DEBUG: StorageService - Invalid UUID format \(idString), marking for removal")
                invalidDesignsToRemove.append(index)
                continue
            }
            
            let createdAt = Date(timeIntervalSince1970: createdAtTimestamp)
            
            // Check status to determine design type
            let status = metadata["status"] as? String ?? "completed"
            
            if status == "processing" {
                // Design is still processing
                var design = SavedDesign(
                    id: uuid,
                    originalImage: originalImage,
                    styleName: styleName,
                    prompt: prompt
                )
                
                // Manually set creation date to match saved value
                design.createdAt = createdAt
                
                // If we have an in-memory version with a more up-to-date status, use it
                if let inMemoryDesign = inMemoryDesigns[uuid] {
                    // Only use in-memory if status is not processing
                    if case .processing = inMemoryDesign.status {
                        print("DEBUG: StorageService - Design \(idString) is still processing")
                    } else {
                        print("DEBUG: StorageService - Using in-memory version of design \(idString) with updated status")
                        design = inMemoryDesign
                    }
                }
                
                designs.append(design)
            } else if status == "failed" {
                print("DEBUG: StorageService - Loading failed design \(idString)")
                // Design failed
                let errorMessage = metadata["errorMessage"] as? String ?? "Unknown error"
                var design = SavedDesign(
                    id: uuid,
                    originalImage: originalImage,
                    styleName: styleName,
                    prompt: prompt
                )
                design.updateWithError(errorMessage)
                design.createdAt = createdAt
                designs.append(design)
            } else {
                print("DEBUG: StorageService - Loading completed design \(idString)")
                // Completed design
                guard let generatedImagePath = metadata["generatedImagePath"] as? String,
                      let generatedImage = loadImage(from: generatedImagePath) else {
                    print("DEBUG: StorageService - Could not load generated image for design \(idString), marking as failed")
                    // Instead of skipping, mark as failed
                    var design = SavedDesign(
                        id: uuid,
                        originalImage: originalImage,
                        styleName: styleName,
                        prompt: prompt
                    )
                    design.updateWithError("Generated image could not be loaded")
                    design.createdAt = createdAt
                    designs.append(design)
                    continue
                }
                
                var design = SavedDesign(
                    id: uuid,
                    originalImage: originalImage,
                    generatedImage: generatedImage,
                    styleName: styleName,
                    prompt: prompt
                )
                
                // Manually set creation date to match saved value
                design.createdAt = createdAt
                
                designs.append(design)
            }
        }
        
        // Clean up invalid designs
        if !invalidDesignsToRemove.isEmpty {
            print("DEBUG: StorageService - Cleaning up \(invalidDesignsToRemove.count) invalid designs")
            var updatedMetadata = designsMetadata
            // Remove from highest index to lowest to avoid changing indices
            for index in invalidDesignsToRemove.sorted(by: >) {
                updatedMetadata.remove(at: index)
            }
            userDefaults.set(updatedMetadata, forKey: designsKey)
        }
        
        return designs.sorted { $0.createdAt > $1.createdAt }
    }
    
    // Get a specific design by ID
    func getDesign(by id: UUID) -> SavedDesign? {
        // First check in-memory collection
        if let design = inMemoryDesigns[id] {
            return design
        }
        
        // Otherwise load from metadata
        let designsMetadata = getDesignsMetadata()
        
        for metadata in designsMetadata {
            guard
                let idString = metadata["id"] as? String,
                idString == id.uuidString,
                let originalImagePath = metadata["originalImagePath"] as? String,
                let styleName = metadata["styleName"] as? String,
                let prompt = metadata["prompt"] as? String,
                let originalImage = loadImage(from: originalImagePath)
            else {
                continue
            }
            
            let status = metadata["status"] as? String ?? "completed"
            
            if status == "processing" {
                // Design is still processing
                var design = SavedDesign(
                    id: UUID(uuidString: idString)!,
                    originalImage: originalImage,
                    styleName: styleName,
                    prompt: prompt
                )
                return design
            } else if status == "failed" {
                // Design failed
                let errorMessage = metadata["errorMessage"] as? String ?? "Unknown error"
                var design = SavedDesign(
                    id: UUID(uuidString: idString)!,
                    originalImage: originalImage,
                    styleName: styleName,
                    prompt: prompt
                )
                design.updateWithError(errorMessage)
                return design
            } else {
                // Completed design
                guard let generatedImagePath = metadata["generatedImagePath"] as? String,
                      let generatedImage = loadImage(from: generatedImagePath) else {
                    continue
                }
                
                let design = SavedDesign(
                    id: UUID(uuidString: idString)!,
                    originalImage: originalImage,
                    generatedImage: generatedImage,
                    styleName: styleName,
                    prompt: prompt
                )
                
                return design
            }
        }
        
        return nil
    }
    
    // Notify subscribers that designs have changed
    private func notifyDesignsChanged() {
        DispatchQueue.main.async {
            let designs = self.loadAllDesignsInternal()
            self.designsSubject.send(designs)
        }
    }
    
    private func getDesignsMetadata() -> [[String: Any]] {
        return userDefaults.array(forKey: designsKey) as? [[String: Any]] ?? []
    }
    
    // Verify that UserDefaults has the correct state
    private func verifyDesignsMetadata(shouldNotContainId id: UUID) {
        print("DEBUG: StorageService - VERIFICATION: Checking UserDefaults directly")
        
        // Force synchronize first
        userDefaults.synchronize()
        
        // Get raw data from UserDefaults
        guard let rawMetadata = userDefaults.array(forKey: designsKey) as? [[String: Any]] else {
            print("DEBUG: StorageService - VERIFICATION: No metadata found in UserDefaults")
            return
        }
        
        print("DEBUG: StorageService - VERIFICATION: Found \(rawMetadata.count) designs in UserDefaults")
        
        // Check if the design with the specified ID exists
        let matchingDesigns = rawMetadata.filter { metadata in
            guard let metadataId = metadata["id"] as? String else { return false }
            return metadataId == id.uuidString
        }
        
        if matchingDesigns.isEmpty {
            print("DEBUG: StorageService - VERIFICATION: SUCCESS - Design \(id) not found in UserDefaults")
        } else {
            print("DEBUG: StorageService - VERIFICATION: ERROR - Design \(id) still exists in UserDefaults!")
            
            // Print the matching design
            if let matchingDesign = matchingDesigns.first {
                print("DEBUG: StorageService - VERIFICATION: Matching design details:")
                for (key, value) in matchingDesign {
                    print("DEBUG: StorageService - VERIFICATION: \(key): \(value)")
                }
            }
        }
    }
    
    private func saveImage(_ image: UIImage, name: String) -> String {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent("\(name).jpg")
        
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: fileURL)
        }
        
        return fileURL.path
    }
    
    private func loadImage(from path: String) -> UIImage? {
        return UIImage(contentsOfFile: path)
    }
    
    // Save a completed design
    func saveDesign(_ design: SavedDesign) {
        print("DEBUG: StorageService - Saving completed design")
        
        // Keep the design's existing ID
        let designId = design.id
        
        // Save images to documents directory
        let originalImagePath = saveImage(design.originalImage, name: "original_\(designId.uuidString)")
        let generatedImagePath = saveImage(design.generatedImage!, name: "generated_\(designId.uuidString)")
        
        // Create metadata to save in UserDefaults
        let designMetadata: [String: Any] = [
            "id": designId.uuidString,
            "originalImagePath": originalImagePath,
            "generatedImagePath": generatedImagePath,
            "styleName": design.styleName,
            "prompt": design.prompt,
            "createdAt": design.createdAt.timeIntervalSince1970,
            "status": "completed"
        ]
        
        // Get existing designs
        var existingDesigns = getDesignsMetadata()
        existingDesigns.append(designMetadata)
        
        // Save updated list
        userDefaults.set(existingDesigns, forKey: designsKey)
        
        // Set flag to indicate a new design was saved
        hasNewDesign = true
        
        // Notify subscribers of the change
        notifyDesignsChanged()
        
        print("DEBUG: StorageService - Completed design saved with ID: \(designId)")
    }
    
    // Delete a design by ID
    func deleteDesign(with id: UUID) {
        print("DEBUG: StorageService - Starting deletion for design ID: \(id)")
        
        // Get existing designs
        var designsMetadata = getDesignsMetadata()
        print("DEBUG: StorageService - Current designs count: \(designsMetadata.count)")
        
        // Print all available designs for debugging
        print("DEBUG: StorageService - Available designs in UserDefaults:")
        for (index, metadata) in designsMetadata.enumerated() {
            if let metadataId = metadata["id"] as? String,
               let styleName = metadata["styleName"] as? String {
                print("DEBUG: StorageService - Design \(index): ID=\(metadataId), Style=\(styleName)")
            }
        }
        
        // Find the design to delete by ID (exact match)
        guard let index = designsMetadata.firstIndex(where: { ($0["id"] as? String) == id.uuidString }),
              let metadata = designsMetadata[safe: index] else {
            print("DEBUG: StorageService - Error: Could not find design with ID \(id) to delete")
            
            // Check if there's a case-insensitive match (debugging only)
            if let alternateIndex = designsMetadata.firstIndex(where: { 
                guard let metadataId = $0["id"] as? String else { return false }
                return metadataId.lowercased() == id.uuidString.lowercased() 
            }) {
                print("DEBUG: StorageService - Warning: Found case-insensitive match at index \(alternateIndex)")
                // We won't use this match - this is just for debugging
            }
            
            return
        }
        
        print("DEBUG: StorageService - Found design with ID \(id) at index \(index)")
        
        // Delete images from documents directory
        if let originalImagePath = metadata["originalImagePath"] as? String {
            print("DEBUG: StorageService - Deleting original image at: \(originalImagePath)")
            deleteFile(at: originalImagePath)
        }
        
        if let generatedImagePath = metadata["generatedImagePath"] as? String {
            print("DEBUG: StorageService - Deleting generated image at: \(generatedImagePath)")
            deleteFile(at: generatedImagePath)
        }
        
        // Remove from metadata
        designsMetadata.remove(at: index)
        print("DEBUG: StorageService - Removed design from metadata. New count: \(designsMetadata.count)")
        
        // Remove from in-memory cache
        let previousCount = inMemoryDesigns.count
        inMemoryDesigns.removeValue(forKey: id)
        if previousCount != inMemoryDesigns.count {
            print("DEBUG: StorageService - Successfully removed design from in-memory cache")
        } else {
            print("DEBUG: StorageService - Warning: Design not found in in-memory cache")
        }
        
        // Save updated list
        userDefaults.set(designsMetadata, forKey: designsKey)
        userDefaults.synchronize()
        print("DEBUG: StorageService - Saved updated metadata to UserDefaults")
        
        // Verify deletion
        let afterDesigns = getDesignsMetadata()
        let stillExists = afterDesigns.contains { ($0["id"] as? String) == id.uuidString }
        if stillExists {
            print("DEBUG: StorageService - ERROR: Design still exists after deletion!")
        } else {
            print("DEBUG: StorageService - SUCCESS: Design successfully deleted")
        }
        
        // Update publisher with new designs list
        let updatedDesigns = loadAllDesignsInternal()
        print("DEBUG: StorageService - Loaded \(updatedDesigns.count) designs after deletion")
        
        DispatchQueue.main.async {
            // Update the publisher
            self.designsSubject.send(updatedDesigns)
            
            // Post notifications for any listeners
            NotificationCenter.default.post(name: Notification.Name("DesignsUpdated"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("DesignDeleted"), object: nil)
            
            print("DEBUG: StorageService - Notifications posted")
        }
        
        print("DEBUG: StorageService - Deletion process completed for ID: \(id)")
    }
    
    // Delete designs helper method
    private func deleteFile(at path: String) {
        do {
            try fileManager.removeItem(atPath: path)
            print("DEBUG: StorageService - Successfully deleted file: \(path)")
        } catch {
            print("DEBUG: StorageService - Error deleting file at \(path): \(error.localizedDescription)")
        }
    }
}

// Add extension for safe array access
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}