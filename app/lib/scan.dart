import 'package:fluttertoast/fluttertoast.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import './data/model/contact.dart';

class Scan extends StatefulWidget {
  const Scan({super.key});

  @override
  State<StatefulWidget> createState() => _ScanState();
}

class _ScanState extends State<Scan> {
  String? _scannedFingerprint;
  String _nameText = '';

  void _handleBarcode(BarcodeCapture barcodes) {
    if (mounted) {
      setState(() {
        final barcode = barcodes.barcodes.firstOrNull;
        if (barcode != null) {
          final code = barcode.rawValue;
          if (code != null) {
            _scannedFingerprint = code;
          }
        }
      });
    }
  }

  void _handleCancel() {
    _scannedFingerprint = null;
    _nameText = '';
  }

  void _addContact() async {
    if (_scannedFingerprint == null) {
      return;
    }

    if (await Contact.hasFingerprint(_scannedFingerprint!)) {
      Fluttertoast.showToast(
        msg: 'This contact is already in contacts.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        fontSize: 16.0,
      );
    } else {
      final newContact = Contact(_nameText, _scannedFingerprint!);
      await newContact.insert();

      Fluttertoast.showToast(
        msg: 'Contact $_nameText added.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        fontSize: 16.0,
      );

      if (context.mounted) {
        Navigator.of(context).pop();
      }
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
              GestureDetector(
                onTap: () {},
                child: Text('FlashLight'),
              ), // TODO Flashlight
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
            GestureDetector(onTap: _handleCancel, child: Text('Cancel')),
            Text('New Contact'),
            GestureDetector(onTap: _addContact, child: Text('Add')),
          ],
        ),
        TextField(
          keyboardType: TextInputType.text,
          decoration: InputDecoration(hintText: 'Name'),
          onChanged: (value) {
            _nameText = value;
          },
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
