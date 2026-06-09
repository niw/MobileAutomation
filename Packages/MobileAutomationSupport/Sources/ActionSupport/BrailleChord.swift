import Foundation

/// A single Braille keyboard chord: a set of dot numbers (1–8) optionally
/// combined with the Space bar. iOS / VoiceOver treats Space + dots as a
/// distinct chord from dots alone.
public struct BrailleChord: Sendable, Hashable {
    public var dots: Set<Int>
    public var space: Bool

    public init(dots: Set<Int> = [], space: Bool = false) {
        self.dots = dots
        self.space = space
    }

    /// Convenience initializer using a variadic dot list.
    public init(_ dots: Int..., space: Bool = false) {
        self.init(dots: Set(dots), space: space)
    }

    /// Unicode Braille glyph (U+2800–U+28FF) for the dots in this chord,
    /// ignoring the Space modifier. Useful for previews.
    public var brailleGlyph: String {
        var bits: UInt32 = 0
        for dot in dots where (1 ... 8).contains(dot) {
            bits |= 1 << (dot - 1)
        }
        return String(UnicodeScalar(0x2800 + bits)!)
    }

    /// Compact human-readable form, e.g. `Space+1-2-5` or `1-2-5`.
    public var displayString: String {
        if dots.isEmpty {
            return space ? "Space" : "(empty)"
        }
        let joined = dots.sorted().map(String.init).joined(separator: "-")
        return space ? "Space+\(joined)" : joined
    }
}
