import 'dart:js_interop';

import 'package:mobile_scanner/mobile_scanner.dart';

@JS('window.BarcodeDetector')
external JSAny? get _nativeDetector;

/// Native detection where available, an origin-local pinned decoder elsewhere.
/// Frames stay on the device; scanning never needs a third-party CDN.
void configureQrScanner() {
  MobileScannerPlatform.instance.setWebBarcodeReader(
    _nativeDetector != null
        ? WebBarcodeReader.barcodeDetector
        : WebBarcodeReader.zxingJs,
  );
  MobileScannerPlatform.instance.setBarcodeLibraryScriptUrl(
    Uri.base.resolve('/scanner/zxing-0.23.0.min.js').toString(),
  );
}
