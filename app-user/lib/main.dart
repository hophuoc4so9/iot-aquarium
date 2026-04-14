import 'package:flutter/material.dart';
import 'screens/pond_management_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/camera_diagnosis_screen.dart';
import 'screens/fish_wiki_screen.dart';
import 'screens/account_screen.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartAquariumApp());
}

class SmartAquariumApp extends StatelessWidget {
  const SmartAquariumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Aquarium',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
      ),
      home: const LoginScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    PondManagementScreen(),  // Trang 1: Quản lý ao
    ChatScreen(),            // Trang 2: Tư vấn
    CameraDiagnosisScreen(), // Trang 3: Camera / dự đoán bệnh
    FishWikiScreen(),        // Trang 4: Wiki cá
    AccountScreen(),         // Trang 5: Tài khoản
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _pages[_selectedIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded), label: "Quản lý ao"),
          BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_rounded), label: "Tư vấn"),
          BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt_rounded), label: "Camera"),
          BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_rounded), label: "Wiki cá"),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded), label: "Tài khoản"),
        ],
      ),
    );
  }
}
