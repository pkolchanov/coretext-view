import ArgumentParser
import Cocoa
import UniformTypeIdentifiers

@main
struct CoretextView: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "coretext-view",
        abstract: "View text with given font using CoreText API.",
        usage: "coretext-view [OPTION…] [FONT-FILE] [TEXT]"
    )

    @Option(name: .customLong("font-file"), help: "Set font file-name")
    var fontFileOption: String?

    @Option(name: .customLong("font-size"), help: "Font size")
    var fontSize: Double = 12

    @Option(name: .customLong("text"), help: "Set input text")
    var textOption: String?

    @Option(
        name: .customLong("variations"),
        help: "Comma-separated list of font variations.\nFor example \"wght=400,wdth=0\"")
    var fontVariations: String?

    @Option(
        name: .customLong("features"),
        help: "Comma-separated list of font opentype features.\n\nSyntax:\tValue:\n\"liga\"\t1\t# Turn feature on\n\"+liga\"\t1\t# Turn feature on\n\"-liga\"\t0\t# Turn feature off\n\"liga=1\"\t1\t# Turn feature on\n\"liga=0\"\t0\t# Turn feature off\n")
    var fontFeatures: String?

    @Option(
        name: .customLong("language"),
        help: "Set text language using BCP 47 tag")
    var language: String?

    @Option(name: [.customShort("o"), .customLong("output-file")], help: "Set output file-name")
    var outputFile: String = "out.pdf"

    @Argument(help: ArgumentHelp("Font file-name", valueName: "font-file"))
    var fontFileArgument: String?

    @Argument(help: ArgumentHelp("Input text", valueName: "text"))
    var textArgument: String?

    func run() throws {
        guard let fontFile = fontFileOption ?? fontFileArgument else {
            throw ValidationError("No font file")
        }
        guard let text = textOption ?? textArgument else {
            throw ValidationError("No input text")
        }

        let fileURL = URL(fileURLWithPath: fontFile)
        let outURL = URL(fileURLWithPath: outputFile)

        guard let font = Self.createCTFont(fromFileURL: fileURL, size: CGFloat(fontSize)) else {
            throw ValidationError("Failed to load font from \(fileURL.path)")
        }
        let fontAttributes: [CFString: Any] = [
            kCTFontVariationAttribute: Self.parseVariations(variationsString: fontVariations),
            kCTFontFeatureSettingsAttribute: Self.parseFeatures(featuresString: fontFeatures),
        ]
        let descriptor = CTFontDescriptorCreateWithAttributes(fontAttributes as CFDictionary)
        let varFont = CTFontCreateCopyWithAttributes(font, 0.0, nil, descriptor)

        var stringAttributes: [NSAttributedString.Key: Any] = [
            .font: varFont,
            .foregroundColor: CGColor(red: 0, green: 0, blue: 0, alpha: 1),
        ]
        if let language = language {
            stringAttributes[NSAttributedString.Key(kCTLanguageAttributeName as String)] = language
        }
        let attributedString = NSAttributedString(string: text, attributes: stringAttributes)
        let framesetter = CTFramesetterCreateWithAttributedString(
            attributedString as CFAttributedString)
        let constraints = CGSize(
            width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter, CFRangeMake(0, 0), nil, constraints, nil)
        let pageSize = CGSize(width: ceil(suggestedSize.width), height: ceil(suggestedSize.height))

        let textPath = CGMutablePath()
        let textRect = CGRect(origin: .zero, size: pageSize)
        textPath.addRect(textRect)

        let frame = CTFramesetterCreateFrame(
            framesetter, CFRangeMake(0, attributedString.length), textPath, nil)
        let mediaBox = CGRect(origin: .zero, size: pageSize)

        try Self.export(outURL: outURL, frame: frame, mediaBox: mediaBox)
    }

    static func exportPDF(outURL: URL, frame: CTFrame, mediaBox: CGRect) throws {
        var mediaBox = mediaBox
        guard let pdfContext = CGContext(outURL as CFURL, mediaBox: &mediaBox, nil) else {
            throw ValidationError("Failed to create PDF context at \(outURL.path)")
        }

        pdfContext.beginPDFPage(nil)
        pdfContext.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        pdfContext.fill(mediaBox)
        CTFrameDraw(frame, pdfContext)
        pdfContext.endPDFPage()
        pdfContext.closePDF()

        print("Successfully wrote PDF to \(outURL.path)")
    }

    static func export(outURL: URL, frame: CTFrame, mediaBox: CGRect) throws {
        guard let type = UTType(filenameExtension: outURL.pathExtension) else {
            throw ValidationError("Unknown output extention")
        }
        switch type {
        case _ where type.conforms(to: .pdf):
            try Self.exportPDF(outURL: outURL, frame: frame, mediaBox: mediaBox)
        case _ where type.conforms(to: .image):
            try Self.exportImage(outURL: outURL, frame: frame, mediaBox: mediaBox)
        default:
            throw ValidationError("Unknown output extention")
        }
    }

    static func exportImage(outURL: URL, frame: CTFrame, mediaBox: CGRect) throws {
        guard
            let context = CGContext(
                data: nil,
                width: Int(mediaBox.width),
                height: Int(mediaBox.height),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            throw ValidationError("Failed to create bitmap context")
        }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(mediaBox)
        CTFrameDraw(frame, context)

        guard let image = context.makeImage() else {
            throw ValidationError("Failed to render image")
        }

        guard let type: UTType = UTType(filenameExtension: outURL.pathExtension),
            let dest = CGImageDestinationCreateWithURL(
                outURL as CFURL, type.identifier as CFString, 1, nil)
        else {
            throw ValidationError("Unsupported image format: \(outURL.pathExtension)")
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw ValidationError("Failed to encode \(outURL.pathExtension)")
        }

        print("Successfully wrote image to \(outURL.path)")
    }

    static func parseVariations(variationsString: String?) -> [NSNumber: NSNumber] {
        Dictionary(
            (variationsString ?? "")
                .split(separator: ",")
                .compactMap { pair -> (NSNumber, NSNumber)? in
                    let kv = pair.split(separator: "=", maxSplits: 1)
                    guard kv.count == 2 else { return nil }
                    let tag = String(kv[0]).trimmingCharacters(in: .whitespaces)
                    guard let value = Double(String(kv[1]).trimmingCharacters(in: .whitespaces))
                    else { return nil }
                    return (NSNumber(value: Self.axisID(tag)), NSNumber(value: value))
                },
            uniquingKeysWith: { _, last in last }
        )
    }

    static func parseFeatures(featuresString: String?) -> [[String: Any]] {
        let featureTag = kCTFontOpenTypeFeatureTag as String
        let featureValue = kCTFontOpenTypeFeatureValue as String

        return (featuresString ?? "")
            .split(separator: ",")
            .compactMap { token -> (tag: String, value: Int)? in
                let token = token.trimmingCharacters(in: .whitespaces)

                if token.contains("=") {
                    let kv = token.split(separator: "=", maxSplits: 1)
                    guard kv.count == 2 else { return nil }
                    let tag = String(kv[0]).trimmingCharacters(in: .whitespaces)
                    guard let value = Int(String(kv[1]).trimmingCharacters(in: .whitespaces)) else {
                        return nil
                    }
                    return (tag, value)
                }

                if token.hasPrefix("+") {
                    return (String(token.dropFirst()), 1)
                }
                if token.hasPrefix("-") {
                    return (String(token.dropFirst()), 0)
                }
                return (token, 1)
            }
            .map { [featureTag: $0.tag, featureValue: $0.value] }
    }

    static func axisID(_ tag: String) -> Int {
        //FourCC
        tag.utf8.reduce(0) { ($0 << 8) | Int($1) }
    }

    static func createCTFont(fromFileURL url: URL, size: CGFloat) -> CTFont? {
        guard let fontData = try? Data(contentsOf: url) else { return nil }
        guard let dataProvider = CGDataProvider(data: fontData as CFData) else { return nil }
        guard let cgFont = CGFont(dataProvider) else { return nil }
        return CTFontCreateWithGraphicsFont(cgFont, size, nil, nil)
    }
}
