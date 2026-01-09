import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/theme/app_theme.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/permission_service.dart';

class EmployeePermissionHistory extends StatefulWidget {
  const EmployeePermissionHistory({super.key});

  @override
  State<EmployeePermissionHistory> createState() =>
      _EmployeePermissionHistoryState();
}

class _EmployeePermissionHistoryState extends State<EmployeePermissionHistory> {
  final AuthService _authService = AuthService();
  final PermissionService _permissionService = PermissionService();
  String _employeeId = '';
  List<PermissionRecord> _permissionHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPermissionHistory();
  }

  Future<void> _loadPermissionHistory() async {
    setState(() => _isLoading = true);

    final user = _authService.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final emp = await _authService.fetchEmployeeByEmail(user.email ?? '');
    if (emp != null) {
      setState(() {
        _employeeId = (emp['id'] ?? emp['_id'] ?? '').toString();
      });
    }

    // Fetch actual permission history from API
    try {
      final permissions = await _permissionService.fetchAllPermissions();

      // Filter permissions for this employee only
      final myPermissions = permissions
          .where((p) => p.employeeId == _employeeId)
          .toList();

      // Sort by date descending (newest first)
      myPermissions.sort((a, b) => b.leaveDate.compareTo(a.leaveDate));

      // Convert to PermissionRecord
      final records = myPermissions.map((p) {
        return PermissionRecord(
          id: p.id,
          date: p.leaveDate,
          type: p.type,
          reason: p.reason,
          status: _capitalizeStatus(p.status),
          approvedBy: (p.adminId != null && p.adminId!.isNotEmpty)
              ? 'Admin'
              : '-',
          notes: (p.adminEmail != null && p.adminEmail!.isNotEmpty)
              ? 'Diproses oleh: ${p.adminEmail}'
              : (p.status.toLowerCase() == 'pending'
                    ? 'Menunggu persetujuan'
                    : ''),
        );
      }).toList();

      setState(() {
        _permissionHistory = records;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading permission history: $e');
      setState(() {
        _permissionHistory = [];
        _isLoading = false;
      });
      _showMessage('Gagal memuat riwayat perizinan', false);
    }
  }

  String _capitalizeStatus(String status) {
    if (status.isEmpty) return status;
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'pending':
        return 'Pending';
      default:
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'izin':
        return AppColors.info;
      case 'cuti':
        return AppColors.primary;
      default:
        return Colors.grey;
    }
  }

  void _showMessage(String msg, bool isSuccess) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _openLeaveForm() {
    String selectedType = "Izin";
    DateTime selectedDate = DateTime.now();
    final TextEditingController reasonController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Ajukan Izin / Cuti",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Isi formulir pengajuan izin atau cuti Anda",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.category),
                        labelText: "Jenis",
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: "Cuti", child: Text("Cuti")),
                        DropdownMenuItem(value: "Izin", child: Text("Izin")),
                      ],
                      onChanged: (value) =>
                          setModalState(() => selectedType = value!),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.light().copyWith(
                              colorScheme: ColorScheme.light(
                                primary: AppColors.primary,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      controller: reasonController,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.description),
                        labelText: "Alasan",
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      maxLines: 4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: const Text(
                            "Batal",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (reasonController.text.trim().isEmpty) {
                              Navigator.pop(context);
                              _showMessage("Alasan harus diisi!", false);
                              return;
                            }

                            Navigator.pop(context);
                            setState(() => _isLoading = true);

                            try {
                              final emp = await _authService
                                  .fetchEmployeeByEmail(
                                    _authService.currentUser?.email ?? '',
                                  );
                              final employeeName =
                                  emp?['name'] ??
                                  emp?['nama'] ??
                                  emp?['fullName'] ??
                                  _authService.currentUser?.displayName ??
                                  '';
                              final employeeDivision =
                                  emp?['division'] ?? emp?['divisi'];
                              final employeeAvatarPath =
                                  emp?['avatarPath'] ?? emp?['avatar_path'];

                              final success = await _permissionService
                                  .submitPermissionRequest(
                                    employeeId: _employeeId,
                                    employeeName: employeeName,
                                    employeeEmail:
                                        _authService.currentUser?.email ?? '',
                                    employeeDivision: employeeDivision,
                                    employeeAvatarPath: employeeAvatarPath,
                                    type: selectedType,
                                    reason: reasonController.text.trim(),
                                    leaveDate: selectedDate,
                                  );

                              if (success) {
                                _showMessage(
                                  "Pengajuan izin berhasil dikirim!",
                                  true,
                                );
                                // Refresh data
                                await _loadPermissionHistory();
                              } else {
                                _showMessage(
                                  "Gagal mengirim pengajuan izin",
                                  false,
                                );
                              }
                            } catch (e) {
                              _showMessage("Error: $e", false);
                            } finally {
                              setState(() => _isLoading = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Kirim",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openLeaveForm,
        label: const Text("Ajukan Izin"),
        icon: const Icon(Icons.add_task, size: 20),
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              // Header Card
              Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(16),
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
                              Icons.history,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Riwayat Izin/Cuti',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Total: ${_permissionHistory.length} permintaan',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatCard(
                            'Disetujui',
                            _permissionHistory
                                .where(
                                  (p) => p.status.toLowerCase() == 'approved',
                                )
                                .length
                                .toString(),
                            Colors.green,
                          ),
                          _buildStatCard(
                            'Menunggu',
                            _permissionHistory
                                .where(
                                  (p) => p.status.toLowerCase() == 'pending',
                                )
                                .length
                                .toString(),
                            Colors.orange,
                          ),
                          _buildStatCard(
                            'Ditolak',
                            _permissionHistory
                                .where(
                                  (p) => p.status.toLowerCase() == 'rejected',
                                )
                                .length
                                .toString(),
                            Colors.red,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Permission List
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daftar Permintaan Izin/Cuti',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _permissionHistory.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.hourglass_empty,
                                    size: 64,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Belum ada riwayat',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _permissionHistory.length,
                            itemBuilder: (context, index) {
                              final permission = _permissionHistory[index];
                              return _buildPermissionCard(permission);
                            },
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      );
  }

  Widget _buildStatCard(String label, String count, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard(PermissionRecord permission) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getTypeColor(
                              permission.type,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            permission.type,
                            style: TextStyle(
                              color: _getTypeColor(permission.type),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              permission.status,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            permission.status,
                            style: TextStyle(
                              color: _getStatusColor(permission.status),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      permission.reason,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tanggal',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd MMMM yyyy', 'id_ID').format(permission.date),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Disetujui Oleh',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    permission.approvedBy,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (permission.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Catatan',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    permission.notes,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PermissionRecord {
  final String id;
  final DateTime date;
  final String type;
  final String reason;
  final String status;
  final String approvedBy;
  final String notes;

  PermissionRecord({
    required this.id,
    required this.date,
    required this.type,
    required this.reason,
    required this.status,
    required this.approvedBy,
    required this.notes,
  });
}
