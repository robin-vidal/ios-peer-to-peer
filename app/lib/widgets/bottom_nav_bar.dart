import 'package:material_ui/material_ui.dart';

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({
    required this.homeWidget,
    required this.codeWidget,
    required this.settingsWidget,
    super.key,
  });

  final Widget homeWidget;
  final Widget codeWidget;
  final Widget settingsWidget;

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  _BottomNavBarState();

  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> widgetOptions = <Widget>[
      widget.homeWidget,
      widget.codeWidget,
      widget.settingsWidget,
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: widgetOptions.elementAt(_selectedIndex)),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.blueGrey,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code), label: 'My Card'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
      ),
    );
  }
}
