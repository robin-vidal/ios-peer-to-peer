import 'package:material_ui/material_ui.dart';
import 'package:p2pchat/scan.dart';
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
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            child: FittedBox(
              fit: BoxFit.fitWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  fingerprint.substring(0, 16),
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
                    return Scaffold(
                      backgroundColor: Colors.black,
                      body: Scan(),
                    );
                  },
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Colors.blue,
            ),
            child: Center(
              child: Row(
                children: [
                  Icon(Icons.camera),
                  Text(
                    'Scan a Contact',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
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
