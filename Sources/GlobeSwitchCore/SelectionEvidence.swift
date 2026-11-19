import Foundation

/// Resolves the independent selection representations exposed by a text field.
/// A collapsed numeric range does not invalidate nonempty selected text.
public struct SelectionEvidence {
    public let text: String?
    public let range: NSRange?
    public var hasSelection: Bool { text != nil || range != nil }

    public init(text: String?, markerText: String?, range: NSRange?) {
        self.text = [text, markerText].compactMap { $0 }.first { !$0.isEmpty }
        // Do not use a contradictory range to calculate the expected pasted value.
        if let range, range.location >= 0, range.location != NSNotFound,
           range.length > 0,
           self.text.map({ $0.utf16.count == range.length }) ?? true {
            self.range = range
        } else {
            self.range = nil
        }
    }
}

/// Predicts the full value after Paste when the host supplies enough evidence
/// to locate the selection, including editors without numeric selection ranges.
public func expectedPasteValue(before: String, selected: String, replacement: String,
                               range: NSRange?) -> String? {
    guard !selected.isEmpty else { return nil }
    let value = before as NSString
    let location: NSRange
    if let range, range.location >= 0, range.length == selected.utf16.count,
       range.length <= value.length, range.location <= value.length - range.length,
       value.substring(with: range).utf16.elementsEqual(selected.utf16) {
        location = range
    } else {
        let first = value.range(of: selected, options: .literal)
        guard first.location != NSNotFound,
              first == value.range(of: selected, options: [.literal, .backwards]) else { return nil }
        location = first
    }
    return value.replacingCharacters(in: location, with: replacement)
}
