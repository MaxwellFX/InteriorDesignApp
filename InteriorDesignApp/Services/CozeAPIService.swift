import Foundation
import UIKit
import CommonCrypto

class CozeAPIService {
    static let shared = CozeAPIService()
    
    // Coze API credentials
    private let token = "pat_64hTLhSc9tsgwvNiBMTgDkbUPCFeWXKl4RfvhCs0DSLwF4oHm4Q4dNJyr9KPdAB7"
    private let workflowId = "7443772511077089295"
    private let cozeBaseURL = "https://api.coze.cn/v1/workflow/run"
    
    // Cloudinary credentials
    private let cloudName = "dswo78c0s"
    private let cloudinaryAPIKey = "571299258666685" 
    private let cloudinaryAPISecret = "yQmY58jma1ode8NEWNiK4-FKApU"
    private let cloudinaryUploadURL = "https://api.cloudinary.com/v1_1/dswo78c0s/image/upload"
    private let cloudinaryFolder = "coze_interior_designs"
    
    // Enable debug mode for detailed logs
    private let debugMode = true
    
    private init() {}
    
    // Debug logger function
    private func logDebug(_ message: String) {
        if debugMode {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("📱 DEBUG [\(timestamp)]: \(message)")
        }
    }
    
    func generateDesign(image: UIImage, prompt: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        logDebug("Starting design generation process...")
        logDebug("Prompt: \(prompt)")
        
        // Step 1: Upload the image to Cloudinary
        logDebug("Step 1: Uploading image to Cloudinary...")
        uploadImageToCloudinary(image) { result in
            switch result {
            case .success(let cloudinaryURL):
                self.logDebug("✅ Image uploaded to Cloudinary successfully")
                self.logDebug("Cloudinary URL: \(cloudinaryURL)")
                
                // Step 2: Call Coze API with the Cloudinary URL
                self.logDebug("Step 2: Calling Coze API with Cloudinary URL...")
                self.callCozeAPI(imageURL: cloudinaryURL, prompt: prompt) { result in
                    switch result {
                    case .success(let image):
                        self.logDebug("✅ Design generated successfully!")
                        completion(.success(image))
                    case .failure(let error):
                        // Just pass the failure back to the caller
                        self.logDebug("❌ API Error: \(error.localizedDescription)")
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                self.logDebug("❌ Cloudinary upload failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    private func uploadImageToCloudinary(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        logDebug("Preparing image for Cloudinary upload...")
        
        // Resize image to reasonable size if needed
        let maxSize: CGFloat = 1024  // 1024px max dimension
        var resizedImage = image
        
        if image.size.width > maxSize || image.size.height > maxSize {
            let scale = maxSize / max(image.size.width, image.size.height)
            let newWidth = image.size.width * scale
            let newHeight = image.size.height * scale
            let newSize = CGSize(width: newWidth, height: newHeight)
            
            logDebug("Resizing image from \(image.size.width)x\(image.size.height) to \(newWidth)x\(newHeight)")
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            if let resized = UIGraphicsGetImageFromCurrentImageContext() {
                resizedImage = resized
            }
            UIGraphicsEndImageContext()
        }
        
        // Convert to JPEG data with reduced quality
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.7) else {
            logDebug("❌ Failed to convert image to JPEG data")
            completion(.failure(CozeAPIError.imageProcessingFailed))
            return
        }
        
        logDebug("Image size after compression: \(ByteCountFormatter.string(fromByteCount: Int64(imageData.count), countStyle: .file))")
        
        // Create a timestamp for the signature
        let timestamp = Int(Date().timeIntervalSince1970)
        
        // Create form data for upload
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: cloudinaryUploadURL)!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        logDebug("Creating multipart form data for Cloudinary...")
        var body = Data()
        
        // Add API key
        body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"api_key\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(cloudinaryAPIKey)".data(using: .utf8)!)
        
        // Add timestamp
        body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"timestamp\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(timestamp)".data(using: .utf8)!)
        
        // Add folder
        body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"folder\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(cloudinaryFolder)".data(using: .utf8)!)
        
        // Generate signature (timestamp + folder + secret)
        let signatureString = "folder=\(cloudinaryFolder)&timestamp=\(timestamp)\(cloudinaryAPISecret)"
        let signature = signatureString.sha1()
        
        // Add signature
        body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"signature\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(signature)".data(using: .utf8)!)
        
