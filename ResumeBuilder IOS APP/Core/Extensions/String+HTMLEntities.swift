import Foundation

extension String {
    /// Decodes the HTML entities that reach us in backend-extracted text.
    ///
    /// Job titles and company names are extracted from job descriptions that are
    /// frequently pasted from web pages, so they arrive HTML-escaped. Nothing in
    /// this app decoded them, so a founder run on 2026-07-29 rendered
    /// `Sales &amp; Business Development Manager` verbatim on the optimized
    /// preview and again inside the diagnosis copy.
    ///
    /// Deliberately a small explicit table rather than `NSAttributedString`'s
    /// HTML importer: that importer must run on the main thread, is an order of
    /// magnitude slower, and will happily interpret arbitrary markup — none of
    /// which is appropriate for rendering a job title into a `Text`.
    ///
    /// Ampersand is unescaped **last** so `&amp;lt;` decodes to the literal
    /// `&lt;` rather than being double-decoded into `<`.
    func decodingHTMLEntities() -> String {
        guard contains("&") else { return self }

        var result = self

        // Numeric entities first: &#38; / &#x26;
        result = result.replacingNumericHTMLEntities()

        let named: [(String, String)] = [
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&apos;", "'"),
            ("&#39;", "'"),
            ("&nbsp;", "\u{00A0}"),
            ("&ndash;", "–"),
            ("&mdash;", "—"),
            ("&hellip;", "…"),
            ("&rsquo;", "’"),
            ("&lsquo;", "‘"),
            ("&rdquo;", "”"),
            ("&ldquo;", "“"),
            // &amp; MUST stay last — see note above.
            ("&amp;", "&"),
        ]

        for (entity, replacement) in named {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }

        return result
    }

    /// Whether two user-facing strings say the same thing.
    ///
    /// Used to suppress a "detail" line that merely restates its title. An
    /// exact `!=` check let differences in trailing whitespace, case, or
    /// punctuation through, which rendered the same sentence twice in the
    /// blockers list.
    func isEquivalentCopy(to other: String) -> Bool {
        func normalized(_ value: String) -> String {
            value
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
                .trimmingCharacters(in: CharacterSet(charactersIn: ".!,;: "))
        }
        return normalized(self) == normalized(other)
    }

    /// Replaces `&#NN;` and `&#xHH;` with their scalar, leaving anything
    /// unparseable exactly as found.
    private func replacingNumericHTMLEntities() -> String {
        guard contains("&#") else { return self }

        let pattern = "&#(x[0-9a-fA-F]+|[0-9]+);"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return self }

        var result = self
        let matches = regex.matches(in: self, range: NSRange(startIndex..., in: self))

        // Reverse order so earlier ranges stay valid as we substitute.
        for match in matches.reversed() {
            guard
                let full = Range(match.range, in: result),
                let digits = Range(match.range(at: 1), in: self)
            else { continue }

            let token = String(self[digits])
            let value: UInt32?
            if token.hasPrefix("x") || token.hasPrefix("X") {
                value = UInt32(token.dropFirst(), radix: 16)
            } else {
                value = UInt32(token, radix: 10)
            }

            guard let value, let scalar = Unicode.Scalar(value) else { continue }
            result.replaceSubrange(full, with: String(Character(scalar)))
        }

        return result
    }
}
