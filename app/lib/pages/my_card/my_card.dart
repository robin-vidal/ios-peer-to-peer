import 'package:material_ui/material_ui.dart';
import 'package:p2pchat/pages/scan/scan.dart';
import 'package:p2pchat/utils.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MyCard extends StatelessWidget {
  const MyCard(this.fingerprint, this.qrSize, {super.key});

  final String fingerprint;
  final double qrSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        spacing: 8.0,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Text(
              'My Card',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
          QrImageView(
            data: fingerprint,
            size: qrSize,
            version: QrVersions.auto,
            backgroundColor: Colors.white,
          ),
          Text(
            'Show this code to your contact while you are standing together',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          Text('FINGERPRINT', style: Theme.of(context).textTheme.bodyLarge),
          Container(
            padding: EdgeInsets.only(left: 8.0, right: 8.0),
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.transparent),
              borderRadius: BorderRadius.all(Radius.circular(25)),
              color: Colors.grey.shade700,
            ),
            child: FittedBox(
              fit: BoxFit.fitWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  groupCharacters(
                    fingerprint.substring(0, 16),
                    4,
                  ).toUpperCase(),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          ),
          Text(
            'The first 16 characters of your ID. Read them out loud so your contact can compare.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) {
                    return Padding(
                      padding: EdgeInsets.only(top: 32.0),
                      child: Scaffold(
                        backgroundColor: Colors.black,
                        body: Scan(),
                      ),
                    );
                  },
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              minimumSize: Size.fromHeight(40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Colors.blue,
            ),
            child: Row(
              spacing: 8,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.camera_alt, color: Colors.white),
                Text(
                  'Scan a Contact',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          Text(
            'Your card holds two public keys and nothing else. It is safe to show, photograph or print.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
