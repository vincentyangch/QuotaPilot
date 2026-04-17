import Foundation

public struct GlobalRules: Codable, Equatable, Sendable {
    public let switchThresholdPercent: Int
    public let minimumScoreAdvantage: Int
    public let remainingWeight: Int
    public let resetWeight: Int
    public let priorityWeight: Int
    public let providerWeights: [QuotaProvider: Int]

    public init(
        switchThresholdPercent: Int,
        minimumScoreAdvantage: Int,
        remainingWeight: Int,
        resetWeight: Int,
        priorityWeight: Int,
        providerWeights: [QuotaProvider: Int]
    ) {
        self.switchThresholdPercent = switchThresholdPercent
        self.minimumScoreAdvantage = minimumScoreAdvantage
        self.remainingWeight = remainingWeight
        self.resetWeight = resetWeight
        self.priorityWeight = priorityWeight
        self.providerWeights = providerWeights
    }

    public static let `default` = GlobalRules(
        switchThresholdPercent: 20,
        minimumScoreAdvantage: 15,
        remainingWeight: 1,
        resetWeight: 3,
        priorityWeight: 1,
        providerWeights: [.codex: 50, .claude: 50]
    )
}
