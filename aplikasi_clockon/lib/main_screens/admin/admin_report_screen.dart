import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/services/admin_report_service.dart';
import '../../utils/theme/app_theme.dart';
import '../../data/services/division_service.dart';
import '../../data/services/employee_service.dart';

class AdminReportScreen extends StatefulWidget {
  const AdminReportScreen({super.key});

  @override
  State<AdminReportScreen> createState() => _AdminReportScreenState();
}

class _AdminReportScreenState extends State<AdminReportScreen> {
  final AdminReportService _reportService = AdminReportService();
  final DivisionService _divisionService = DivisionService();
  final EmployeeService _employeeService = EmployeeService();

  DateTime _selectedDate = DateTime.now();
  DateTime? _selectedDateDaily = DateTime.now();
  int _currentPage = 0;
  List _filteredAttendance = [];
  List attendanceList = [];
  bool _isLoading = true;
  List<Map<String, dynamic>> _divisionStats = [];
  int _totalWorkingDays = 22; // Default working days per month

  @override
  void initState() {
    super.initState();
    _totalWorkingDays = _calculateWorkingDays(_selectedDate);
    _loadData();
  }

  int _calculateWorkingDays(DateTime date) {
    final year = date.year;
    final month = date.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    int workingDays = 0;

    for (int day = 1; day <= daysInMonth; day++) {
      final currentDate = DateTime(year, month, day);
      // Exclude weekends (Saturday & Sunday)
      if (currentDate.weekday != DateTime.saturday &&
          currentDate.weekday != DateTime.sunday) {
        workingDays++;
      }
    }

    return workingDays;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      debugPrint('\n=== LOADING DIVISION ATTENDANCE STATS ===');
      debugPrint(
        '📅 Period: ${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}',
      );
      debugPrint('📊 Working days: $_totalWorkingDays');

      final summary = await _reportService.getDivisionAttendanceSummary(
        year: _selectedDate.year,
        month: _selectedDate.month,
      );

      // Calculate attendance percentage for each division
      final stats = summary.map((div) {
        final totalKaryawan = div['totalKaryawan'] as int? ?? 0;
        final hadir = div['hadir'] as int? ?? 0;
        final cuti = div['cuti'] as int? ?? 0;
        final izin = div['izin'] as int? ?? 0;
        final tidakHadir = div['tidakHadir'] as int? ?? 0;

        // Total possible attendance = employees × working days
        final maxPossibleAttendance = totalKaryawan * _totalWorkingDays;

        // Attendance percentage = (hadir / maxPossibleAttendance) × 100
        final attendancePercentage = maxPossibleAttendance > 0
            ? (hadir / maxPossibleAttendance) * 100
            : 0.0;

        return {
          'division': div['division'],
          'totalKaryawan': totalKaryawan,
          'hadir': hadir,
          'cuti': cuti,
          'izin': izin,
          'tidakHadir': tidakHadir,
          'maxPossibleAttendance': maxPossibleAttendance,
          'attendancePercentage': attendancePercentage,
          'totalRecords': hadir + cuti + izin + tidakHadir,
        };
      }).toList();

      // Sort by attendance percentage (highest first)
      stats.sort(
        (a, b) => (b['attendancePercentage'] as double).compareTo(
          a['attendancePercentage'] as double,
        ),
      );

      debugPrint('✅ Division stats calculated: ${stats.length} divisions');
      for (var stat in stats) {
        debugPrint(
          '   ${stat['division']}: ${(stat['attendancePercentage'] as double).toStringAsFixed(1)}%',
        );
      }

      // Load daily attendance data
      debugPrint('\n=== LOADING DAILY ATTENDANCE DATA ===');
      final dailyAttendance = await _reportService.getDailyAttendance(
        year: _selectedDate.year,
        month: _selectedDate.month,
      );

      debugPrint('✅ Daily attendance loaded: ${dailyAttendance.length} records');

      // Map dailyAttendance to include formatted check-in and check-out times
      final mappedAttendance = dailyAttendance.map((record) {
        return {
          ...record,
          'checkInTime': record['checkin'] != null ? DateFormat('HH:mm').format(record['checkin']) : '-',
          'checkOutTime': record['checkout'] != null ? DateFormat('HH:mm').format(record['checkout']) : '-',
        };
      }).toList();

      setState(() {
        _divisionStats = stats;
        attendanceList = mappedAttendance;
        _filterByDate(_selectedDateDaily);
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('Error loading data: $e');
      debugPrint(st.toString());
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDatePickerMode: DatePickerMode.day,
      helpText: 'Pilih Bulan dan Tahun',
      cancelText: 'Batal',
      confirmText: 'OK',
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _totalWorkingDays = _calculateWorkingDays(picked);
      });
      _loadData();
    }
  }
  Future<void> _selectDailyDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateDaily,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Pilih Tanggal',
      cancelText: 'Batal',
      confirmText: 'OK',
    );

    if (picked != null && picked != _selectedDateDaily) {
      setState(() {
        _selectedDateDaily = picked;
        _filterByDate(picked);
      });
    }
  }

  void _filterByDate(DateTime? date) {
    if (date == null) {
      setState(() {
        _filteredAttendance = [];
        _currentPage = 0;
      });
      return;
    }

    setState(() {
      _filteredAttendance = attendanceList.where((item) {
        final itemDate = item['date'];
        if (itemDate == null || itemDate is! DateTime) return false;
        return itemDate.day == date.day && itemDate.month == date.month && itemDate.year == date.year;
      }).toList();
      _currentPage = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat("MMMM yyyy", "id_ID").format(_selectedDate);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  const Text('Memuat data laporan...'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Laporan Kehadiran Per Divisi',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _selectMonth,
                              icon: const Icon(Icons.calendar_month),
                              tooltip: 'Pilih Bulan',
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.primary.withOpacity(
                                  0.1,
                                ),
                                foregroundColor: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _loadData,
                              icon: const Icon(Icons.refresh),
                              tooltip: 'Refresh',
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.primary.withOpacity(
                                  0.1,
                                ),
                                foregroundColor: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Period Info Card
                    _buildPeriodInfoCard(monthLabel),
                    const SizedBox(height: 24),

                    // Bar Chart Section
                    _buildBarChartSection(),
                    const SizedBox(height: 24),

                    // Detailed Insights
                    _buildDetailedInsights(),
                    const SizedBox(height: 24),

                    // Daily Attendance Table
                    _buildDailyAttendanceSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodInfoCard(String monthLabel) {
    final totalEmployees = _divisionStats.fold<int>(
      0,
      (sum, div) => sum + (div['totalKaryawan'] as int? ?? 0),
    );
    final totalDivisions = _divisionStats.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_today,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Periode Laporan',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    Text(
                      monthLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.business,
                  label: 'Total Divisi',
                  value: '$totalDivisions',
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.3),
              ),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.people,
                  label: 'Total Karyawan',
                  value: '$totalEmployees',
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.3),
              ),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.event,
                  label: 'Hari Kerja',
                  value: '$_totalWorkingDays',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBarChartSection() {
    if (_divisionStats.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.bar_chart, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'Tidak ada data untuk periode ini',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.bar_chart,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Persentase Kehadiran Per Divisi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ..._divisionStats.asMap().entries.map((entry) {
            final index = entry.key;
            final div = entry.value;
            final divisionName = div['division'] as String;
            final percentage = div['attendancePercentage'] as double;
            final totalKaryawan = div['totalKaryawan'] as int;

            return _buildBarItem(
              divisionName: divisionName,
              percentage: percentage,
              totalEmployees: totalKaryawan,
              index: index,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBarItem({
    required String divisionName,
    required double percentage,
    required int totalEmployees,
    required int index,
  }) {
    final color = _getDivisionColor(index);
    final status = _getAttendanceStatus(percentage);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        divisionName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$totalEmployees karyawan',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: status['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: status['color'].withOpacity(0.3)),
                ),
                child: Text(
                  status['label'],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: status['color'],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getDivisionColor(int index) {
    final colors = [
      const Color(0xFF10B981), // Green
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFF59E0B), // Orange
      const Color(0xFFEF4444), // Red
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFFEC4899), // Pink
      const Color(0xFF14B8A6), // Teal
    ];
    return colors[index % colors.length];
  }

  Map<String, dynamic> _getAttendanceStatus(double percentage) {
    if (percentage >= 90) {
      return {'label': 'Sangat Baik', 'color': const Color(0xFF10B981)};
    } else if (percentage >= 80) {
      return {'label': 'Baik', 'color': const Color(0xFF3B82F6)};
    } else if (percentage >= 70) {
      return {'label': 'Cukup', 'color': const Color(0xFFF59E0B)};
    } else if (percentage >= 60) {
      return {'label': 'Kurang', 'color': const Color(0xFFFF6B35)};
    } else {
      return {'label': 'Buruk', 'color': const Color(0xFFEF4444)};
    }
  }

  Widget _buildDetailedInsights() {
    if (_divisionStats.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate overall statistics
    final totalEmployees = _divisionStats.fold<int>(
      0,
      (sum, div) => sum + (div['totalKaryawan'] as int),
    );
    final totalHadir = _divisionStats.fold<int>(
      0,
      (sum, div) => sum + (div['hadir'] as int),
    );
    final totalMaxPossible = _divisionStats.fold<int>(
      0,
      (sum, div) => sum + (div['maxPossibleAttendance'] as int),
    );
    final overallPercentage = totalMaxPossible > 0
        ? (totalHadir / totalMaxPossible) * 100
        : 0.0;

    // Find best and worst performing divisions
    final sortedByPercentage = List<Map<String, dynamic>>.from(_divisionStats)
      ..sort(
        (a, b) => (b['attendancePercentage'] as double).compareTo(
          a['attendancePercentage'] as double,
        ),
      );

    final bestDivision = sortedByPercentage.first;
    final worstDivision = sortedByPercentage.last;

    // Calculate average
    final avgPercentage =
        _divisionStats.fold<double>(
          0.0,
          (sum, div) => sum + (div['attendancePercentage'] as double),
        ) /
        _divisionStats.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.purple.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.amber.shade700, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Insight & Analisis Detail',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Overall Performance
          _buildInsightItem(
            icon: Icons.assessment,
            title: 'Performa Keseluruhan',
            value: '${overallPercentage.toStringAsFixed(1)}%',
            description:
                'Rata-rata kehadiran dari $totalEmployees karyawan di ${_divisionStats.length} divisi',
            color: Colors.blue,
          ),
          const SizedBox(height: 16),

          // Best Division
          _buildInsightItem(
            icon: Icons.emoji_events,
            title: 'Divisi Terbaik',
            value:
                '${(bestDivision['attendancePercentage'] as double).toStringAsFixed(1)}%',
            description:
                '${bestDivision['division']} menunjukkan performa kehadiran tertinggi dengan ${bestDivision['hadir']} dari ${bestDivision['maxPossibleAttendance']} kehadiran yang mungkin',
            color: Colors.green,
          ),
          const SizedBox(height: 16),

          // Worst Division (Need Attention)
          _buildInsightItem(
            icon: Icons.warning_amber_rounded,
            title: 'Perlu Perhatian',
            value:
                '${(worstDivision['attendancePercentage'] as double).toStringAsFixed(1)}%',
            description:
                '${worstDivision['division']} memiliki tingkat kehadiran terendah. Rekomendasi: lakukan evaluasi dan pembinaan untuk meningkatkan disiplin',
            color: Colors.orange,
          ),
          const SizedBox(height: 16),

          // Average Performance
          _buildInsightItem(
            icon: Icons.analytics,
            title: 'Rata-rata Divisi',
            value: '${avgPercentage.toStringAsFixed(1)}%',
            description:
                'Standar performa kehadiran rata-rata dari seluruh divisi',
            color: Colors.purple,
          ),
          const SizedBox(height: 20),

          // Additional Insights
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📊 Rekomendasi Evaluasi:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),
                _buildRecommendationItem(
                  'Divisi dengan persentase < 70% memerlukan tindakan korektif segera',
                ),
                _buildRecommendationItem(
                  'Divisi dengan persentase 70-80% perlu monitoring dan pembinaan',
                ),
                _buildRecommendationItem(
                  'Divisi dengan persentase > 90% dapat dijadikan best practice',
                ),
                _buildRecommendationItem(
                  'Pertimbangkan faktor cuti dan izin dalam evaluasi performa',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightItem({
    required IconData icon,
    required String title,
    required String value,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        value,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyAttendanceSection() {
    final dailyDateLabel = DateFormat("dd MMMM yyyy", "id_ID").format(_selectedDateDaily ?? DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Date Picker
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Laporan Kehadiran Harian',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                Text(
                  dailyDateLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _selectDailyDate,
                  icon: const Icon(Icons.calendar_today),
                  tooltip: 'Pilih Tanggal',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Daily Attendance Table
        _buildDailyAttendanceTable(),
      ],
    );
  }

  Widget _buildDailyAttendanceTable() {
    if (_filteredAttendance.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.table_chart, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'Tidak ada data kehadiran untuk tanggal ini',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    const int itemsPerPage = 10;
    final int totalPages = (_filteredAttendance.length / itemsPerPage).ceil();
    final int startIndex = _currentPage * itemsPerPage;
    final int endIndex = (startIndex + itemsPerPage) > _filteredAttendance.length
        ? _filteredAttendance.length
        : startIndex + itemsPerPage;
    final List currentItems = _filteredAttendance.sublist(startIndex, endIndex);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.table_chart,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Tabel Kehadiran Harian',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Nama Karyawan')),
                DataColumn(label: Text('Tanggal')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Jam Masuk')),
                DataColumn(label: Text('Jam Keluar')),
              ],
              rows: currentItems.map((item) {
                return DataRow(
                  cells: [
                    DataCell(Text(item['employeeName'] ?? '')),
                    DataCell(Text(DateFormat('dd/MM/yyyy').format(item['date']))),
                    DataCell(Text(item['status'] ?? '')),
                    DataCell(Text(item['checkInTime'] ?? '-')),
                    DataCell(Text(item['checkOutTime'] ?? '-')),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage--)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('Halaman ${_currentPage + 1} dari $totalPages'),
              IconButton(
                onPressed: _currentPage < totalPages - 1
                    ? () => setState(() => _currentPage++)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
