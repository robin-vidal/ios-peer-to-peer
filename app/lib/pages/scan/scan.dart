import 'dart:async';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:p2pchat/pages/scan/scan_view_model.dart';
import 'package:p2pchat/theme/ios27/ios27_colors.dart';
import 'package:p2pchat/theme/ios27/ios27_typography.dart';
import 'package:p2pchat/utils.dart';
import 'package:registry_client/registry_client.dart';
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

  void _addContact(BuildContext context) async {
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
              Stack(
                children: [
                  Align(
                    alignment: AlignmentGeometry.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: Theme.of(context).textButtonTheme.style!.copyWith(
                        foregroundColor: WidgetStateColor.resolveWith(
                          (states) => IOS27Colors.grayWhite,
                        ),
                      ),
                      child: Text('Cancel'),
                    ),
                  ),
                  Align(
                    alignment: AlignmentGeometry.center,
                    child: Text(
                      'Scan Contact',
                      style: IOS27Typography.title2Emphasized,
                    ),
                  ),
                  Align(
                    alignment: AlignmentGeometry.centerRight,
                    child: TextButton.icon(
                      label: Text(''),
                      onPressed: () {
                        controller.toggleTorch();
                      },
                      icon: Icon(Icons.flashlight_on, color: IOS27Colors.gray),
                    ),
                  ),
                ],
              ),

              Column(
                spacing: 8.0,
                children: [
                  Text(
                    'Point at Your Contact\'s Code',
                    style: IOS27Typography.body,
                  ),
                  Text(
                    'Both phones need to be in the same room.',
                    style: IOS27Typography.body.copyWith(
                      color: IOS27Colors.darkLabelSecondary,
                    ),
                  ),
                  Text(
                    'The camera is only used to read contact codes.\nNothing is stored or uploaded.',
                    style: IOS27Typography.body.copyWith(
                      color: IOS27Colors.darkLabelSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: Theme.of(context).elevatedButtonTheme.style!
                          .copyWith(
                            backgroundColor: WidgetStateColor.resolveWith(
                              (states) => IOS27Colors.darkFillSecondary,
                            ),
                          ),
                      child: Text('Show My Card', style: IOS27Typography.body),
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
    final newContactCart = ContactCard.fromDB(newFingerprint);
    return Padding(
      padding: EdgeInsets.only(left: 8.0, right: 8.0),
      child: Column(
        spacing: 16,
        children: [
          Stack(
            children: [
              Align(
                alignment: AlignmentGeometry.centerLeft,
                child: TextButton(
                  onPressed: scanViewModel.handleCancel,
                  child: Text('Cancel'),
                ),
              ),
              Align(
                alignment: AlignmentGeometry.center,
                child: Text('New Contact', style: IOS27Typography.body),
              ),
              Align(
                alignment: AlignmentGeometry.centerRight,
                child: TextButton(
                  onPressed: () {
                    _addContact(context);
                  },
                  child: Text('Add', style: IOS27Typography.body),
                ),
              ),
            ],
          ),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.transparent),
              borderRadius: BorderRadius.circular(25),
              color: IOS27Colors.darkFillPrimary,
            ),
            child: TextField(
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                label: Text('Name', style: IOS27Typography.body),
              ),
              onChanged: scanViewModel.onNameTextChange,
              // style: IOS27Typography.body,
            ),
          ),
          Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'THEIR FINGERPRINT',
                  style: IOS27Typography.body.copyWith(
                    color: IOS27Colors.darkLabelSecondary,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.only(left: 8.0, right: 8.0),
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.transparent),
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  color: IOS27Colors.darkFillPrimary,
                ),
                child: Text(
                  groupCharacters(
                    newContactCart.id.substring(0, 16),
                    4,
                  ).toUpperCase(),
                  style: IOS27Typography.body.copyWith(fontSize: 28),
                ),
              ),
            ],
          ),
          Text(
            'Check that it matches the code on their screen before you add them.',
            style: IOS27Typography.body.copyWith(
              color: IOS27Colors.darkLabelSecondary,
            ),
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
            color: IOS27Colors.darkBackgroundGroupedSecondary,
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
