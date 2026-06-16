//
//  ResumeRTL.swift
//  ResumeBuilder IOS APP
//
//  Right-to-left support for resume preview HTML and PDF export. Direction is
//  derived from the resume CONTENT (presence of Hebrew letters) rather than the
//  app UI language, so a Hebrew résumé renders RTL even with an English UI and
//  vice-versa.
//

import Foundation

enum ResumeTextDirection {
    /// True when the combined resume content is predominantly right-to-left (Hebrew).
    static func isRTL(sections: [OptimizedResumeSection], contact: ResumeContact?) -> Bool {
        var text = ""
        if let contact {
            text += [contact.name, contact.title, contact.contactLine]
                .compactMap { $0 }
                .joined(separator: " ")
        }
        for section in sections {
            text += " " + section.body
        }
        return isRTLText(text)
    }

    /// Heuristic: RTL when Hebrew letters are present and at least as common as Latin letters.
    static func isRTLText(_ text: String) -> Bool {
        var hebrew = 0
        var latin = 0
        for scalar in text.unicodeScalars {
            let v = scalar.value
            if (0x0590...0x05FF).contains(v) || (0xFB1D...0xFB4F).contains(v) {
                hebrew += 1
            } else if (0x41...0x5A).contains(v) || (0x61...0x7A).contains(v) {
                latin += 1
            }
        }
        return hebrew > 0 && hebrew >= latin
    }
}

enum ResumeHTMLDirection {
    /// Hebrew-capable font stack used for RTL résumés (system Hebrew faces first).
    static let hebrewFontStack = "-apple-system, 'Heebo', 'Arial Hebrew', 'Arial', sans-serif"

    /// Makes an HTML document render right-to-left: sets `dir="rtl"` on `<html>`
    /// (if absent) and appends RTL CSS overrides (direction, alignment, logical
    /// list indentation, Hebrew font). Safe to apply to backend-rendered HTML of
    /// unknown structure; the appended `<style>` wins by cascade order.
    static func applyRTL(to html: String) -> String {
        var out = html

        // 1. Ensure the <html> element carries dir="rtl".
        if let htmlTag = out.range(of: "<html", options: .caseInsensitive) {
            let afterTag = out.range(of: ">", range: htmlTag.lowerBound..<out.endIndex)?.lowerBound ?? out.endIndex
            let tagText = out[htmlTag.lowerBound..<afterTag].lowercased()
            if !tagText.contains("dir=") {
                out.replaceSubrange(htmlTag, with: "<html dir=\"rtl\"")
            }
        } else {
            out = "<html dir=\"rtl\">" + out
        }

        // 2. Append RTL CSS overrides.
        let css = """
        <style>
        html, body { direction: rtl; }
        body { text-align: right; font-family: \(hebrewFontStack); }
        ul, ol { padding-right: 1.1em; padding-left: 0; }
        .section ul { margin-right: 16px; margin-left: 0; }
        </style>
        """
        if let headClose = out.range(of: "</head>", options: .caseInsensitive) {
            out.replaceSubrange(headClose, with: css + "</head>")
        } else if let bodyOpen = out.range(of: "<body", options: .caseInsensitive) {
            out.insert(contentsOf: css, at: bodyOpen.lowerBound)
        } else {
            out = css + out
        }
        return out
    }

    /// Applies RTL only when `isRTL` is true; otherwise returns the HTML unchanged.
    static func applyRTLIfNeeded(to html: String, isRTL: Bool) -> String {
        isRTL ? applyRTL(to: html) : html
    }
}
