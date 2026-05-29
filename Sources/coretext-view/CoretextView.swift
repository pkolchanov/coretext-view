import ArgumentParser
import Cocoa

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

    @Option(name: .customLong("variations"), help: "Comma-separated list of font variations")
    var fontVariations: String?

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

        let variationDict = Self.parseVariations(variationsString: fontVariations)
        let atrs: [CFString: Any] = [
            kCTFontVariationAttribute: variationDict
        ]
        let descriptor = CTFontDescriptorCreateWithAttributes(atrs as CFDictionary)
        let varFont = CTFontCreateCopyWithAttributes(font, 0.0, nil, descriptor)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: varFont,
            .foregroundColor: CGColor(red: 0, green: 0, blue: 0, alpha: 1),
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString as CFAttributedString)

        let constraints = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, 0), nil, constraints, nil)
        let pageSize = CGSize(width: ceil(suggestedSize.width), height: ceil(suggestedSize.height))

        let textPath = CGMutablePath()
        let textRect = CGRect(origin: .zero, size: pageSize)
        textPath.addRect(textRect)

        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attributedString.length), textPath, nil)

        var mediaBox = CGRect(origin: .zero, size: pageSize)
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

    static func parseVariations(variationsString: String?) -> [NSNumber: NSNumber] {
        Dictionary(
            (variationsString ?? "")
                .split(separator: ",")
                .compactMap { pair -> (NSNumber, NSNumber)? in
                    let kv = pair.split(separator: "=", maxSplits: 1)
                    guard kv.count == 2 else { return nil }
                    let tag = String(kv[0]).trimmingCharacters(in: .whitespaces)
                    guard let value = Double(String(kv[1]).trimmingCharacters(in: .whitespaces)) else { return nil }
                    return (NSNumber(value: Self.axisID(tag)), NSNumber(value: value))
                },
            uniquingKeysWith: { _, last in last }
        )
    }

    static func axisID(_ tag: String) -> Int {
        tag.utf8.reduce(0) { ($0 << 8) | Int($1) }
    }

    static func createCTFont(fromFileURL url: URL, size: CGFloat) -> CTFont? {
        guard let fontData = try? Data(contentsOf: url) else { return nil }
        guard let dataProvider = CGDataProvider(data: fontData as CFData) else { return nil }
        guard let cgFont = CGFont(dataProvider) else { return nil }
        return CTFontCreateWithGraphicsFont(cgFont, size, nil, nil)
    }
}
