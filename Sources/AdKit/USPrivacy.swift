import Foundation

/// The user's US state privacy choice ("Do Not Sell or Share My Personal Information"), read from the
/// IAB strings a consent platform such as UMP stores in `UserDefaults`.
///
/// Google can't forward this choice to every mediated network, so each network's SDK has to be told.
public struct USPrivacy: Equatable, Sendable {
    /// The user opted out of the sale or sharing of their data, or of targeted advertising.
    public var doNotSell: Bool

    public init(doNotSell: Bool) {
        self.doNotSell = doNotSell
    }

    /// `nil` when no US privacy string is stored, for example outside regulated US states.
    public static func current(defaults: UserDefaults = .standard) -> USPrivacy? {
        if let usnat = usnatSection(defaults: defaults), let optOut = optedOut(usnat: usnat) {
            return USPrivacy(doNotSell: optOut)
        }
        if let usp = defaults.string(forKey: "IABUSPrivacy_String"), let optOut = optedOut(usPrivacy: usp) {
            return USPrivacy(doNotSell: optOut)
        }
        return nil
    }

    /// The IAB CCPA string (`1YYN` or `1YNN`), for SDKs that still read `IABUSPrivacy_String`.
    public var usPrivacyString: String {
        doNotSell ? "1YYN" : "1YNN"
    }

    static let usnatSectionID = 7

    static func usnatSection(defaults: UserDefaults) -> String? {
        if let section = defaults.string(forKey: "IABGPP_\(usnatSectionID)_String"), !section.isEmpty {
            return section
        }
        // Fall back to the full string: a header, then one section per ID in `IABGPP_GppSID`, joined by "~".
        guard let gpp = defaults.string(forKey: "IABGPP_HDR_GppString"),
              let sids = defaults.string(forKey: "IABGPP_GppSID") else { return nil }
        let ids = sids.split(separator: "_").compactMap { Int($0) }
        let sections = gpp.split(separator: "~").dropFirst().map(String.init)
        guard let index = ids.firstIndex(of: usnatSectionID), index < sections.count else { return nil }
        return sections[index]
    }

    /// Reads the core segment of the IAB GPP US National section. Each opt-out field is 2 bits:
    /// 0 not applicable, 1 opted out, 2 did not opt out.
    static func optedOut(usnat: String) -> Bool? {
        let core = usnat.split(separator: ".").first.map(String.init) ?? usnat
        guard let bits = bits(base64URL: core), bits.count >= 24 else { return nil }
        // Version (6) and six notice fields (2 each) come first.
        let saleOptOut = field(bits, at: 18)
        let sharingOptOut = field(bits, at: 20)
        let targetedAdvertisingOptOut = field(bits, at: 22)
        return [saleOptOut, sharingOptOut, targetedAdvertisingOptOut].contains(1)
    }

    static func optedOut(usPrivacy: String) -> Bool? {
        let chars = Array(usPrivacy)
        guard chars.count == 4, chars[0] == "1" else { return nil }
        switch chars[2] {
        case "Y": return true
        case "N": return false
        default: return nil
        }
    }

    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")

    private static func bits(base64URL: String) -> [Bool]? {
        var result: [Bool] = []
        for char in base64URL {
            guard let value = alphabet.firstIndex(of: char) else { return nil }
            for shift in (0..<6).reversed() { result.append((value >> shift) & 1 == 1) }
        }
        return result
    }

    private static func field(_ bits: [Bool], at offset: Int) -> Int {
        (bits[offset] ? 2 : 0) + (bits[offset + 1] ? 1 : 0)
    }
}
