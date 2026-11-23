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
        children: [
          Text('My Card'),
          QrImageView(
            data: fingerprint,
            size: qrSize,
            version: QrVersions.auto,
          ),
          Text(
            'Show this code to your contact while you are standing together',
          ),
          Text('FINGERPRINT'),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            child: Text(fingerprint.substring(0, 16)),
          ),
          Text(
            'The first 16 characters of your ID. Read them out loud so your contact can compare.',
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (context) => const Scan()),
              );
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Center(
              child: Row(
                children: [
                  Image(image: AssetImage('assets/camera_icon.png')),
                  Text('Scan a Contact'),
                ],
              ),
            ),
          ),
          Text(
            'Your card holds two public keys and nothing else. It is safe to show, photograph or print.',
          ),
        ],
      ),
    );
  }
}
