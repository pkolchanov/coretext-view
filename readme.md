# coretext-view
View text with a given font using CoreText API, similar to `hb-view`.

### build and run
`swift build -c release && .build/release/coretext-view --help`

or use Homebrew

`brew install pkolchanov/tap/coretext-view`

```
OVERVIEW: View text with given font using CoreText API.

USAGE: coretext-view [OPTION…] [FONT-FILE] [TEXT]

ARGUMENTS:
  <font-file>             Font file-name
  <text>                  Input text

OPTIONS:
  --font-file <font-file> Set font file-name
  --font-size <font-size> Font size (default: 12.0)
  --text <text>           Set input text
  --unicodes <unicodes>   Set input Unicode codepoints
  --variations <variations>
                          Comma-separated list of font variations.
                          For example "wght=400,wdth=0"
  --features <features>   Comma-separated list of font opentype features.

                          Syntax:	Value:
                          "liga"	1	# Turn feature on
                          "+liga"	1	# Turn feature on
                          "-liga"	0	# Turn feature off
                          "liga=1"	1	# Turn feature on
                          "liga=0"	0	# Turn feature off

  --language <language>   Set text language using BCP 47 tag
  -o, --output-file <output-file>
                          Set output file-name (default: out.pdf)
  -h, --help              Show help information.
```