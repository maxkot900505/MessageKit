/*
 MIT License
 
 Copyright (c) 2017 MessageKit
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

// Missing UILabel Properties

// adjustsFontSizeToFitWidth
// allowsDefaultTighteningForTruncation
// baselineAdjustment
// minimumScaleFactor
// highlightedTextColor
// isHighlighted
// shadowColor
// shadowOffset

import UIKit
extension NSTextStorage {
    
    var attributedString: NSAttributedString {
        let range = NSRange(location: 0, length: mutableString.length)
        return attributedSubstring(from: range)
    }
    
    var mutableAttributedString: NSMutableAttributedString {
        return NSMutableAttributedString(attributedString: attributedString)
    }
    
    func addAttribute(key: NSAttributedStringKey, value: AnyObject, range: NSRange? = nil) {
        let range = range ?? NSRange(location: 0, length: length)
        addAttribute(key, value: value, range: range)
    }
    
}

open class MessageLabel: UIView, UIGestureRecognizerDelegate {

    // MARK: - Properties [Public]
    
    public weak var delegate: MessageLabelDelegate?
    
    public var attributedText: NSAttributedString? {
        get {
            return textStorage.attributedString
        }
        set {
            let string = newValue ?? NSAttributedString(string: "")
            // we may have to add paragraph attributes here
            textStorage.setAttributedString(string)
            
            setStorageByParsing(text: string) {
                if !self.isConfiguring { self.setNeedsDisplay() }
            }
            
            if !isConfiguring { setNeedsDisplay() }
        }
    }
    
    public var text: String? {
        get {
            return textStorage.string
        }
        set {
            let string = addLocalAttributes(to: newValue)
            textStorage.setAttributedString(string)
            
            setStorageByParsing(text: string) {
                if !self.isConfiguring { self.setNeedsDisplay() }
            }
            
            if !isConfiguring { setNeedsDisplay() }
        }
    }
    
    public var font: UIFont = UIFont.systemFont(ofSize: 10.0) {
        didSet {
            textStorage.addAttribute(key: .font, value: font)
            updateDetectorAttributes(for: .font)
            if !isConfiguring { setNeedsDisplay() }
        }
    }
    
    public var textColor: UIColor = .darkText {
        didSet {
            textStorage.addAttribute(key: .foregroundColor, value: textColor)
            updateDetectorAttributes(for: .foregroundColor)
            if !isConfiguring { setNeedsDisplay() }
        }
    }
    
    public var lineBreakMode: NSLineBreakMode = .byWordWrapping {
        didSet {
            textContainer.lineBreakMode = lineBreakMode
            if !isConfiguring { setNeedsDisplay() }
        }
    }
    
    public var lineFragmentPadding: CGFloat = 0 {
        didSet {
            textContainer.lineFragmentPadding = lineFragmentPadding
            if !isConfiguring { setNeedsDisplay() }
        }
    }
    
    public var numberOfLines: Int = 0 {
        didSet {
            textContainer.maximumNumberOfLines = numberOfLines
            if !isConfiguring { setNeedsDisplay() }
        }
    }
    public var textAlignment: NSTextAlignment = .center {
        didSet {
            textStorage.addAttribute(key: .paragraphStyle, value: paragraphStyle)
            if !isConfiguring { setNeedsDisplay() }
        }
    }

    public var textInsets: UIEdgeInsets = .zero {
        didSet {
            if !isConfiguring { setNeedsDisplay() }
        }
    }
    
    public var enabledDetectors: [DetectorType] = [] {
        didSet {
            setStorageByParsing(text: attributedText) {
                if !self.isConfiguring { self.setNeedsDisplay() }
            }
        }
    }
    
    public var phoneAttributes: [NSAttributedStringKey: Any] = [:] {
        didSet {
            updateDetectorAttributes(for: .phoneNumber)
            if !isConfiguring { setNeedsDisplay() }
        }
    }
    
    public var addressAttributes: [NSAttributedStringKey: Any] = [:] {
        didSet {
            updateDetectorAttributes(for: .address)
            if !isConfiguring { setNeedsDisplay() }
        }
    }
    
    public var urlAttributes: [NSAttributedStringKey: Any] = [:] {
        didSet {
            updateDetectorAttributes(for: .url)
            if !isConfiguring { setNeedsDisplay() }
        }
    }
    
    public var dateAttributes: [NSAttributedStringKey: Any] = [:] {
        didSet {
            updateDetectorAttributes(for: .date)
            if !isConfiguring { setNeedsDisplay() }
        }
    }
    
    // MARK: - Properties [Private]
    
    private var layoutManager: NSLayoutManager
    
    private var textContainer: NSTextContainer
    
    private var textStorage: NSTextStorage
    
    private var phoneResults: [NSRange: String?] = [:]
    
    private var addressResults: [NSRange: Any?] = [:]
    
    private var dateResults: [NSRange: Date?] = [:]
    
    private var urlResults: [NSRange: URL?] = [:]
    
    private var isConfiguring: Bool = false
    
    private var paragraphStyle: NSParagraphStyle {
        
        guard textStorage.attributedString.length > 0 else { return NSParagraphStyle() }
        
        var range = NSRange(location: 0, length: textStorage.length)
        let existingStyle = textStorage.attributedString.attribute(.paragraphStyle, at: 0, effectiveRange: &range) as? NSMutableParagraphStyle
        let style = existingStyle ?? NSMutableParagraphStyle()
        
        style.lineBreakMode = lineBreakMode
        style.alignment = textAlignment
        
        
        
        return style
        
    }
    
    // MARK: - Initializers
    
    public override init(frame: CGRect) {
        
        self.textContainer = NSTextContainer()
        self.textContainer.lineFragmentPadding = lineFragmentPadding
        self.textContainer.maximumNumberOfLines = numberOfLines
        self.textContainer.lineBreakMode = lineBreakMode
        self.textContainer.size = frame.size
        
        self.layoutManager = NSLayoutManager()
        self.layoutManager.addTextContainer(self.textContainer)
        
        self.textStorage = NSTextStorage(attributedString: NSAttributedString(string: ""))
        textStorage.addLayoutManager(layoutManager)
        
        super.init(frame: frame)
        
        let defaultAttributes: [NSAttributedStringKey: Any] = [
            .underlineStyle: NSUnderlineStyle.styleSingle.rawValue,
            .underlineColor: self.textColor
        ]
        
        self.addressAttributes = defaultAttributes
        self.phoneAttributes = defaultAttributes
        self.dateAttributes = defaultAttributes
        self.urlAttributes = defaultAttributes
        
        setupGestureRecognizers()
        
        backgroundColor = .clear
        
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Methods [Public]
    
    open override func draw(_ rect: CGRect) {
        
        let insetRect = UIEdgeInsetsInsetRect(rect, textInsets)
        textContainer.size = insetRect.size
        
        let range = layoutManager.glyphRange(for: textContainer)
        let origin = insetRect.origin
        
        layoutManager.drawBackground(forGlyphRange: range, at: origin)
        layoutManager.drawGlyphs(forGlyphRange: range, at: origin)
        
    }
    
    public func configure(configurationBlock: () -> Void) {
        isConfiguring = true
        configurationBlock()
        isConfiguring = false
        setNeedsDisplay()
    }
    
    // MARK: - Methods [Private]
    
    private func addLocalAttributes(to string: String?) -> NSAttributedString {
        
        guard let string = string, string != "" else {
            return NSAttributedString(string: "")
        }
        
        let attributes: [NSAttributedStringKey: AnyObject] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        
        let mutableString = NSMutableAttributedString(string: string)
        
        // Later we will exclude detected ranges
        let range = NSRange(location: 0, length: mutableString.length)
        mutableString.addAttributes(attributes, range: range)
        
        return NSAttributedString(attributedString: mutableString)
    }
    
    private func applyAttributes(_ attributes: [NSAttributedStringKey: Any], to ranges: [NSRange]) {
        
        guard !attributes.isEmpty || !ranges.isEmpty else { return }
        
        for range in ranges {
            textStorage.mutableAttributedString.addAttributes(attributes, range: range)
        }
        
    }
    
    func detectedRanges(for detectorType: DetectorType) -> [NSRange]? {
        
        let ranges = { (results: [NSRange: Any?]) -> [NSRange]? in
            guard !results.isEmpty else { return nil }
            return results.map { $0.key }
        }
        
        switch detectorType {
        case .address:
            return ranges(addressResults)
        case .phoneNumber:
            return ranges(phoneResults)
        case .date:
            return ranges(dateResults)
        case .url:
            return ranges(urlResults)
        }
    }
    
    private func updateDetectorAttributes(for detector: DetectorType) {
        guard enabledDetectors.contains(detector) else { return }
        guard let ranges = detectedRanges(for: detector) else { return }
        let attributes = detectorAttributes(for: detector)
        applyAttributes(attributes, to: ranges)
    }
    
    func detectorAttributes(for detectorType: DetectorType) -> [NSAttributedStringKey: Any] {
        switch detectorType {
        case .address: return addressAttributes
        case .date: return dateAttributes
        case .phoneNumber: return phoneAttributes
        case .url: return urlAttributes
        }
    }
    
    func detectorResults(for detectorType: DetectorType) -> [NSRange: Any?] {
        switch detectorType {
        case .address: return addressResults
        case .phoneNumber: return phoneResults
        case .date: return dateResults
        case .url: return urlResults
        }
    }
    
    private func updateDetectorAttributes(for key: NSAttributedStringKey? = nil) {
        
        guard !enabledDetectors.isEmpty else { return }
        
        let selectedAttributes = { (attributes: [NSAttributedStringKey: Any], key: NSAttributedStringKey?)
                            -> [NSAttributedStringKey: Any]? in
            
            // Key was found so we are applying selective attributes
            if let key = key {
                // No attributes exist for this key, exit early
                guard let value = attributes[key] else { return nil }
                return [key: value]
            } else {
                return attributes
            }
        
        }

        for detector in enabledDetectors {
            if let ranges = detectedRanges(for: detector) {
                let attributes = detectorAttributes(for: detector)
                guard let selected = selectedAttributes(attributes, key) else { continue }
                applyAttributes(selected, to: ranges)
            }
        }
        
    }
    
    private func setStorageByParsing(text: NSAttributedString?, completion: @escaping () -> Void) {
        
        removeAllDetectedResults()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            
            defer {
                DispatchQueue.main.async {
                    completion()
                }
            }
            
            guard let `self` = self else { return }
            guard let text = text, text.length > 0, !self.enabledDetectors.isEmpty else { return }
            guard let checkingResults = self.parse(text: text.string) else { return }
  
            self.setDetectorResults(for: checkingResults)
            self.updateDetectorAttributes()

        }
        
    }
    
    private func parse(text: String) -> [NSTextCheckingResult]? {
        let checkingTypes = enabledDetectors.reduce(0) { $0 | $1.textCheckingType.rawValue }
        let detector = try? NSDataDetector(types: checkingTypes)
        let string = NSString(string: text)
        let range = NSRange(location: 0, length: string.length)
        return detector?.matches(in: text, options: [], range: range)
    }
    
    private func setDetectorResults(for checkingResults: [NSTextCheckingResult]) {
        guard !checkingResults.isEmpty else { return }
        
        for result in checkingResults {
            switch result.resultType {
            case NSTextCheckingResult.CheckingType.address:
                addressResults[result.range] = result.addressComponents
            case NSTextCheckingResult.CheckingType.date:
                dateResults[result.range] = result.date
            case NSTextCheckingResult.CheckingType.phoneNumber:
                phoneResults[result.range] = result.phoneNumber
            case NSTextCheckingResult.CheckingType.link:
                urlResults[result.range] = result.url
            default:
                fatalError("Received an unrecognized NSTextCheckingResult.CheckingType")
            }
        }
    }
    
    private func removeAllDetectedResults() {
        phoneResults.removeAll()
        addressResults.removeAll()
        dateResults.removeAll()
        urlResults.removeAll()
    }
    
    // MARK: - Gesture Handling
    
    private func stringIndex(at location: CGPoint) -> Int? {
        guard textStorage.length > 0 else { return nil }
        
        var location = location
        let textOffset = CGPoint(x: textInsets.left, y: textInsets.right) // <- bug?
        
        location.x -= textOffset.x
        location.y -= textOffset.y
        
        let glyphIndex = layoutManager.glyphIndex(for: location, in: textContainer)
        
        let lineRect = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: nil)
        
        let rectContainsLocation = lineRect.contains(location)
        
        return rectContainsLocation ? layoutManager.characterIndexForGlyph(at: glyphIndex) : nil
        
    }
    
    private func setupGestureRecognizers() {
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
        addGestureRecognizer(tapGesture)
        tapGesture.delegate = self
        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
        addGestureRecognizer(longPressGesture)
        tapGesture.delegate = self
        
        isUserInteractionEnabled = true
    }
    
    @objc
    func handleGesture(_ gesture: UIGestureRecognizer) {
        
        let touchLocation = gesture.location(ofTouch: 0, in: self)
        guard let index = stringIndex(at: touchLocation) else { return }
        
        var detectorRangeMap: [DetectorType: [NSRange]] = [:]
        
        for detector in enabledDetectors where !enabledDetectors.isEmpty {
            detectorRangeMap[detector] = detectedRanges(for: detector)
        }
        
        for (detectorType, ranges) in detectorRangeMap {
            for nsRange in ranges {
                guard let range = Range(nsRange), range.contains(index) else { continue }
                let results = detectorResults(for: detectorType)
                guard !results.isEmpty, let value = results[nsRange] else { continue }
                forwardToDelegateMethod(for: detectorType, value: value)
            }
        }
    }
    
    private func forwardToDelegateMethod(for detector: DetectorType, value: Any?) {
        switch detector {
        case .address:
            guard let addressComponents = value as? [String: String] else { return }
            handleAddress(addressComponents)
        case .phoneNumber:
            guard let phoneNumber = value as? String else { return }
            handlePhoneNumber(phoneNumber)
        case .date:
            guard let date = value as? Date else { return }
            handleDate(date)
        case .url:
            guard let url = value as? URL else { return }
            handleURL(url)
        }
    }
    
    private func handleAddress(_ addressComponents: [String: String]) {
        delegate?.didSelectAddress(addressComponents)
    }
    
    private func handleDate(_ date: Date) {
        delegate?.didSelectDate(date)
    }
    
    private func handleURL(_ url: URL) {
        delegate?.didSelectURL(url)
    }
    
    private func handlePhoneNumber(_ phoneNumber: String) {
        delegate?.didSelectPhoneNumber(phoneNumber)
    }
    
    // MARK: UIGestureRecognizer Delegate
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    //swiftlint:disable cyclomatic_complexity
    // Yeah we're disabling this because the whole file is a mess :D
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        
        let touchLocation = touch.location(in: self)
        
        var activeRanges: [NSRange] = []
        
        for detector in enabledDetectors where !enabledDetectors.isEmpty {
            guard let ranges = detectedRanges(for: detector) else { continue }
            activeRanges.append(contentsOf: ranges)
        }
        
        switch true {
        case gestureRecognizer.view != self.superview && gestureRecognizer.view != self:
            return true
        case gestureRecognizer.view == self.superview:
            guard let index = stringIndex(at: touchLocation) else { return true }
            for nsRange in activeRanges {
                guard let range = Range(nsRange) else { return true }
                if range.contains(index) { return false }
            }
            return true
        case gestureRecognizer.view == self:
            guard let index = stringIndex(at: touchLocation) else { return false }
            for nsRange in activeRanges {
                guard let range = Range(nsRange) else { return false }
                if range.contains(index) { return true}
            }
            return false
        default:
            return true
        }
        
    }
    
}
