import 'package:flutter/material.dart';
import '../../../utils/theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../data/services/auth_service.dart';

class AdminLayout extends StatefulWidget {
  final String title;
  final Widget child;

  const AdminLayout({super.key, required this.title, required this.child});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  bool isCollapsed = false;
  final AuthService _authService = AuthService();
  String _email = 'admin@email.com';

  String get selectedMenuItem {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    switch (currentRoute) {
      case AppRoutes.adminDashboard:
        return "dashboard";
      case AppRoutes.employeeManagement:
        return "employee";
      case AppRoutes.officeManagement:
        return "office";
      case AppRoutes.scheduleManagement:
        return "schedule";
      case AppRoutes.permissionManagement:
        return "permission";
      case AppRoutes.adminReportScreen:
        return "report";
      case AppRoutes.divisionManagement:
        return "division";
      default:
        return "dashboard"; // Default to dashboard
    }
  }

  @override
  void initState() {
    super.initState();
    _loadEmail();
  }

  Future<void> _loadEmail() async {
    final user = _authService.currentUser;
    if (user == null) return;
    final admin = await _authService.fetchAdminByEmail(user.email ?? '');
    if (admin != null) {
      setState(() {
        _email = (admin['email'] ?? user.email ?? _email).toString();
      });
    } else {
      setState(() {
        _email = user.email ?? _email;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // ======================================================
          // SIDEBAR (COLLAPSIBLE)
          // ======================================================
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: isCollapsed ? 70 : 250,
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: isCollapsed
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                // 🚀 COLLAPSE BUTTON DI ATAS LOGO - MULAI 🚀
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 8, left: 8),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          isCollapsed
                              ? Icons.keyboard_arrow_right
                              : Icons.keyboard_arrow_left,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        onPressed: () {
                          setState(() {
                            isCollapsed = !isCollapsed;
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.only(
                    top: 2,
                    bottom: isCollapsed ? 2 : 10,
                    left: 8,
                    right: 8,
                  ),
                  child: Container(
                    height: isCollapsed ? 40 : 170,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/clockon.png',
                        fit: BoxFit.contain,
                        width: isCollapsed ? 30 : 170,
                        height: isCollapsed ? 30 : 150,
                      ),
                    ),
                  ),
                ),

                // 🚀 LOGO BESAR - SELESAI 🚀
                if (!isCollapsed)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "Menu Admin",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),

                const SizedBox(height: 8),
                const Divider(color: Colors.grey, height: 1),

                // ===== MENU ITEMS =====
                _menuItem(
                  icon: Icons.dashboard,
                  label: "Beranda",
                  collapsed: isCollapsed,
                  isSelected: selectedMenuItem == "dashboard",
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.adminDashboard);
                  },
                ),

                _menuItem(
                  icon: Icons.people,
                  label: "Karyawan",
                  collapsed: isCollapsed,
                  isSelected: selectedMenuItem == "employee",
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.employeeManagement);
                  },
                ),

                _menuItem(
                  icon: Icons.apartment,
                  label: "Lokasi Kantor",
                  collapsed: isCollapsed,
                  isSelected: selectedMenuItem == "office",
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.officeManagement);
                  },
                ),

                _menuItem(
                  icon: Icons.schedule,
                  label: "Kelola Jadwal",
                  collapsed: isCollapsed,
                  isSelected: selectedMenuItem == "schedule",
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.scheduleManagement);
                  },
                ),

                _menuItem(
                  icon: Icons.check_circle,
                  label: "Perizinan",
                  collapsed: isCollapsed,
                  isSelected: selectedMenuItem == "permission",
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.permissionManagement,
                    );
                  },
                ),

                _menuItem(
                  icon: Icons.bar_chart,
                  label: "Riwayat Kehadiran",
                  collapsed: isCollapsed,
                  isSelected: selectedMenuItem == "report",
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.adminReportScreen);
                  },
                ),

                _menuItem(
                  icon: Icons.domain,
                  label: "Divisi",
                  collapsed: isCollapsed,
                  isSelected: selectedMenuItem == "division",
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.divisionManagement);
                  },
                ),

                const Spacer(),

                // ======================================================
                // LOGOUT BUTTON
                // ======================================================
                _menuItem(
                  icon: Icons.logout,
                  label: "Logout",
                  collapsed: isCollapsed,
                  isSelected: selectedMenuItem == "logout",
                  onTap: () => _showLogoutConfirmation(),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),

          // ======================================================
          // CONTENT AREA (TIDAK DIUBAH)
          // ======================================================
          Expanded(
            child: Scaffold(
              extendBodyBehindAppBar: true,
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(80),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withOpacity(0.95),
                        AppColors.primary,
                        AppColors.secondary.withOpacity(0.9),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(25),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    toolbarHeight: 80,
                    automaticallyImplyLeading: false,
                    title: Text(
                      widget.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                    actions: [
                      Container(
                        margin: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.person, size: 24),
                          tooltip: 'Profil',
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.adminProfile,
                            );
                          },
                          splashRadius: 24,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
              body: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xfff5f6fa).withOpacity(0.8),
                      const Color(0xfff5f6fa),
                      Colors.white,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    child: Column(
                      children: [
                        // Welcome card with modern design
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white,
                                Colors.white.withOpacity(0.9),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.05),
                                blurRadius: 40,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.primary,
                                          AppColors.secondary,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withOpacity(
                                            0.3,
                                          ),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.waving_hand,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Halo Admin, $_email 👋',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryDark,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Semangat bekerja hari ini',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Main content card
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: widget.child,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool collapsed,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: AppColors.primary.withOpacity(0.3), width: 1)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Row(
            children: [
              const SizedBox(width: 4),
              Icon(
                icon,
                color: isSelected ? AppColors.primary : Colors.grey[600],
                size: 24,
              ),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : Colors.grey[600],
                    fontSize: 15,
                    fontWeight: isSelected
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi Logout'),
          content: const Text('Apakah Anda yakin ingin logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }
}
