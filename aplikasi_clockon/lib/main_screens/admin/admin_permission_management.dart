import 'package:flutter/material.dart';
import '../../../utils/theme/app_theme.dart';
import '../../utils/avatar_helper.dart';
import '../../data/models/permission_model.dart';
import '../../data/models/employee_model.dart';
import '../../data/services/permission_service.dart';
import '../../data/services/employee_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/shift_service.dart';
import 'package:intl/intl.dart';

class AdminPermissionManagementScreen extends StatefulWidget {
  const AdminPermissionManagementScreen({super.key});

  @override
  State<AdminPermissionManagementScreen> createState() =>
      _AdminPermissionManagementScreenState();
}

class _AdminPermissionManagementScreenState
    extends State<AdminPermissionManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String filterStatus = "Semua"; // Filter aktif

  final List<String> statusOptions = [
    "Semua",
    "pending",
    "approved",
    "rejected",
  ];

  // ============================
  // REAL DATA FROM API
  // ============================
  final List<PermissionModel> _permissions = [];
  bool _isLoading = false;
  String _loadError = '';

  final PermissionService _permissionService = PermissionService();
  final EmployeeService _employeeService = EmployeeService();
  final AuthService _authService = AuthService();
  final ShiftService _shiftService = ShiftService();

  @override
  void initState() {
    _tabController = TabController(length: 2, vsync: this);
    _loadPermissions();
    super.initState();
  }

  Future<void> _loadPermissions() async {
    debugPrint('=== _loadPermissions called ===');
    setState(() {
      _isLoading = true;
      _loadError = '';
    });

    try {
      // Fetch permissions dan employee data
      final permissions = await _permissionService.fetchAllPermissions();
      final employees = await _employeeService.fetchAllEmployees();

      // Map employee data untuk quick lookup
      final employeeMap = <String, EmployeeModel>{};
      for (final emp in employees) {
        employeeMap[emp.id] = emp;
      }

      debugPrint('Fetched ${permissions.length} permissions');
      debugPrint('Fetched ${employees.length} employees for avatar mapping');

      // Update permission avatarPath dari employee data terbaru
      final updatedPermissions = permissions.map((p) {
        final employee = employeeMap[p.employeeId];
        // Update avatar dan divisi dari employee data terbaru
        return PermissionModel(
          id: p.id,
          employeeId: p.employeeId,
          employeeName: p.employeeName,
          employeeEmail: p.employeeEmail,
          employeeDivision:
              employee?.division ??
              p.employeeDivision, // dari employee data atau fallback
          employeeAvatarPath:
              employee?.avatarPath ??
              p.employeeAvatarPath, // dari employee data atau fallback
          type: p.type,
          reason: p.reason,
          leaveDate: p.leaveDate,
          scheduleId: p.scheduleId,
          shiftId: p.shiftId,
          status: p.status,
          adminId: p.adminId,
          adminEmail: p.adminEmail,
          processedAt: p.processedAt,
          createdAt: p.createdAt,
        );
      }).toList();

      setState(() {
        _permissions.clear();
        _permissions.addAll(updatedPermissions);
        debugPrint(
          'Updated _permissions list with ${updatedPermissions.length} items',
        );
      });
    } catch (e) {
      debugPrint('Error loading permissions: $e');
      setState(() {
        _loadError = 'Gagal memuat data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<PermissionModel> get _filteredPermissions {
    if (filterStatus == 'Semua') return _permissions;
    final fs = filterStatus.toLowerCase();
    return _permissions.where((p) => p.status.toLowerCase() == fs).toList();
  }

  Future<String> _getShiftLabel(String? shiftId) async {
    if (shiftId == null || shiftId.isEmpty) return '-';
    try {
      final shifts = await _shiftService.fetchAllShifts('');
      final shift = shifts.where((s) => s['id'] == shiftId).toList();
      return shift.isNotEmpty ? shift.first['label'] ?? shiftId : shiftId;
    } catch (e) {
      debugPrint('Error getting shift label: $e');
      return shiftId;
    }
  }

  Future<void> _updatePermissionStatus(
    String permissionId,
    String status,
  ) async {
    setState(() => _isLoading = true);

    try {
      final adminUser = _authService.currentUser;
      if (adminUser == null) {
        _showMessage('Admin tidak terautentikasi', false);
        setState(() => _isLoading = false);
        return;
      }

      // Validate admin email
      final adminEmail = adminUser.email;
      if (adminEmail == null || adminEmail.isEmpty) {
        _showMessage('Email admin tidak valid', false);
        setState(() => _isLoading = false);
        return;
      }

      debugPrint('=== Admin Permission Update ===');
      debugPrint('Permission ID: $permissionId');
      debugPrint('New Status: $status');
      debugPrint('Admin ID: ${adminUser.uid}');
      debugPrint('Admin Email: $adminEmail');

      final success = await _permissionService.updatePermissionStatus(
        permissionId: permissionId,
        status: status,
        adminId: adminUser.uid,
        adminEmail: adminEmail,
      );

      if (success) {
        _showMessage(
          'Permission ${status == 'approved' ? 'disetujui' : 'ditolak'}',
          true,
        );
        // Reload data and wait for it to complete
        await _loadPermissions();
      } else {
        _showMessage(
          'Gagal update permission - periksa koneksi internet',
          false,
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error updating permission status: $e');
      _showMessage('Error: $e', false);
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ===============================
          // TAB HEADER
          // ===============================
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: "Izin"),
                Tab(text: "Cuti"),
              ],
            ),
          ),

          // ===============================
          // FILTER DROPDOWN
          // ===============================
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.filter_list, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  "Filter Status:",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButton<String?>(
                    value: statusOptions.contains(filterStatus)
                        ? filterStatus
                        : null,
                    underline: const SizedBox(),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: Colors.grey.shade600,
                    ),
                    items: statusOptions
                        .map(
                          (e) => DropdownMenuItem<String?>(
                            value: e,
                            child: Text(
                              e,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        filterStatus = v;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // ===============================
          // TAB CONTENT
          // ===============================
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadError.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_loadError),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadPermissions,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _permissionListByType('Izin'),
                      _permissionListByType('Cuti'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ===============================
  // LIST BUILDER + FILTER BY TYPE
  // ===============================
  Widget _permissionListByType(String type) {
    // Filter by type and status
    final filtered = _filteredPermissions.where((p) => p.type == type).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              "Tidak ada data ${type.toLowerCase()}",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPermissions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final permission = filtered[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: _statusColor(permission.status).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with avatar, name, and status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AvatarHelper.buildAvatar(
                        avatarPath:
                            permission.employeeAvatarPath ??
                            'assets/karyawan1.jpeg',
                        radius: 26,
                        showBorder: true,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              permission.employeeName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3748),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              permission.employeeEmail,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              permission.employeeDivision?.isNotEmpty == true
                                  ? permission.employeeDivision!
                                  : '-',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(
                            permission.status,
                          ).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _statusColor(
                              permission.status,
                            ).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          _getStatusText(permission.status),
                          style: TextStyle(
                            color: _statusColor(permission.status),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Details section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        // Date and Type row
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 18,
                                    color: Colors.blue.shade500,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat(
                                      'dd MMM yyyy',
                                      'id_ID',
                                    ).format(permission.leaveDate.toLocal()),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF2D3748),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: type == 'Izin'
                                    ? Colors.orange.shade100
                                    : Colors.purple.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                permission.type,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: type == 'Izin'
                                      ? Colors.orange.shade700
                                      : Colors.purple.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Reason
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.notes,
                              size: 18,
                              color: Colors.purple.shade500,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                permission.reason,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF4A5568),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Shift
                        Row(
                          children: [
                            Icon(
                              Icons.timelapse,
                              size: 18,
                              color: Colors.teal.shade500,
                            ),
                            const SizedBox(width: 8),
                            FutureBuilder<String>(
                              future: _getShiftLabel(permission.shiftId),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.teal,
                                      ),
                                    ),
                                  );
                                }
                                return Text(
                                  snapshot.data ?? '-',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF2D3748),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Action buttons for pending status
                  if (permission.status == 'pending') ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoading
                                ? null
                                : () => _updatePermissionStatus(
                                    permission.id,
                                    'rejected',
                                  ),
                            icon: const Icon(Icons.close, size: 20),
                            label: const Text(
                              'Tolak',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade600,
                              side: BorderSide(color: Colors.red.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading
                                ? null
                                : () => _updatePermissionStatus(
                                    permission.id,
                                    'approved',
                                  ),
                            icon: const Icon(Icons.check, size: 20),
                            label: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Setujui',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===============================
  // PERMISSION DETAIL DIALOG
  // ===============================
  void _showPermissionDetail(PermissionModel permission) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(permission.employeeName),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Email: ${permission.employeeEmail}"),
              Text("Jenis: ${permission.type}"),
              Text(
                "Tanggal: ${permission.leaveDate.toLocal().toString().split(' ')[0]}",
              ),
              Text("Alasan: ${permission.reason}"),
              if (permission.shiftId != null) ...[
                Text("Shift: ${permission.shiftId}"),
              ],
              Text("Status: ${permission.status}"),
              Text("Dibuat: ${permission.createdAt.toLocal()}"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Tutup"),
          ),
          if (permission.status == 'pending') ...[
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updatePermissionStatus(permission.id, 'approved');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text("Setujui"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updatePermissionStatus(permission.id, 'rejected');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Tolak"),
            ),
          ],
        ],
      ),
    );
  }

  // ===============================
  // HELPER METHODS
  // ===============================
  String _getStatusText(String status) {
    switch (status) {
      case "pending":
        return "Menunggu";
      case "approved":
        return "Disetujui";
      case "rejected":
        return "Ditolak";
      default:
        return status;
    }
  }

  // ===============================
  // WARNA STATUS
  // ===============================
  Color _statusColor(String status) {
    switch (status) {
      case "pending":
        return Colors.orange;
      case "approved":
        return Colors.green;
      case "rejected":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
