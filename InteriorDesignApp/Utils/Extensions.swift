import SwiftUI
import UIKit

// MARK: - UIImage Extensions
extension UIImage {
    // Convenience function to create a composite image for sharing
    func compositeBesideImage(_ image: UIImage, withPadding padding: CGFloat = 10) -> UIImage {
        let totalWidth = self.size.width + image.size.width + padding
        let maxHeight = max(self.size.height, image.size.height)
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: totalWidth, height: maxHeight))
        return renderer.image { ctx in
            // Draw first image
            self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
            
            // Draw second image
            image.draw(in: CGRect(x: self.size.width + padding, y: 0, width: image.size.width, height: image.size.height))
        }
    }
}

// MARK: - View Extensions
extension View {
    // Apply rounded corners to specific corners
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
    
    // Add shadow to views
    func customShadow(radius: CGFloat = 5, opacity: CGFloat = 0.2) -> some View {
        self.shadow(color: Color.black.opacity(opacity), radius: radius, x: 0, y: 2)
    }
}

// MARK: - Custom Shapes
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
