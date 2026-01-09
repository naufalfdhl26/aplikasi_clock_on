import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/theme/app_theme.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/attendance_service.dart';
import '../../data/services/employee_service.dart';
import '../../data/models/employee_model.dart';
import '../../data/models/attendance_model.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AuthService _auth = AuthService();
  final AttendanceService _attendanceService = AttendanceService();
  final EmployeeService _employeeService = EmployeeService();

  bool _isLoading = true;
  String? _companyName;
  int _totalEmployees = 0;
  int _hadirCount = 0;
  int _izinCount = 0;
  int _cutiCount = 0;
  int _alphaCount = 0;
  List<Map<String, dynamic>> _divisionStats = [];

  // Cached data for detail views
  final List<EmployeeModel> _employees = [];
  final List<AttendanceModel> _todaysAttendance = []; 

  final String _todayDate = DateFormat(
    "EEEE, dd MMMM yyyy",
    "id_ID",
  ).format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Load admin data
      final adminData = await _auth.fetchAdminByEmail(user.email!);
      if (adminData != null) {
        setState(() {
          _companyName = adminData['company'];
        });
      }

      // Load all employees
      final employees = await _employeeService.fetchAllEmployees();
      final employeesByDivision = <String, List<Map<String, dynamic>>>{};

      for (var emp in employees) {
        final division = emp.division.isEmpty ? 'Tanpa Divisi' : emp.division;
        if (!employeesByDivision.containsKey(division)) {
          employeesByDivision[division] = [];
        }
        employeesByDivision[division]!.add({
          'id': emp.id,
          'name': emp.name,
          'division': division,
        });
      }

      // Load today's attendance
      final today = DateTime.now();
      final attendance = await _attendanceService.fetchAttendanceByDateRange(
        '', // Will fetch all
        today,
        today,
      );

      // Process attendance data
      int hadir = 0;
      int izin = 0;
      int cuti = 0;
      int alpha = 0;

      // Count attendance records
      final attendedEmployeeIds = <String>{};
      for (var att in attendance) {
        attendedEmployeeIds.add(att.employeeId);
        final status = att.status.toLowerCase();
        if (status.contains('hadir') || status.contains('present')) {
          hadir++;
        } else if (status.contains('izin') || status.contains('permission')) {
          izin++;
        } else if (status.contains('cuti') || status.contains('leave')) {
          cuti++;
        } else if (status.contains('alpha') || status.contains('absent')) {
          alpha++;
        }
      }

      // Mark employees without attendance as alpha
      alpha = employees.length - attendedEmployeeIds.length;
      if (alpha < 0) alpha = 0;

      // Calculate per division
      final divisionStats = <Map<String, dynamic>>[];
      employeesByDivision.forEach((division, emps) {
        final divisionAttendance = attendance
            .where(
              (att) => emps.any(
                (e) => e['id'].toString() == att.employeeId.toString(),
              ),
            )
            .toList();

        int divHadir = 0;
        int divIzin = 0;
        int divCuti = 0;
        int divAlpha = 0;

        final divisionAttendedIds = <String>{};

        for (var att in divisionAttendance) {
          divisionAttendedIds.add(att.employeeId);
          final status = att.status.toLowerCase();
          if (status.contains('hadir') || status.contains('present')) {
            divHadir++;
          } else if (status.contains('izin') || status.contains('permission')) {
            divIzin++;
          } else if (status.contains('cuti') || status.contains('leave')) {
            divCuti++;
          } else if (status.contains('alpha') || status.contains('absent')) {
            divAlpha++;
          }
        }

        // Mark unanswered employees as alpha
        divAlpha = emps.length - divisionAttendedIds.length;
        if (divAlpha < 0) divAlpha = 0;

        divisionStats.add({
          'division': division,
          'totalKaryawan': emps.length,
          'hadir': divHadir,
          'izin': divIzin,
          'cuti': divCuti,
          'alpha': divAlpha,
        });
      });

      // Sort by division name
      divisionStats.sort(
        (a, b) => a['division'].toString().compareTo(b['division'].toString()),
      );

      setState(() {
        _totalEmployees = employees.length;
        _hadirCount = hadir;
        _izinCount = izin;
        _cutiCount = cuti;
        _alphaCount = alpha;
        _divisionStats = divisionStats;

        // cache for detail views
        _employees.clear();
        _employees.addAll(employees);
        _todaysAttendance.clear();
        _todaysAttendance.addAll(attendance);

        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('Error loading dashboard data: $e');
      debugPrint(st.toString());
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  const Text('Memuat data kehadiran hari ini...'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Refresh Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Dashboard Kehadiran',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: _loadDashboardData,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Refresh',
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            foregroundColor: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Date Header
                    _buildDateHeader(),
                    const SizedBox(height: 24),

                    // Alert (if needed)
                    if (_alphaCount > 0) _buildAlertCard(),
                    if (_alphaCount > 0) const SizedBox(height: 16),

                    // Summary Cards
                    _buildSummaryCards(),
                    const SizedBox(height: 16),

                    // Division Recap Table
                    _buildDivisionRecapSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDateHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monitoring Absensi Hari Ini',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _todayDate,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.people, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                'Total Karyawan: $_totalEmployees',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard() {
    final absentPercentage = (_alphaCount / _totalEmployees * 100)
        .toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.1),
        border: Border.all(
          color: const Color(0xFFEF4444).withOpacity(0.5),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFEF4444),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ada karyawan yang tidak hadir',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_alphaCount karyawan ($absentPercentage%) tidak hadir tanpa keterangan',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ringkasan Kehadiran Hari Ini',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildCompactStatCard(
                title: 'Hadir',
                count: _hadirCount,
                color: const Color(0xFF10B981),
                icon: Icons.check_circle,
                onTap: () => _openAttendanceDetail('Hadir'),
              ),
              const SizedBox(width: 10),
              _buildCompactStatCard(
                title: 'Izin',
                count: _izinCount,
                color: const Color(0xFF3B82F6),
                icon: Icons.assignment,
                onTap: () => _openAttendanceDetail('Izin'),
              ),
              const SizedBox(width: 10),
              _buildCompactStatCard(
                title: 'Cuti',
                count: _cutiCount,
                color: const Color(0xFF8B5CF6),
                icon: Icons.beach_access,
                onTap: () => _openAttendanceDetail('Cuti'),
              ),
              const SizedBox(width: 10),
              _buildCompactStatCard(
                title: 'Alpha',
                count: _alphaCount,
                color: const Color(0xFFEF4444),
                icon: Icons.cancel,
                onTap: () => _openAttendanceDetail('Alpha'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatCard({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final card = Container(
      padding: const EdgeInsets.all(10),
      constraints: const BoxConstraints(minWidth: 90),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 6),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    if (onTap == null) return card;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: card,
    );
  }

  Widget _buildDivisionRecapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Rekap Per Divisi',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: DataTable(
              columnSpacing: 40,
              horizontalMargin: 20,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 56,
              headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
              columns: const [
                DataColumn(
                  label: Text(
                    'Divisi',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Hadir',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Izin',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Cuti',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Alpha',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              rows: _divisionStats
                  .map(
                    (div) => DataRow(
                      cells: [
                        DataCell(
                          Text(
                            div['division'] ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${div['hadir']}',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${div['izin']}',
                            style: const TextStyle(
                              color: Color(0xFF3B82F6),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${div['cuti']}',
                            style: const TextStyle(
                              color: Color(0xFF8B5CF6),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${div['alpha']}',
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  /// Classify employee's attendance status for today using today's attendance list.
  String _classifyEmployeeStatus(EmployeeModel emp, List<AttendanceModel> todays) {
    final empAtt = todays.where((a) => a.employeeId.toString() == emp.id.toString()).toList();

    if (empAtt.isNotEmpty) {
      // Prefer 'Hadir' if any present
      for (final a in empAtt) {
        final s = a.status.toLowerCase();
        if (s.contains('hadir') || s.contains('present')) return 'Hadir';
      }

      // Approved izin
      for (final a in empAtt) {
        final s = a.status.toLowerCase();
        if ((s.contains('izin') || s.contains('permission')) && a.approved == true) return 'Izin';
      }

      // Approved cuti
      for (final a in empAtt) {
        final s = a.status.toLowerCase();
        if ((s.contains('cuti') || s.contains('leave')) && a.approved == true) return 'Cuti';
      }

      // Explicit alpha/absent flag
      for (final a in empAtt) {
        final s = a.status.toLowerCase();
        if (s.contains('alpha') || s.contains('absent')) return 'Alpha';
      }
    }

    // No attendance → Alpha
    return 'Alpha';
  }

  void _openAttendanceDetail(String status) {
    // Ensure we have data
    if (_employees.isEmpty) {
      _loadDashboardData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Memuat data, coba lagi sebentar...')),
      );
      return;
    }

    final items = _employees.map((emp) {
      final s = _classifyEmployeeStatus(emp, _todaysAttendance);
      return {
        'employeeId': emp.id,
        'name': emp.name,
        'division': emp.division,
        'status': s,
      };
    }).where((e) => e['status'] == status).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: AttendanceDetailSheet(
          title: status,
          items: items,
        ),
      ),
    );
  }
}

class AttendanceDetailSheet extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;

  const AttendanceDetailSheet({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            height: 4,
            width: 48,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$title (${items.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            SizedBox(
              height: 160,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.people_outline, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Tidak ada karyawan', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final it = items[i];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text((it['name'] as String).isNotEmpty
                          ? (it['name'] as String)[0].toUpperCase()
                          : '?'),
                    ),
                    title: Text(it['name'] ?? '-'),
                    subtitle: Text('ID: ${it['employeeId']} • ${it['division'] ?? '-'}'),
                    trailing: Text(it['status'] ?? '-'),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
