import 'package:material_ui/material_ui.dart';
import 'package:p2pchat/main.dart';
import 'package:p2pchat/pages/your_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<StatefulWidget> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  void onInit(BuildContext context) async {
    final sharedPref = await SharedPreferences.getInstance();

    if (context.mounted) {
      if (sharedPref.getBool(consentSharedKey) ?? false) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MyApp()),
        );
      } else {
        final navigator = Navigator.of(context);
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (context) => YourData(
              onCensentGiven: () {
                navigator.pop();
              },
            ),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    onInit(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Align(child: Image.asset('assets/icons/logo.png')),
            const Align(
              alignment: Alignment.bottomCenter,
              child: CircularProgressIndicator(),
            ),
          ],
        ),
      ),
    );
  }
}
