import Foundation

/// Retrieves product nutrition via Open Food Facts API.
struct OpenFoodFactsService {
    
    struct ProductResult {
        let name: String
        let proteinPer100g: Double
        let servingSize: String?       // e.g. "30g"
        let proteinPerServing: Double?  // protein for one serving
    }
    
    /// Scans database for product by EAN/UPC barcode.
    static func fetchProduct(barcode: String) async -> ProductResult? {
        // SIMULATION MOCK: Return immediate result for magic barcode
        if barcode == "9999999999999" {
            // Simulate network delay slightly
            try? await Task.sleep(nanoseconds: 500_000_000)
            return ProductResult(
                name: "Simulated Whey Protein",
                proteinPer100g: 82.0,
                servingSize: "30g",
                proteinPerServing: 24.6
            )
        }

        let encodedBarcode = barcode.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? barcode
        let urlString = "https://world.openfoodfacts.org/api/v2/product/\(encodedBarcode).json?fields=product_name,nutriments,serving_size,serving_quantity"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? Int, status == 1,
                  let product = json["product"] as? [String: Any] else { return nil }
            
            let name = product["product_name"] as? String ?? "Unknown Product"
            
            guard let nutriments = product["nutriments"] as? [String: Any] else { return nil }
            
            // Protein per 100g
            let proteinPer100g: Double
            if let p = nutriments["proteins_100g"] as? Double {
                proteinPer100g = p
            } else if let p = nutriments["proteins_100g"] as? Int {
                proteinPer100g = Double(p)
            } else {
                return nil // No protein data, not useful
            }
            
            // Serving info (optional)
            let servingSize = product["serving_size"] as? String
            let proteinPerServing: Double?
            if let ps = nutriments["proteins_serving"] as? Double {
                proteinPerServing = ps
            } else if let ps = nutriments["proteins_serving"] as? Int {
                proteinPerServing = Double(ps)
            } else {
                proteinPerServing = nil
            }
            
            return ProductResult(
                name: name,
                proteinPer100g: proteinPer100g,
                servingSize: servingSize,
                proteinPerServing: proteinPerServing
            )
        } catch {
            return nil
        }
    }
}
