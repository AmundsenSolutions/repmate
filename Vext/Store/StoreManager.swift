import Foundation
import StoreKit
import SwiftUI
import Combine

@MainActor
class StoreManager: ObservableObject {
    @Published var isPro: Bool = false
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var errorMessage: String? = nil
    
    private let proProductID = "vext_pro_lifetime"
    private var updateListenerTask: Task<Void, Error>? = nil
    
    init() {
        updateListenerTask = listenForTransactions()
        
        Task {
            await requestProducts()
            await updateCustomerProductStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    func requestProducts() async {
        do {
            let storeProducts = try await Product.products(for: [proProductID])
            self.products = storeProducts
        } catch {
            print("Failed product request from App Store server: \(error)")
            self.errorMessage = "Failed to load store products."
        }
    }
    
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updateCustomerProductStatus()
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }
    
    func restorePurchases() {
        Task {
            do {
                try await AppStore.sync()
                await updateCustomerProductStatus()
            } catch {
                print("Failed to sync purchases: \(error)")
                self.errorMessage = "Failed to restore purchases."
            }
        }
    }
    
    @MainActor
    private func updateCustomerProductStatus() async {
        var purchasedIDs: Set<String> = []
        
        // Iterate through all of the user's purchased products.
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // Determine if the product is active.
                if transaction.revocationDate == nil {
                    purchasedIDs.insert(transaction.productID)
                }
            } catch {
                print("Transaction failed verification: \(error)")
            }
        }
        
        self.purchasedProductIDs = purchasedIDs
        
        // Update user state if they have the Pro product.
        if purchasedIDs.contains(proProductID) {
            self.isPro = true
        } else {
            self.isPro = false
        }
    }
    
    // Listen for transactions that might happen outside the app (e.g. Ask to Buy)
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }
                do {
                    let transaction = try self.checkVerified(result)
                    await transaction.finish()
                    await self.updateCustomerProductStatus()
                } catch {
                    print("Transaction failed verification: \(error)")
                }
            }
        }
    }
    
    // Check if the transaction passes StoreKit's cryptographic signature check
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
