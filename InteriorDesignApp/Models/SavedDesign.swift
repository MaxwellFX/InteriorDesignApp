import Foundation
import UIKit

// Processing status for design generation
enum ProcessingStatus: Hashable {
    case processing
    case completed
    case failed(error: String)
    
    // Implement Hashable for ProcessingStatus with associated value
    func hash(into hasher: inout Hasher) {
        switch self {
        case .processing:
            hasher.combine(0)
        case .completed:
            hasher.combine(1)
        case .failed(let error):
            hasher.combine(2)
            hasher.combine(error)
        }
    }
    
    // Implement Equatable for ProcessingStatus with associated value
    static func == (lhs: ProcessingStatus, rhs: ProcessingStatus) -> Bool {
        switch (lhs, rhs) {
        case (.processing, .processing):
            return true
        case (.completed, .completed):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}

struct SavedDesign: Identifiable, Hashable {
    let id: UUID
    let originalImage: UIImage
    var generatedImage: UIImage?
    let styleName: String
    let prompt: String
    var createdAt: Date
    var status: ProcessingStatus
    
    // For creating new designs that are processing
    init(id: UUID, originalImage: UIImage, styleName: String, prompt: String) {
        self.id = id
        self.originalImage = originalImage
        self.generatedImage = nil
        self.styleName = styleName
        self.prompt = prompt
        self.createdAt = Date()
        self.status = .processing
    }
    
    // For completed designs
    init(id: UUID, originalImage: UIImage, generatedImage: UIImage, styleName: String, prompt: String) {
        self.id = id
        self.originalImage = originalImage
        self.generatedImage = generatedImage
        self.styleName = styleName
        self.prompt = prompt
        self.createdAt = Date()
        self.status = .completed
    }
    
    // For updating status
    mutating func updateWithGeneratedImage(_ image: UIImage) {
        self.generatedImage = image
        self.status = .completed
    }
    
    mutating func updateWithError(_ errorMessage: String) {
        self.status = .failed(error: errorMessage)
    }
    
    // MARK: - Hashable Implementation
    
    // Custom implementation of Hashable since UIImage is not Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(styleName)
        hasher.combine(prompt)
        hasher.combine(createdAt)
        hasher.combine(status)
    }
    
    // Custom implementation of Equatable
    static func == (lhs: SavedDesign, rhs: SavedDesign) -> Bool {
        return lhs.id == rhs.id
    }
} 