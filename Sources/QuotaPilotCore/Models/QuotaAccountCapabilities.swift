import Foundation

public struct QuotaAccountCapabilities: Codable, Equatable, Sendable {
    public let canReadUsage: Bool
    public let canRecommend: Bool
    public let canAutoActivateLocalProfile: Bool
    public let canGuideDesktopHandoff: Bool

    public init(
        canReadUsage: Bool,
        canRecommend: Bool,
        canAutoActivateLocalProfile: Bool,
        canGuideDesktopHandoff: Bool
    ) {
        self.canReadUsage = canReadUsage
        self.canRecommend = canRecommend
        self.canAutoActivateLocalProfile = canAutoActivateLocalProfile
        self.canGuideDesktopHandoff = canGuideDesktopHandoff
    }

    public static let localProfile = QuotaAccountCapabilities(
        canReadUsage: true,
        canRecommend: true,
        canAutoActivateLocalProfile: true,
        canGuideDesktopHandoff: true
    )
}
