import 'package:material_ui/material_ui.dart';
import 'package:p2pchat/app_identity.dart';
import 'package:p2pchat/pages/scan/scan.dart';
import 'package:p2pchat/theme/ios27/ios27_colors.dart';
import 'package:p2pchat/theme/ios27/ios27_typography.dart';
import 'package:p2pchat/utils.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:registry_client/registry_client.dart';
import 'package:share_plus/share_plus.dart';

class MyCard extends StatelessWidget {
  const MyCard(this.qrSize, {super.key});

  final double qrSize;

  @override
  Widget build(BuildContext context) {
    Future<Identity> idFunc() async {
      final identity = await createAppIdentity();
      return identity;
    }

    return FutureBuilder(
      future: idFunc(),
      builder: (context, snapshot) {
        return Center(
          child: Column(
            spacing: 16.0,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () {
                    if (snapshot.hasData) {
                      SharePlus.instance.share(
                        ShareParams(
                          text: snapshot.data!.card.toDB(),
                          title: 'Share your ID',
                        ),
                      );
                    }
                  },
                  child: Icon(
                    Icons.ios_share_outlined,
                    color: IOS27Colors.blue,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topLeft,
                child: Text(
                  'My Card',
                  style: IOS27Typography.largeTitleEmphasized,
                ),
              ),
              snapshot.hasData
                  ? QrImageView(
                      data: snapshot.data!.card.toDB(),
                      size: qrSize,
                      version: QrVersions.auto,
                      backgroundColor: IOS27Colors.grayWhite,
                    )
                  : Text('Loading QR Code...', style: IOS27Typography.body),
              Text(
                'Show this code to your contact while you are standing together',
                style: IOS27Typography.body.copyWith(
                  color: IOS27Colors.darkLabelSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'FINGERPRINT',
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
                child: FittedBox(
                  fit: BoxFit.fitWidth,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: snapshot.hasData
                        ? Text(
                            groupCharacters(
                              snapshot.data!.id.substring(0, 16),
                              4,
                            ).toUpperCase(),
                            style: IOS27Typography.body,
                          )
                        : Text('Loading fingerprint...'),
                  ),
                ),
              ),
              Text(
                'The first 16 characters of your ID. Read them out loud so your contact can compare.',
                style: IOS27Typography.body.copyWith(
                  color: IOS27Colors.darkLabelSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) {
                        return SafeArea(child: Scaffold(body: Scan()));
                      },
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.fromHeight(40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Row(
                  spacing: 8,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt, color: IOS27Colors.grayWhite),
                    Text(
                      'Scan a Contact',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              Text(
                'Your card holds two public keys and nothing else. It is safe to show, photograph or print.',
                style: IOS27Typography.body.copyWith(
                  color: IOS27Colors.darkLabelSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}
