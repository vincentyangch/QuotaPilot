import Foundation

public struct QuotaAccount: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let provider: QuotaProvider
    public let label: String
    public let priority: Int
    public let isCurrent: Bool
    public let profileRootPath: String?
    public let sourceDescription: String?
    public let email: String?
    public let plan: String?
    public let organizationLabel: String?
    public let workspaceLabel: String?
    public let capabilities: QuotaAccountCapabilities
    public let lastSuccessfulRefreshAt: Date?
    public let windows: [UsageWindow]

    public init(
        id: UUID,
        provider: QuotaProvider,
        label: String,
        priority: Int,
        isCurrent: Bool,
        profileRootPath: String? = nil,
        sourceDescription: String? = nil,
        email: String? = nil,
        plan: String? = nil,
        organizationLabel: String? = nil,
        workspaceLabel: String? = nil,
        capabilities: QuotaAccountCapabilities = .localProfile,
        lastSuccessfulRefreshAt: Date? = nil,
        windows: [UsageWindow]
    ) {
        self.id = id
        self.provider = provider
        self.label = label
        self.priority = priority
        self.isCurrent = isCurrent
        self.profileRootPath = profileRootPath
        self.sourceDescription = sourceDescription
        self.email = email
        self.plan = plan
        self.organizationLabel = organizationLabel
        self.workspaceLabel = workspaceLabel
        self.capabilities = capabilities
        self.lastSuccessfulRefreshAt = lastSuccessfulRefreshAt
        self.windows = windows
    }

    public var primaryWindow: UsageWindow? {
        self.windows.first
    }

    public var primaryRemainingPercent: Int {
        self.primaryWindow?.remainingPercent ?? 0
    }

    public func primaryResetHours(from now: Date = .now) -> Int {
        self.primaryWindow?.hoursUntilReset(from: now) ?? Int.max
    }

    public var identitySummary: String? {
        let parts = [
            self.email,
            self.plan?.uppercased(),
            self.workspaceLabel ?? self.organizationLabel,
        ].compactMap { value in
            value?.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " • ")
    }

    public var capabilityLabels: [String] {
        var labels: [String] = []
        if self.capabilities.canReadUsage {
            labels.append("Usage")
        }
        if self.capabilities.canRecommend {
            labels.append("Recommend")
        }
        if self.capabilities.canAutoActivateLocalProfile {
            labels.append("Auto-Switch")
        }
        if self.capabilities.canGuideDesktopHandoff {
            labels.append("Handoff")
        }
        return labels
    }
}

extension QuotaAccount {
    enum CodingKeys: String, CodingKey {
        case id
        case provider
        case label
        case priority
        case isCurrent
        case profileRootPath
        case sourceDescription
        case email
        case plan
        case organizationLabel
        case workspaceLabel
        case capabilities
        case lastSuccessfulRefreshAt
        case windows
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.provider = try container.decode(QuotaProvider.self, forKey: .provider)
        self.label = try container.decode(String.self, forKey: .label)
        self.priority = try container.decode(Int.self, forKey: .priority)
        self.isCurrent = try container.decode(Bool.self, forKey: .isCurrent)
        self.profileRootPath = try container.decodeIfPresent(String.self, forKey: .profileRootPath)
        self.sourceDescription = try container.decodeIfPresent(String.self, forKey: .sourceDescription)
        self.email = try container.decodeIfPresent(String.self, forKey: .email)
        self.plan = try container.decodeIfPresent(String.self, forKey: .plan)
        self.organizationLabel = try container.decodeIfPresent(String.self, forKey: .organizationLabel)
        self.workspaceLabel = try container.decodeIfPresent(String.self, forKey: .workspaceLabel)
        self.capabilities = try container.decodeIfPresent(QuotaAccountCapabilities.self, forKey: .capabilities) ?? .localProfile
        self.lastSuccessfulRefreshAt = try container.decodeIfPresent(Date.self, forKey: .lastSuccessfulRefreshAt)
        self.windows = try container.decode([UsageWindow].self, forKey: .windows)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.provider, forKey: .provider)
        try container.encode(self.label, forKey: .label)
        try container.encode(self.priority, forKey: .priority)
        try container.encode(self.isCurrent, forKey: .isCurrent)
        try container.encodeIfPresent(self.profileRootPath, forKey: .profileRootPath)
        try container.encodeIfPresent(self.sourceDescription, forKey: .sourceDescription)
        try container.encodeIfPresent(self.email, forKey: .email)
        try container.encodeIfPresent(self.plan, forKey: .plan)
        try container.encodeIfPresent(self.organizationLabel, forKey: .organizationLabel)
        try container.encodeIfPresent(self.workspaceLabel, forKey: .workspaceLabel)
        try container.encode(self.capabilities, forKey: .capabilities)
        try container.encodeIfPresent(self.lastSuccessfulRefreshAt, forKey: .lastSuccessfulRefreshAt)
        try container.encode(self.windows, forKey: .windows)
    }
}

public extension QuotaAccount {
    static func codex(
        label: String,
        remainingPercent: Int,
        resetHours: Int,
        priority: Int,
        isCurrent: Bool,
        profileRootPath: String? = nil,
        sourceDescription: String? = nil,
        email: String? = nil,
        plan: String? = nil,
        organizationLabel: String? = nil,
        workspaceLabel: String? = nil,
        capabilities: QuotaAccountCapabilities = .localProfile,
        lastSuccessfulRefreshAt: Date? = nil
    ) -> Self {
        QuotaAccount(
            id: UUID(),
            provider: .codex,
            label: label,
            priority: priority,
            isCurrent: isCurrent,
            profileRootPath: profileRootPath,
            sourceDescription: sourceDescription,
            email: email,
            plan: plan,
            organizationLabel: organizationLabel,
            workspaceLabel: workspaceLabel,
            capabilities: capabilities,
            lastSuccessfulRefreshAt: lastSuccessfulRefreshAt,
            windows: [
                UsageWindow(
                    id: "session",
                    title: "Session",
                    remainingPercent: remainingPercent,
                    resetsAt: .now.addingTimeInterval(Double(resetHours) * 3600)
                ),
                UsageWindow(
                    id: "weekly",
                    title: "Weekly",
                    remainingPercent: max(remainingPercent - 10, 0),
                    resetsAt: .now.addingTimeInterval(Double(resetHours + 48) * 3600)
                ),
            ]
        )
    }

    static func claude(
        label: String,
        remainingPercent: Int,
        resetHours: Int,
        priority: Int,
        isCurrent: Bool,
        profileRootPath: String? = nil,
        sourceDescription: String? = nil,
        email: String? = nil,
        plan: String? = nil,
        organizationLabel: String? = nil,
        workspaceLabel: String? = nil,
        capabilities: QuotaAccountCapabilities = .localProfile,
        lastSuccessfulRefreshAt: Date? = nil
    ) -> Self {
        QuotaAccount(
            id: UUID(),
            provider: .claude,
            label: label,
            priority: priority,
            isCurrent: isCurrent,
            profileRootPath: profileRootPath,
            sourceDescription: sourceDescription,
            email: email,
            plan: plan,
            organizationLabel: organizationLabel,
            workspaceLabel: workspaceLabel,
            capabilities: capabilities,
            lastSuccessfulRefreshAt: lastSuccessfulRefreshAt,
            windows: [
                UsageWindow(
                    id: "weekly",
                    title: "Weekly",
                    remainingPercent: remainingPercent,
                    resetsAt: .now.addingTimeInterval(Double(resetHours) * 3600)
                ),
            ]
        )
    }
}
