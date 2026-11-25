import 'package:material_ui/material_ui.dart';
import 'package:p2pchat/app_identity.dart';
import 'package:p2pchat/pages/scan/scan.dart';
import 'package:p2pchat/utils.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class MyCard extends StatelessWidget {
  const MyCard(this.qrSize, this.identityLoader, {super.key});

  final Future<String> Function()? identityLoader;
  final double qrSize;

  @override
  Widget build(BuildContext context) {
    final Future<String> Function() idFunc =
        (identityLoader ??
        () async {
          final identity = await createAppIdentity();
          return identity.id;
        });

    return FutureBuilder(
      future: idFunc(),
      builder: (context, snapshot) {
        return Center(
          child: Column(
            spacing: 8.0,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () {
                    if (snapshot.hasData) {
                      SharePlus.instance.share(
                        ShareParams(
                          text: snapshot.data!,
                          title: 'Share your ID',
                        ),
                      );
                    }
                  },
                  child: Icon(
                    Icons.ios_share_outlined,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topLeft,
                child: Text(
                  'My Card',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
              snapshot.hasData
                  ? QrImageView(
                      data: snapshot.data!,
                      size: qrSize,
                      version: QrVersions.auto,
                      backgroundColor: Colors.white,
                    )
                  : Text(
                      'Loading QR Code...',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
              Text(
                'Show this code to your contact while you are standing together',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'FINGERPRINT',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Container(
                padding: EdgeInsets.only(left: 8.0, right: 8.0),
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.transparent),
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  color: Colors.grey[850],
                ),
                child: FittedBox(
                  fit: BoxFit.fitWidth,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: snapshot.hasData
                        ? Text(
                            groupCharacters(
                              snapshot.data!.substring(0, 16),
                              4,
                            ).toUpperCase(),
                            style: Theme.of(context).textTheme.bodyLarge,
                          )
                        : Text('Loadin fingerprint...'),
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
                        return SafeArea(
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
      },
    );
  }
}
