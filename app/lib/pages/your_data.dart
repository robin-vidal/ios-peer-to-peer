import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:p2pchat/widgets/buttons/primary_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

const consentSharedKey = "HAVE_CONSENT";

class YourData extends StatelessWidget {
  const YourData({super.key});

  void onAgreeClick() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(consentSharedKey, true);
  }

  ListTile generateListTileInfoItem(
    Widget icon,
    Color iconBackgroundColor,
    String title,
    String description,
  ) {
    return ListTile(
      leading: Container(
        decoration: BoxDecoration(
          color: iconBackgroundColor,
          border: Border.all(color: Colors.transparent),
          borderRadius: BorderRadius.circular(15),
        ),
        child: icon,
      ),
      title: Text(title),
      subtitle: Text(description),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Align(
          alignment: AlignmentGeometry.topCenter,
          child: Column(
            children: [
              TextButton.icon(
                onPressed: () {},
                label: Text("Back"),
                icon: Icon(Icons.chevron_left),
              ),
              Text("Your Data"),
              Text(
                "What p2pchat keeps, what it sends, and what it never touches.",
              ),
              ListView(
                children: [
                  generateListTileInfoItem(
                    Icon(Icons.phone_iphone_outlined),
                    Colors.green,
                    'Kept on This iPhone',
                    "Your keys, your contacts and every message, encrypted at rest",
                  ),
                  generateListTileInfoItem(
                    SvgPicture.asset('assets/icons/server.svg'),
                    Colors.blue,
                    'Sent to the Registry',
                    "Your public ID, and an address sealed for each contact. Nothing else.",
                  ),
                  generateListTileInfoItem(
                    Icon(IconData(0xf662)),
                    Colors.grey.shade300,
                    'Never Collected',
                    "No analytics, address book, location or push token.",
                  ),
                ],
              ),
            ],
          ),
        ),

        Align(
          alignment: AlignmentGeometry.bottomCenter,
          child: Column(
            children: [
              PrimaryButton(
                onPressed: onAgreeClick,
                child: Text('Agree and Continue'),
              ),
              Text('Shown once, on first launch.'),
            ],
          ),
        ),
      ],
    );
  }
}
