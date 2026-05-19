# Kircerta Utilities

Small local-first utilities.

## Projects

| Name | Description | Tech Stack | Build From Source |
|---|---|---|---|
| PDFColorInverter | PDF color inversion app. | Python, PyQt6, PyMuPDF, Pillow, NumPy | `python3 -m pip install PyQt6 PyMuPDF Pillow numpy`; `python3 PDFColorInverter/Color_Reverser_alpha/pdf_inverter.py` |
| QuickMemo | Menu bar memo app. | Swift, SwiftUI, Xcode | `xcodebuild -project QuickMemo/QuickMemo.xcodeproj -scheme QuickMemo -configuration Release build` |
| _replacer | Text find-and-replace app. | Swift, SwiftUI, Xcode | `xcodebuild -project _replacer/_replacer.xcodeproj -scheme _replacer -configuration Release build` |
| _resizer | Batch image resizing app. | Swift, SwiftUI, Xcode | `xcodebuild -project _resizer/ImageSizeTransformer.xcodeproj -scheme ImageSizeTransformer -configuration Release build` |
| _trexparent | Handwritten-note image cleanup app. | Swift, SwiftUI, Xcode | `xcodebuild -project _trexparent/_trexparent/Handwritten2Transparent.xcodeproj -scheme Handwritten2Transparent -configuration Release build` |
| brownoiser | Brown-noise tray app. | Python, pygame, pystray, Pillow, PyInstaller | `python3 -m pip install pygame pystray pillow pyinstaller`; `cd brownoiser && pyinstaller --onefile --windowed --add-data "brownnoise_sample1.wav:." --add-data "brownnoiser_winicon.ico:." brownoiser.py` |

## License

MIT. See `LICENSE`.