        // Add file
        body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        
        // End boundary
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Make upload request
        logDebug("Sending upload request to Cloudinary...")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                self.logDebug("❌ Cloudinary network error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                self.logDebug("Cloudinary response status code: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                self.logDebug("❌ No data received from Cloudinary")
                DispatchQueue.main.async {
                    completion(.failure(CozeAPIError.noDataReceived))
                }
                return
            }
            
            // Debug response
            if let responseString = String(data: data, encoding: .utf8) {
                self.logDebug("Cloudinary response: \(responseString)")
            }
            
            do {
                // Parse response
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let secureUrl = json["secure_url"] as? String {
                    self.logDebug("✅ Successfully parsed Cloudinary response")
                    DispatchQueue.main.async {
                        completion(.success(secureUrl))
                    }
                } else {
                    self.logDebug("❌ Failed to extract secure_url from Cloudinary response")
                    DispatchQueue.main.async {
                        completion(.failure(CozeAPIError.invalidResponse))
                    }
                }
            } catch {
                self.logDebug("❌ Error parsing Cloudinary JSON: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
    
    private func callCozeAPI(imageURL: String, prompt: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        // Setup request
        guard let url = URL(string: cozeBaseURL) else {
            logDebug("❌ Invalid Coze API URL")
            completion(.failure(CozeAPIError.invalidURL))
            return
        }
        
        logDebug("Preparing Coze API request...")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create request body - UPDATED FORMAT based on test_coze_api.js
        let parameters: [String: Any] = [
            "parameters": [
                "Image_Input": imageURL,
                "Prompt": prompt
            ],
            "workflow_id": workflowId
        ]
        
        logDebug("Request parameters: \(parameters)")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            logDebug("❌ Failed to serialize JSON for Coze API request: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }
        
        // Make API call with loading indicator
        DispatchQueue.main.async {
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
        }
        
        logDebug("Sending request to Coze API...")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
            }
            
            if let error = error {
                let nsError = error as NSError
                
                self.logDebug("❌ Coze API network error: \(error.localizedDescription)")
                self.logDebug("Error domain: \(nsError.domain), code: \(nsError.code)")
                
                // Handle connectivity errors
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorNotConnectedToInternet {
                    self.logDebug("❌ Internet connection appears to be offline")
                    DispatchQueue.main.async {
                        completion(.failure(CozeAPIError.connectivity(message: "Internet connection appears to be offline")))
                    }
                } else {
                DispatchQueue.main.async {
                    completion(.failure(error))
                    }
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                self.logDebug("Coze API response status code: \(httpResponse.statusCode)")
                self.logDebug("Response headers: \(httpResponse.allHeaderFields)")
            }
            
            guard let data = data else {
                self.logDebug("❌ No data received from Coze API")
                DispatchQueue.main.async {
                    completion(.failure(CozeAPIError.noDataReceived))
                }
                return
            }
            
            // Debug response
            if let responseString = String(data: data, encoding: .utf8) {
                self.logDebug("Coze API raw response: \(responseString)")
            }
            
            // Process response to extract the generated image URL
            // UPDATED PARSING LOGIC based on test_parser.js
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    self.logDebug("Successfully parsed outer JSON response")
                    
                    // Check for Coze API error first
                    if let errorCode = json["code"] as? Int, errorCode != 0 {
                        let errorMsg = json["msg"] as? String ?? "Unknown error"
                        self.logDebug("❌ Coze API returned error code: \(errorCode)")
                        self.logDebug("Error message: \(errorMsg)")
                        
                        // Rate limiting check
                        if errorCode == 4024 {
                            self.logDebug("⚠️ API rate limited")
                            DispatchQueue.main.async {
                                completion(.failure(CozeAPIError.rateLimited(message: "API rate limited: \(errorMsg)")))
                            }
                        } else {
                            DispatchQueue.main.async {
                                completion(.failure(CozeAPIError.api(code: errorCode, message: errorMsg)))
                            }
                        }
                        return
                    }
                    
                    // Success path - parse the data field which contains a nested JSON string
                    if let dataString = json["data"] as? String {
                        self.logDebug("Found data field, attempting to parse nested JSON")
                        
                        // Parse the nested JSON string
                        if let dataData = dataString.data(using: .utf8),
                           let nestedJson = try JSONSerialization.jsonObject(with: dataData) as? [String: Any] {
                            
                            self.logDebug("Successfully parsed nested JSON")
                            self.logDebug("Nested JSON content: \(nestedJson)")
                            
                            // Check for TLS handshake timeout but still try to get the Output
                            if let msg = nestedJson["msg"] as? String {
                                self.logDebug("Message from nested JSON: \(msg)")
                                
                                if msg.contains("TLS handshake timeout") {
                                    self.logDebug("⚠️ TLS handshake timeout detected with Cloudinary URL")
                                    self.logDebug("Attempting to proceed with Output URL if available")
                                }
                            }
                            
                            // Extract the Output URL
                            if let outputURL = nestedJson["Output"] as? String {
                                self.logDebug("✅ Found Output URL: \(outputURL)")
                                
                                // Check if the URL is empty or invalid
                                if outputURL.isEmpty {
                                    self.logDebug("❌ Output URL is empty")
                                    DispatchQueue.main.async {
                                        completion(.failure(CozeAPIError.api(code: -1, message: "API returned empty image URL")))
                                    }
                                    return
                                }
                                
                                // Make sure we can create a valid URL
                                guard let url = URL(string: outputURL) else {
                                    self.logDebug("❌ Could not create URL from Output string: \(outputURL)")
                                    DispatchQueue.main.async {
                                        completion(.failure(CozeAPIError.invalidURL))
                                    }
                                    return
                                }
                                
                                // Download the generated image
                                self.logDebug("Downloading generated image...")
                                self.downloadImage(from: url) { result in
                                    DispatchQueue.main.async {
                                        completion(result)
                                    }
                                }
                                return
                            } else {
                                self.logDebug("❌ No Output URL found in nested JSON")
                            }
                        } else {
                            self.logDebug("❌ Failed to parse nested JSON from data string")
                        }
                    } else {
                        self.logDebug("❌ No data field found in response JSON")
                    }
                    
                    // If we get here, we couldn't find the expected output
                    self.logDebug("❌ Could not find expected Output URL in response")
                    DispatchQueue.main.async {
                        completion(.failure(CozeAPIError.invalidResponse))
                    }
                } else {
                    self.logDebug("❌ Failed to parse outer JSON response")
                    DispatchQueue.main.async {
                        completion(.failure(CozeAPIError.invalidResponse))
                    }
                }
            } catch {
                self.logDebug("❌ Exception while parsing response: \(error.localizedDescription)")
            DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
    
    private func downloadImage(from url: URL, completion: @escaping (Result<UIImage, Error>) -> Void) {
        logDebug("Downloading image from URL: \(url.absoluteString)")
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                self.logDebug("❌ Image download failed: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                self.logDebug("Image download response status: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                self.logDebug("❌ No image data received")
                completion(.failure(CozeAPIError.noDataReceived))
                return
            }
            
            self.logDebug("Image data size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
            
            guard let image = UIImage(data: data) else {
                self.logDebug("❌ Failed to create UIImage from downloaded data")
                completion(.failure(CozeAPIError.imageProcessingFailed))
                return
            }
            
            self.logDebug("✅ Successfully downloaded and created image: \(image.size.width)x\(image.size.height)")
            completion(.success(image))
        }
        
        task.resume()
    }
}

enum CozeAPIError: Error, LocalizedError {
    case networkError
    case invalidResponse
    case imageProcessingFailed
    case noDataReceived
    case invalidURL
    case connectivity(message: String)
    case authentication(message: String)
    case api(code: Int, message: String)
    case rateLimited(message: String)
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network error occurred"
        case .invalidResponse:
            return "Invalid response from server"
        case .imageProcessingFailed:
            return "Failed to process image"
        case .noDataReceived:
            return "No data received from server"
        case .invalidURL:
            return "Invalid URL"
        case .connectivity(let message):
            return message
        case .authentication(let message):
            return message
        case .api(let code, let message):
            return "API Error \(code): \(message)"
        case .rateLimited(let message):
            return message
        }
    }
}

// Extension for SHA1 hashing (needed for Cloudinary signature)
extension String {
    func sha1() -> String {
        let data = Data(self.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest)
        }
        let hexBytes = digest.map { String(format: "%02hhx", $0) }
        return hexBytes.joined()
    }
} 

