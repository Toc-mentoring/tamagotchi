import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme.dart';
import 'screens/home_screen.dart';
import 'screens/walk_record_screen.dart';

void main() => runApp(const PocketWalkApp());

class PocketWalkApp extends StatelessWidget {
  const PocketWalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.bg,
        colorSchemeSeed: AppColors.primary,
        textTheme: GoogleFonts.notoSansKrTextTheme(),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _screens = const [
    HomeScreen(),
    ComingSoon(title: '상점'),
    ComingSoon(title: '친구'),
    ComingSoon(title: '도감'),
    WalkRecordScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _screens[_index]),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: NavigationBar(
          height: 72,
          backgroundColor: Colors.white,
          indicatorColor: AppColors.primarySoft,
          indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 10,
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w400,
              color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.sub,
            ),
          ),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined, color: AppColors.sub), selectedIcon: Icon(Icons.home_outlined, color: AppColors.primary), label: '홈'),
            NavigationDestination(icon: Icon(Icons.shopping_bag_outlined, color: AppColors.sub), selectedIcon: Icon(Icons.shopping_bag_outlined, color: AppColors.primary), label: '상점'),
            NavigationDestination(icon: Icon(Icons.people_outline, color: AppColors.sub), selectedIcon: Icon(Icons.people_outline, color: AppColors.primary), label: '친구'),
            NavigationDestination(icon: Icon(Icons.menu_book_outlined, color: AppColors.sub), selectedIcon: Icon(Icons.menu_book_outlined, color: AppColors.primary), label: '도감'),
            NavigationDestination(icon: Icon(Icons.bar_chart, color: AppColors.sub), selectedIcon: Icon(Icons.bar_chart, color: AppColors.primary), label: '기록'),
          ],
        ),
      ),
    );
  }
}

class ComingSoon extends StatelessWidget {
  const ComingSoon({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('$title · 준비 중', style: AppText.caption));
  }
}