import 'dart:async';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:p2pchat/pages/scan/scan_view_model.dart';
import 'package:p2pchat/utils.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../../data/model/contact.dart';

class Scan extends StatefulWidget {
  const Scan({super.key});

  @override
  State<StatefulWidget> createState() => _ScanState();
}

class _ScanState extends State<Scan> {
  final ScanViewModel scanViewModel = ScanViewModel();
  final MobileScannerController controller = MobileScannerController();

  @override
  void initState() {
    super.initState();
    unawaited(controller.start());
  }

  void _addContact() async {
    if (scanViewModel.scannedFingerprint == null) {
      return;
    }

    if (await Contact.hasFingerprint(scanViewModel.scannedFingerprint!)) {
      Fluttertoast.showToast(
        msg: 'This contact is already in contacts.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        fontSize: 16.0,
      );
    } else {
      final newContact = Contact(
        scanViewModel.nameText,
        scanViewModel.scannedFingerprint!,
      );
      await newContact.insert();

      Fluttertoast.showToast(
        msg: 'Contact ${scanViewModel.nameText} added.',
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
    final scanWindow = Rect.fromCenter(
      center: MediaQuery.sizeOf(context).center(const Offset(0, -50)),
      width: 200,
      height: 200,
    );

    return Center(
      child: Stack(
        children: [
          scanViewModel.scannedFingerprint == null
              ? Stack(
                  children: [
                    MobileScanner(
                      controller: controller,
                      onDetect: scanViewModel.handleBarcode,
                      scanWindow: scanWindow,
                      fit: BoxFit.contain,
                    ),
                    ScanWindowOverlay(
                      controller: controller,
                      scanWindow: scanWindow,
                      borderRadius: BorderRadius.circular(25),
                      borderStrokeCap: StrokeCap.round,
                      borderStrokeJoin: StrokeJoin.bevel,
                      borderStyle: PaintingStyle.stroke,
                    ),
                  ],
                )
              : Placeholder(),
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    onTap: () {
                      controller.toggleTorch();
                    },
                    child: FittedBox(
                      child: Icon(Icons.flashlight_on, color: Colors.grey),
                    ),
                  ),
                ],
              ),

              Column(
                children: [
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
                    textAlign: TextAlign.center,
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModal(String newFingerprint) {
    return Padding(
      padding: EdgeInsets.only(left: 8.0, right: 8.0),
      child: Column(
        spacing: 16,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              GestureDetector(
                onTap: scanViewModel.handleCancel,
                child: Text(
                  'Cancel',
                  style: Theme.of(context).textTheme.bodyLarge!
                      .copyWith(color: Colors.blueAccent),
                ),
              ),
              Text('New Contact', style: Theme.of(context).textTheme.bodyLarge),
              GestureDetector(
                onTap: _addContact,
                child: Text(
                  'Add',
                  style: Theme.of(context).textTheme.bodyLarge!
                      .copyWith(color: Colors.blueAccent),
                ),
              ),
            ],
          ),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.transparent),
              borderRadius: BorderRadius.circular(25),
              color: Colors.grey.shade700,
            ),
            child: TextField(
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                label: Text(
                  'Name',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              onChanged: scanViewModel.onNameTextChange,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          Column(
            children: [
              Text(
                'THEIR FINGERPRINT',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Container(
                padding: EdgeInsets.only(left: 8.0, right: 8.0),
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.transparent),
                  borderRadius: BorderRadius.all(Radius.circular(25)),
                  color: Colors.grey.shade700,
                ),
                child: Text(
                  spaceText(newFingerprint.substring(0, 16), 4).toUpperCase(),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
          Text(
            'Check that it matches the code on their screen before you add them.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: scanViewModel,
      builder: (context, child) {
        final Widget widget;

        if (scanViewModel.scannedFingerprint != null) {
          widget = SlidingUpPanel(
            body: _buildBackground(),
            panel: _buildModal(scanViewModel.scannedFingerprint!),
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          );
        } else {
          widget = _buildBackground();
        }

        return widget;
      },
    );
  }
}
