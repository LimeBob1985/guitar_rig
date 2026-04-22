import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; // Importato per gestire l'anima dell'app
import 'package:guitar_rig/ui/pages/mixer_page.dart';

import 'ui/pages/mixer_page.dart';
import 'ui/pages/pedal_page.dart';
import 'ui/pages/tuner_page.dart';
import 'ui/pages/presets_page.dart';
import 'ui/theme/app_colors.dart';
import 'logic/app_provider.dart'; // Assicurati di aver creato questo file

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Blocca l'orientamento in verticale per iPhone
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  
  runApp(
    // Avvolgiamo l'app nel Provider così ogni pagina può accedere ai valori
    ChangeNotifierProvider(
      create: (context) => AppProvider(),
      child: const GuitarRigApp(),
    ),
  );
}

class GuitarRigApp extends StatelessWidget {
  const GuitarRigApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guitar Rig',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.background,
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'MyriadPro'),
      ),
      home: const MainNavigationHolder(),
    );
  }
}

class MainNavigationHolder extends StatefulWidget {
  const MainNavigationHolder({super.key});

  @override
  State<MainNavigationHolder> createState() => _MainNavigationHolderState();
}

class _MainNavigationHolderState extends State<MainNavigationHolder> {
  int _selectedIndex = 0;

  // Lista delle pagine
  final List<Widget> _pages = [
    const MixerPage(),
    const PedalPage(),
    const TunerPage(),
    const PresetsPage(),
  ];

  Widget _buildIcon(String assetName, int index) {
    return Image.asset(
      'assets/images/$assetName',
      width: 18, 
      height: 18,
      color: _selectedIndex == index ? Colors.red : const Color(0xFFD3D3D3),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Usiamo un IndexedStack invece di una lista semplice per non 
      // ricaricare le pagine ogni volta che cambiamo tab
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: const Color(0xFF1A1A1A),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF1A1A1A),
          selectedItemColor: Colors.red,
          unselectedItemColor: const Color(0xFFD3D3D3),
          selectedFontSize: 8,
          unselectedFontSize: 8,
          selectedLabelStyle: const TextStyle(
            fontFamily: 'MyriadPro', 
            fontSize: 8, 
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'MyriadPro', 
            fontSize: 8,
            letterSpacing: 0.5,
          ),
          items: [
            BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _buildIcon('mixer_icon.png', 0),
              ),
              label: 'MIXER',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _buildIcon('pedal_icon.png', 1),
              ),
              label: 'PEDAL',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _buildIcon('tuner_icon.png', 2),
              ),
              label: 'TUNER',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _buildIcon('preset_icon.png', 3),
              ),
              label: 'PRESET',
            ),
          ],
        ),
      ),
    );
  }
}