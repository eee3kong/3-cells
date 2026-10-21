import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import 'screens/dashboard_screen.dart';
import 'screens/map_screen.dart';
import 'screens/log_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyAK-e-uORTohnpfvFM0CERKos_4mq8E8rw",
      appId: "1:919361982067:web:7f5840906f47cdcb7d6406",
      messagingSenderId: "919361982067",
      projectId: "buildwatch-6040a",
      databaseURL: "https://buildwatch-6040a-default-rtdb.firebaseio.com",
      storageBucket: "buildwatch-6040a.firebasestorage.app",
      measurementId: "G-D7S6T81SVS",
    ),
  );

  runApp(const BuildWatchApp());
}

class BuildWatchApp extends StatelessWidget {
  const BuildWatchApp({super.key});

  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BuildWatch — Elmina Green 4',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFFF8F1), 
        primaryColor: const Color(0xFFFF6B00), 
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF6B00)),
        useMaterial3: true,
        fontFamily: 'Roboto', 
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  // Set initial index to 1 so the app opens directly to the Home (Map) page
  int _currentIndex = 1;

  // Reordered: Overview (0), Home (1), Log (2)
  final List<Widget> _screens = [
    const DashboardScreen(), 
    const MapScreen(),       
    const LogScreen(),       
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _screens[_currentIndex],
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildCustomNavBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomNavBar() {
    return Container(
      height: 75,
      decoration: const BoxDecoration(
        color: Color(0xFFFF6B00),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(0, Icons.speed, 'Overview'),     // Left
          _buildNavItem(1, Icons.location_on, 'Home'),   // Center
          _buildNavItem(2, Icons.receipt_long, 'Log'),   // Right
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 80,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: isSelected ? 20 : 0), 
                if (!isSelected) Icon(icon, color: Colors.white, size: 24),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            if (isSelected)
              Positioned(
                top: -24,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))
                    ],
                  ),
                  child: Icon(icon, color: const Color(0xFFFF6B00), size: 28),
                ),
              ),
          ],
        ),
      ),
    );
  }
}