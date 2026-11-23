import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

class Scan extends StatefulWidget {
  const Scan({super.key});

  @override
  State<StatefulWidget> createState() => _ScanState();
}

class _ScanState extends State<Scan> {
  String? _scannedFingerprint;

  void _handleBarcode(BarcodeCapture barcodes) {
    if (mounted) {
      setState(() {
        final barcode = barcodes.barcodes.firstOrNull;
        if (barcode != null) {
          final code = barcode.rawValue;
          if (code != null) {
            // TODO Verify key validity
            _scannedFingerprint = code;
          }
        }
      });
    }
  }

  Widget _buildBackground() {
    return Center(
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                },
                child: Text('Cancel'),
              ),
              Text('Scan Contact'),
              GestureDetector(onTap: () {}, child: Text('FlashLight')),
            ],
          ),
          MobileScanner(onDetect: _handleBarcode),
          Text('Point at Your Contact\'s Code'),
          Text('Both phones need to be in the same room.'),
          Text(
            'The camera is only used to read contact codes. Nothing is stored or uploaded.',
          ),

          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Show My Card'),
          ),
        ],
      ),
    );
  }

  Widget _buildModal(String newFingerprint) {
    return Column(
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () {
                _scannedFingerprint = null;
              },
              child: Text('Cancel'),
            ),
            Text('New Contact'),
            GestureDetector(
              onTap: () {}, //TODO Implement add new contacts
              child: Text('Add'),
            ),
          ],
        ),
        TextFormField(
          keyboardType: TextInputType.text,
          decoration: InputDecoration(hintText: 'Name'),
        ),
        Text('Their Fingerprint'),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          child: Text(newFingerprint.substring(0, 16)),
        ),
        Text(
          'Check that it matches the code on their screen before you add them.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SlidingUpPanel(
      body: _buildBackground(),
      panel: _scannedFingerprint == null
          ? _buildModal(_scannedFingerprint!)
          : null,
    );
  }
}
