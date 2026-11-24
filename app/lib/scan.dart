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
  String? _scannedFingerprint =
      '11111111111111111111111111111111111111111111111111';
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
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Cancel',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              Text(
                'Scan Contact',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              GestureDetector(
                onTap: () {},
                child: Icon(Icons.flashlight_on),
              ), // TODO Flashlight
            ],
          ),
          MobileScanner(onDetect: _handleBarcode),
          Text(
            'Point at Your Contact\'s Code',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          Text(
            'Both phones need to be in the same room.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            'The camera is only used to read contact codes.\nNothing is stored or uploaded.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),

          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              'Show My Card',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModal(String newFingerprint) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            GestureDetector(
              onTap: _handleCancel,
              child: Text(
                'Cancel',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            Text('New Contact', style: Theme.of(context).textTheme.bodyLarge),
            GestureDetector(
              onTap: _addContact,
              child: Text('Add', style: Theme.of(context).textTheme.bodyLarge),
            ),
          ],
        ),
        TextField(
          keyboardType: TextInputType.text,
          decoration: InputDecoration(hintText: 'Name'),
          onChanged: (value) {
            _nameText = value;
          },
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        Text(
          'Their Fingerprint',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          child: Text(newFingerprint.substring(0, 16)),
        ),
        Text(
          'Check that it matches the code on their screen before you add them.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_scannedFingerprint != null) {
      return SlidingUpPanel(
        body: _buildBackground(),
        panel: _buildModal(_scannedFingerprint!),
        color: Colors.grey,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      );
    } else {
      return _buildBackground();
    }
  }
}
