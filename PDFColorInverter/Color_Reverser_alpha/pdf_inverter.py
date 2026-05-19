import sys
import os
import fitz  # PyMuPDF
import numpy as np
from PIL import Image, ImageFilter
import io
from PyQt6.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout,
                             QPushButton, QLabel, QFileDialog, QRadioButton,
                             QButtonGroup, QProgressBar, QMessageBox)
from PyQt6.QtCore import Qt, QThread, pyqtSignal

# --- Configuration: Quality First ---
# 5.0 is approx 360 DPI
# Note: If processing A3 or larger formats, memory might be tight; consider lowering to 4.0

ZOOM_FACTOR = 5.0
SATURATION_THRESHOLD = 25  # Color determination threshold (lower is stricter)


# ------------------------

class WorkerThread(QThread):
    progress_update = pyqtSignal(int)
    finished = pyqtSignal(str)
    error = pyqtSignal(str)

    def __init__(self, input_path, mode):
        super().__init__()
        self.input_path = input_path
        self.mode = mode

    def run(self):
        try:
            doc = fitz.open(self.input_path)
            output_doc = fitz.open()
            total_pages = len(doc)

            for i, page in enumerate(doc):
                # 1. Ultra-high-definition rendering (No Alpha channel to avoid transparency interference with inversion)
                pix = page.get_pixmap(matrix=fitz.Matrix(ZOOM_FACTOR, ZOOM_FACTOR), alpha=False)

                # 2. Convert to PIL Image for preprocessing
                img = Image.frombytes("RGB", [pix.width, pix.height], pix.samples)

                # [Critical Step] Pre-sharpening: Enhance edge contrast before inversion to reduce blur in gray transition zones
                img = img.filter(ImageFilter.SHARPEN)

                # Convert to Numpy array
                img_data = np.array(img)

                # 3. Core inversion logic
                if self.mode == 'full':
                    # Global inversion
                    img_data = 255 - img_data

                elif self.mode == 'smart':
                    # === High-precision V4 Algorithm (Pure logic) ===

                    # Convert to int16 to ensure calculation precision
                    work_data = img_data.astype(np.int16)
                    r, g, b = work_data[:, :, 0], work_data[:, :, 1], work_data[:, :, 2]

                    # Calculate saturation (Max - Min)
                    max_val = np.maximum(np.maximum(r, g), b)
                    min_val = np.minimum(np.minimum(r, g), b)
                    saturation = max_val - min_val

                    # Create mask: Low saturation = Black/White/Gray = Needs inversion
                    # High saturation = Color = Keep original
                    mask = saturation < SATURATION_THRESHOLD

                    # Generate inverted layer
                    inverted_data = 255 - img_data

                    # Combine: Use inverted color where mask is True, otherwise use original color
                    # Apply to 3 channels using broadcasting
                    mask_3d = np.stack([mask] * 3, axis=2)
                    img_data = np.where(mask_3d, inverted_data, img_data)

                # 4. Encapsulate and export
                processed_img = Image.fromarray(img_data.astype('uint8'))

                img_byte_arr = io.BytesIO()
                # Use PNG to maintain pixel-perfect lossless quality (larger file size but highest quality)
                processed_img.save(img_byte_arr, format='PNG')

                # Recalculate insertion size (Must divide by zoom factor)
                new_page = output_doc.new_page(width=pix.width / ZOOM_FACTOR, height=pix.height / ZOOM_FACTOR)
                new_page.insert_image(new_page.rect, stream=img_byte_arr.getvalue())

                self.progress_update.emit(int((i + 1) / total_pages * 100))

            # Save file
            folder, filename = os.path.split(self.input_path)
            name, ext = os.path.splitext(filename)
            output_path = os.path.join(folder, f"{name}_V4_inverted.pdf")

            # deflate=True compresses lossless data streams as much as possible
            output_doc.save(output_path, deflate=True)
            output_doc.close()
            doc.close()

            self.finished.emit(output_path)

        except Exception as e:
            import traceback
            traceback.print_exc()
            self.error.emit(str(e))


class PDFInverterApp(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("PDF Color Inverter Tool")
        self.setGeometry(100, 100, 400, 350)
        self.input_path = None
        self.init_ui()

    def init_ui(self):
        layout = QVBoxLayout()
        layout.setSpacing(15)
        layout.setContentsMargins(25, 25, 25, 25)

        title = QLabel("PDF Color Inverter")
        title.setStyleSheet("font-size: 16px; font-weight: bold;")
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(title)

        self.lbl_file = QLabel("Drag & Drop PDF File Here")
        self.lbl_file.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.lbl_file.setStyleSheet("border: 2px dashed #aaa; border-radius: 8px; padding: 20px; color: #666;")
        layout.addWidget(self.lbl_file)

        btn_select = QPushButton("Select File")
        btn_select.clicked.connect(self.select_file)
        layout.addWidget(btn_select)

        layout.addSpacing(10)

        self.radio_smart = QRadioButton("Smart Invert (B&W Only)")
        self.radio_smart.setChecked(True)
        self.radio_full = QRadioButton("Full Invert")

        layout.addWidget(self.radio_smart)
        layout.addWidget(self.radio_full)

        self.btn_convert = QPushButton("Start Conversion")
        self.btn_convert.setFixedHeight(45)
        self.btn_convert.setEnabled(False)
        self.btn_convert.setStyleSheet(
            "QPushButton { background-color: #007AFF; color: white; border-radius: 6px; font-weight: bold; } QPushButton:disabled { background-color: #ccc; }")
        self.btn_convert.clicked.connect(self.start_conversion)
        layout.addWidget(self.btn_convert)

        self.progress = QProgressBar()
        self.progress.setValue(0)
        self.progress.setTextVisible(False)
        layout.addWidget(self.progress)

        container = QWidget()
        container.setLayout(layout)
        self.setCentralWidget(container)

    def select_file(self):
        file_name, _ = QFileDialog.getOpenFileName(self, "Select PDF", "", "PDF Files (*.pdf)")
        if file_name:
            self.input_path = file_name
            self.lbl_file.setText(os.path.basename(file_name))
            self.btn_convert.setEnabled(True)

    def start_conversion(self):
        if not self.input_path: return
        mode = 'smart' if self.radio_smart.isChecked() else 'full'
        self.btn_convert.setEnabled(False)
        self.btn_convert.setText("Rendering...")
        self.progress.setValue(0)
        self.worker = WorkerThread(self.input_path, mode)
        self.worker.progress_update.connect(lambda val: self.progress.setValue(val))
        self.worker.finished.connect(self.finish)
        self.worker.error.connect(lambda e: QMessageBox.critical(self, "Error", str(e)))
        self.worker.start()

    def finish(self, path):
        self.progress.setValue(100)
        self.btn_convert.setEnabled(True)
        self.btn_convert.setText("Start Conversion")
        msg = QMessageBox(self)
        msg.setText("Finished")
        msg.setInformativeText(f"File saved to: {path}")
        msg.setStandardButtons(QMessageBox.StandardButton.Open | QMessageBox.StandardButton.Ok)
        if msg.exec() == QMessageBox.StandardButton.Open:
            os.system(f"open '{path}'")


if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = PDFInverterApp()
    window.show()
    sys.exit(app.exec())