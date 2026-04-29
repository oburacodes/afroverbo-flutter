import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'courses_screen.dart';
import 'tutor_tab.dart';
import 'profile_tab.dart';
import 'tutor_dashboard_tab.dart';
import 'reports_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final bool isTutor = auth.isAdmin;

    // ── TUTOR: full screen — no bottom nav, tabs are built into TutorDashboardTab
    if (isTutor) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF006B3C),
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              const Text(
                '🌍 Afroverbo',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const Spacer(),
              Text(
                'Hi, ${auth.username ?? ''}!',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.bar_chart, color: Colors.white),
              tooltip: 'Reports',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () async {
                await Provider.of<AuthProvider>(
                  context,
                  listen: false,
                ).logout();
                if (!context.mounted) return;
                Navigator.pushReplacementNamed(context, '/welcome');
              },
            ),
          ],
        ),
        // TutorDashboardTab already has its own 3-tab bar (Bookings, Availability, My Profile)
        body: const TutorDashboardTab(),
      );
    }

    // ── STUDENT: 3-tab bottom nav (Courses, Tutors, Profile)
    final List<Widget> studentTabs = [
      const CoursesScreen(),
      const TutorTab(),
      const ProfileTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF006B3C),
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Text(
              '🌍 Afroverbo',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const Spacer(),
            Text(
              'Hi, ${auth.username ?? ''}!',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await Provider.of<AuthProvider>(context, listen: false).logout();
              if (!context.mounted) return;
              Navigator.pushReplacementNamed(context, '/welcome');
            },
          ),
        ],
      ),
      body: studentTabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: const Color(0xFF006B3C),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Courses'),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_pin),
            label: 'Tutors',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
