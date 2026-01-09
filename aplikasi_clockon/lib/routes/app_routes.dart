import 'package:flutter/material.dart';
import '../main_screens/admin/admin_layout.dart';

// Splash & Auth
import '../main_screens/splash_screen/splash_screen.dart';
import '../main_screens/autentikasi/admin_login_screen.dart';
import '../main_screens/autentikasi/admin_register_screen.dart';
import '../main_screens/autentikasi/employee_login_screen.dart';

// Main Screens - Admin
import '../main_screens/admin/admin_dashboard.dart';
import '../main_screens/admin/admin_management_screen.dart';
import '../main_screens/admin/admin_office_management_screen.dart';
import '../main_screens/admin/admin_schedule_management_screen.dart';
import '../main_screens/admin/admin_permission_management.dart';
import '../main_screens/admin/admin_report_screen.dart';
import '../main_screens/admin/admin_divisi_management.dart';
import '../main_screens/admin/admin_profile_screen.dart';

// Main Screens - Employee
import '../main_screens/karyawan/employee_dashboard.dart';
import '../main_screens/karyawan/employee_attendance_screen.dart';
import '../main_screens/karyawan/employee_schedule_viewer.dart';
import '../main_screens/karyawan/employee_profile_screen.dart';
import '../main_screens/karyawan/employee_permission_history.dart';
import '../main_screens/karyawan/employee_layout.dart';

class AppRoutes {
  // Auth Route Names
  static const String splash = '/splash';
  static const String login = '/login';
  static const String adminLoginScreen = '/admin-login';
  static const String adminRegister = '/admin-register';
  static const String employeeLoginScreen = '/employee-login';

  // Admin Routes
  static const String adminDashboard = '/admin-dashboard';
  static const String employeeManagement = '/employee-management';
  static const String officeManagement = '/office-management';
  static const String scheduleManagement = '/schedule-management';
  static const String permissionManagement = '/permission-management';
  static const String adminReportScreen = '/admin-report-screen';
  static const String divisionManagement = '/division-management';
  static const String adminProfile = '/admin-profile';

  // Employee Routes
  static const String employeeDashboard = '/employee-dashboard';
  static const String attendance = '/attendance';
  static const String attendanceCalendar = '/attendance-calendar';
  static const String employeeSchedule = '/employee-schedule';
  static const String employeeProfile = '/employee-profile';
  static const String employeePermissionHistory =
      '/employee-permission-history';

  // Routing Map
  static Map<String, WidgetBuilder> get routes => {
    splash: (_) => const SplashScreen(),
    login: (_) => const EmployeeLoginScreen(),
    adminRegister: (_) => const AdminRegisterScreen(),
    adminLoginScreen: (_) => const AdminLoginScreen(),

    // Admin
    adminDashboard: (_) =>
        AdminLayout(title: "Beranda", child: AdminDashboard()),

    employeeManagement: (_) =>
        AdminLayout(title: "Karyawan", child: EmployeeManagementScreen()),

    officeManagement: (_) =>
        AdminLayout(title: "Lokasi Kantor", child: OfficeManagementScreen()),

    scheduleManagement: (_) => AdminLayout(
      title: "Kelola Jadwal",
      child: const AdminScheduleManagementScreen(),
    ),

    permissionManagement: (_) => AdminLayout(
      title: "Perizinan",
      child: AdminPermissionManagementScreen(),
    ),

    adminReportScreen: (_) => AdminLayout(
      title: "Riwayat Kehadiran",
      child: const AdminReportScreen(),
    ),

    divisionManagement: (_) =>
        AdminLayout(title: "Divisi", child: DivisionManagementScreen()),
    adminProfile: (_) =>
        AdminLayout(title: "Profil Admin", child: const AdminProfileScreen()),

    // Employee
    employeeDashboard: (_) =>
        EmployeeLayout(title: "Beranda", child: EmployeeDashboardScreen()),

    attendance: (_) =>
        EmployeeLayout(title: "Absen", child: AttendanceScreen()),

    employeeSchedule: (_) =>
        EmployeeLayout(title: "Aktivitas", child: EmployeeScheduleScreen()),

    employeeProfile: (_) =>
        EmployeeLayout(title: "Profil", child: const EmployeeProfileScreen()),

    employeePermissionHistory: (_) => EmployeeLayout(
      title: "Perizinan",
      child: const EmployeePermissionHistory(),
    ),
  };
}
