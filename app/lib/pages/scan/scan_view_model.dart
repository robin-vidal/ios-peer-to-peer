import 'package:flutter/widgets.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanViewModel extends ChangeNotifier {
  String? _scannedFingerprint;
  String _nameText = '';

  String? get scannedFingerprint => _scannedFingerprint;
  String get nameText => _nameText;

  void handleBarcode(BarcodeCapture barcodes) {
    final barcode = barcodes.barcodes.firstOrNull;
    if (barcode != null) {
      final code = barcode.rawValue;
      if (code != null && code.length == 130) {
        _scannedFingerprint = code;
        notifyListeners();
      } else {
        Fluttertoast.showToast(
          msg: 'The code is not a p2pchat key.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          fontSize: 16.0,
        );
      }
    }
  }

  void handleCancel() {
    _scannedFingerprint = null;
    _nameText = '';

    notifyListeners();
  }

  void onNameTextChange(String newName) {
    _nameText = newName;
  }
}
