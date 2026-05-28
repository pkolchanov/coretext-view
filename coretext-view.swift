import Cocoa

let fileURL = URL(fileURLWithPath: "/Users/pkolchanov/vf-check/BibliograficaVFRomanNOCOMP.ttf")
let outURL = URL(fileURLWithPath: "/Users/pkolchanov/vf-check/out.pdf")
let text = "Sophistication"
let fontSize: CGFloat = 12

func createCTFont(fromFileURL url: URL, size: CGFloat) -> CTFont? {
    guard let fontData = try? Data(contentsOf: url) else { return nil }
    guard let dataProvider = CGDataProvider(data: fontData as CFData) else { return nil }
    guard let cgFont = CGFont(dataProvider) else { return nil }
    let ctFont = CTFontCreateWithGraphicsFont(cgFont, size, nil, nil)
    return ctFont
}

let font = createCTFont(fromFileURL: fileURL, size: fontSize)

let attributes: [NSAttributedString.Key: Any] = [
    .font: font!,
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
    fatalError("Failed to create PDF context at \(outURL.path)")
}

pdfContext.beginPDFPage(nil)
pdfContext.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
pdfContext.fill(mediaBox)
CTFrameDraw(frame, pdfContext)
pdfContext.endPDFPage()
pdfContext.closePDF()

print("Successfully wrote PDF to \(outURL.path)")
