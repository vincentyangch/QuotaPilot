import Foundation
#if canImport(AppKit)
import AppKit
#endif

public enum ProviderBrandAsset {
    private final class BundleToken {}

    private static let bundle: Bundle = Bundle(for: BundleToken.self)

    public static func iconURL(for provider: QuotaProvider) -> URL? {
        self.bundle.url(forResource: "ProviderIcon-\(provider.rawValue)", withExtension: "svg")
    }

    #if canImport(AppKit)
    public static func iconImage(
        for provider: QuotaProvider,
        size: CGFloat = 16
    ) -> NSImage? {
        guard let url = self.iconURL(for: provider),
              let image = NSImage(contentsOf: url)
        else {
            return nil
        }

        image.size = NSSize(width: size, height: size)
        image.isTemplate = true
        return image
    }
    #endif
}
