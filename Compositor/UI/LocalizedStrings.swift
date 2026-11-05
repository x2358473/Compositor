import AppKit
import SwiftUI

extension String {
    /// The English name an enum keeps in its raw value, or a title built from one, looked up in the
    /// String Catalog. `Text(someString)` shows it untranslated: only a LocalizedStringKey is looked up.
    var localizedKey: LocalizedStringKey { LocalizedStringKey(self) }
    /// A sentence that says itself, looked up, is looked up too.
    var localized: String { NSLocalizedString(self, comment: "") }
    /// Fills a localized `%@` template with a name that is itself looked up, so "Levels" in "Levels
    /// color" is translated as well as the sentence around it.
    func localizedFormat(_ name: String) -> String {
        String(format: NSLocalizedString(self, comment: ""), NSLocalizedString(name, comment: ""))
    }
}

extension LocalizedStringKey {
    /// A title that is already a key passes through: callers take either a literal or a string, and
    /// both reach `Text(title.localizedKey)`.
    var localizedKey: LocalizedStringKey { self }
}

extension NSMenuItem {
    /// A menu item whose title is held in a string rather than written at the call, which
    /// `NSMenuItem(title:)` would show untranslated.
    convenience init(localized title: String, action: Selector?, keyEquivalent: String = "") {
        self.init(title: NSLocalizedString(title, comment: ""), action: action, keyEquivalent: keyEquivalent)
    }
}
