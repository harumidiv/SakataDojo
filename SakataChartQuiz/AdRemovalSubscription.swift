import Combine
import Foundation
import StoreKit

@MainActor
final class AdRemovalSubscription: ObservableObject {
    static let productID = "sakataQuiz.SakataChartQuiz.adfree.monthly"

    enum Access {
        case checking, free, subscribed
    }

    @Published private(set) var access: Access = .checking

    private var transactionUpdates: Task<Void, Never>?
    private var statusUpdates: Task<Void, Never>?
    private var expirationCheck: Task<Void, Never>?
    private var refreshVersion = 0

    init() {
        transactionUpdates = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.finish(update)
            }
        }
        statusUpdates = Task { [weak self] in
            for await status in Product.SubscriptionInfo.Status.updates {
                guard case .verified(let transaction) = status.transaction,
                      transaction.productID == Self.productID else { continue }
                await self?.refresh()
            }
        }
    }

    deinit {
        transactionUpdates?.cancel()
        statusUpdates?.cancel()
        expirationCheck?.cancel()
    }

    func refresh() async {
        refreshVersion += 1
        let version = refreshVersion
        var nextCheck: Date?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == Self.productID,
                  transaction.productType == .autoRenewable else { continue }

            // currentEntitlements includes subscriptions in the App Store's billing grace period.
            let now = Date.now
            var checkDate = transaction.expirationDate ?? now
            if checkDate <= now,
               let status = await transaction.subscriptionStatus,
               status.state == .inGracePeriod,
               case .verified(let renewal) = status.renewalInfo,
               let graceEnd = renewal.gracePeriodExpirationDate {
                checkDate = graceEnd
            }
            // Recheck if StoreKit is still resolving the status at the renewal boundary.
            if checkDate <= now {
                checkDate = now.addingTimeInterval(30)
            }
            nextCheck = min(nextCheck ?? checkDate, checkDate)
        }

        guard version == refreshVersion else { return }
        let updatedAccess: Access = nextCheck == nil ? .free : .subscribed
        if access != updatedAccess {
            access = updatedAccess
        }

        expirationCheck?.cancel()
        expirationCheck = nil
        if let nextCheck {
            let delay = max(1, nextCheck.timeIntervalSinceNow)
            expirationCheck = Task { [weak self] in
                do {
                    try await Task.sleep(for: .seconds(delay))
                    await self?.refresh()
                } catch {
                    return
                }
            }
        }
    }

    func finish(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result,
              transaction.productID == Self.productID else { return }
        await refresh()
        await transaction.finish()
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await refresh()
    }
}
