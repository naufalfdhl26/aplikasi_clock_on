import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../utils/theme/app_theme.dart';
import '../../utils/avatar_helper.dart';
import '../../data/models/location_model.dart';
import '../../data/models/employee_model.dart';
import '../../data/models/division_model.dart';
import '../../data/services/employee_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/division_service.dart';
import '../../data/services/location_service.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  final List<Map<String, dynamic>> _employees = [];
  final List<DivisionModel> _divisions = [];
  final List<LocationModel> _locations = [];
  bool _isLoading = false;
  String _loadError = '';

  final EmployeeService _employeeService = EmployeeService();
  final AuthService _authService = AuthService();
  final DivisionService _divisionService = DivisionService();
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = '';
    });
    try {
      // VALIDATE: ensure logged-in user is an ADMIN
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        setState(() {
          _loadError = 'Anda belum login';
          _isLoading = false;
        });
        return;
      }

      final adminData = await _authService.fetchAdminByEmail(
        currentUser.email ?? '',
      );
      if (adminData == null) {
        setState(() {
          _loadError =
              'User ${currentUser.email} bukan admin. Harap login sebagai admin.';
          _isLoading = false;
        });
        debugPrint(
          'WARN: Non-admin user tried to access admin screen: ${currentUser.email}',
        );
        return;
      }

      final dList = await _divisionService.fetchAllDivisions();
      final lList = await _locationService.fetchAllLocations();
      final eList = await _employeeService.fetchAllEmployees();

      // Use admin id from validated admin data
      final currentAdminId = adminData['id']?.toString() ?? '';
      debugPrint('Admin validated: $currentAdminId (${currentUser.email})');
      debugPrint('=== Filter employees by admin ===');
      debugPrint('Total employees from backend: ${eList.length}');

      setState(() {
        _divisions.clear();
        _divisions.addAll(dList);
        _locations.clear();
        _locations.addAll(lList);
        _employees.clear();
        for (final e in eList) {
          debugPrint(
            'Employee: ${e.name}, createdByAdminId=${e.createdByAdminId}, createdByAdminEmail=${e.createdByAdminEmail}',
          );
          // skip employees not created by this admin (compare by email)
          if ((e.createdByAdminEmail ?? '') != (currentUser.email ?? '')) {
            debugPrint(
              '  → SKIPPED (createdByAdminEmail="${e.createdByAdminEmail}" != currentUser.email="${currentUser.email}")',
            );
            continue;
          }
          debugPrint('  → ADDED');
          _employees.add({
            'id': e.id,
            'name': e.name,
            'email': e.email,
            'password': e.password,
            'position': e.position ?? '',
            'division': e.division,
            'locationId': e.locationId,
            'lokasi': _locations.where((l) => l.id == e.locationId).isNotEmpty
                ? _locations
                      .where((l) => l.id == e.locationId)
                      .map((l) => l.name)
                      .first
                : '-',
            'status': e.isActive ? 'Aktif' : 'Tidak Aktif',
            'lastAttendance': '--:--',
            'attendanceRate': '0%',
            'avatarColor': AppColors.primary,
            'avatarPath':
                e.avatarPath ?? 'assets/karyawan1.jpeg', // tambah avatarPath
          });
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() {
        _loadError = 'Gagal memuat data: $e';
        _isLoading = false;
      });
    }
  }

  String _searchQuery = '';
  String _filterStatus = 'Semua';
  String _filterDivision = 'Semua';

  final List<String> _statuses = ['Semua', 'Aktif', 'Tidak Aktif'];

  List<Map<String, dynamic>> get _filteredEmployees {
    final q = _searchQuery.trim().toLowerCase();
    return _employees.where((employee) {
      final name = (employee['name'] ?? '').toString().toLowerCase();
      final email = (employee['email'] ?? '').toString().toLowerCase();

      final matchesSearch = q.isEmpty || name.contains(q) || email.contains(q);
      final matchesStatus =
          _filterStatus == 'Semua' || employee['status'] == _filterStatus;
      final matchesDivision =
          _filterDivision == 'Semua' || employee['division'] == _filterDivision;

      return matchesSearch && matchesStatus && matchesDivision;
    }).toList();
  }

  // =====================================================================
  // CRUD ADD / EDIT EMPLOYEE
  // =====================================================================

  void _addOrEditEmployee({Map<String, dynamic>? employee}) {
    final isEdit = employee != null;

    final id = isEdit
        ? employee['id']
        : DateTime.now().millisecondsSinceEpoch.toString();

    final nameCtrl = TextEditingController(text: employee?['name'] ?? '');
    final emailCtrl = TextEditingController(text: employee?['email'] ?? '');
    final passwordCtrl = TextEditingController(
      text: employee?['password'] ?? '',
    );

    final positionCtrl = TextEditingController(
      text: employee?['position'] ?? '',
    );
    String selectedDivision = employee?['division'] ?? '';

    // determine initial selected location id (support legacy 'lokasi' name)
    String? initLocId;
    if (employee != null) {
      initLocId = employee['locationId'];
      if (initLocId == null && employee['lokasi'] != null) {
        final m = _locations
            .where((l) => l.name == employee['lokasi'])
            .toList();
        if (m.isNotEmpty) initLocId = m.first.id;
      }
    }
    String? selectedLocationId = initLocId;

    String status = employee?['status'] ?? 'Aktif';
    bool showPassword = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Karyawan' : 'Tambah Karyawan'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                ),
                const SizedBox(height: 8),

                // EMAIL
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 8),

                // PASSWORD
                TextField(
                  controller: passwordCtrl,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        showPassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setDialogState(() => showPassword = !showPassword),
                    ),
                  ),
                  obscureText: !showPassword,
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: positionCtrl,
                  decoration: const InputDecoration(labelText: 'Posisi'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedDivision.isNotEmpty
                      ? selectedDivision
                      : null,
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('- Pilih Divisi -'),
                    ),
                    ..._divisions.map(
                      (d) =>
                          DropdownMenuItem(value: d.name, child: Text(d.name)),
                    ),
                    const DropdownMenuItem(
                      value: '__ADD_NEW__',
                      child: Text('+ Tambah Divisi Baru'),
                    ),
                  ],
                  onChanged: (v) async {
                    if (v == '__ADD_NEW__') {
                      final nameCtrl = TextEditingController();
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Tambah Divisi Baru'),
                          content: TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nama Divisi',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Batal'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                final name = nameCtrl.text.trim();
                                if (name.isEmpty) return;

                                final model = DivisionModel(
                                  id: DateTime.now().millisecondsSinceEpoch
                                      .toString(),
                                  name: name,
                                  createdAt: DateTime.now(),
                                  updatedAt: DateTime.now(),
                                );
                                final created = await _divisionService
                                    .createDivision(model);
                                if (created != null && mounted) {
                                  setState(() {
                                    _divisions.add(created);
                                    selectedDivision = created.name;
                                  });
                                }
                                if (mounted) Navigator.pop(context);
                              },
                              child: const Text('Tambah'),
                            ),
                          ],
                        ),
                      );
                    } else {
                      selectedDivision = v ?? '';
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Divisi'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedLocationId,
                  items:
                      _locations
                          .map(
                            (l) => DropdownMenuItem(
                              value: l.id,
                              child: Text(l.name),
                            ),
                          )
                          .toList()
                        ..insert(
                          0,
                          const DropdownMenuItem(
                            value: '',
                            child: Text('- Pilih Lokasi -'),
                          ),
                        ),
                  onChanged: (v) => selectedLocationId = v,
                  decoration: const InputDecoration(labelText: 'Lokasi Kantor'),
                ),
                const SizedBox(height: 8),

                DropdownButtonFormField<String>(
                  initialValue: status,
                  items: ['Aktif', 'Tidak Aktif']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => status = v ?? status,
                  decoration: const InputDecoration(labelText: 'Status'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final email = emailCtrl.text.trim();
                final pass = passwordCtrl.text.trim();
                if (name.isEmpty || email.isEmpty || pass.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Nama, email, dan password wajib diisi'),
                    ),
                  );
                  return;
                }

                if (!email.contains('@')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('email tidak valid'),
                    ),
                  );
                  return;
                }

                // NOTE: Firebase account will be created here for employees when admin adds them.
                // This ensures employees can login immediately without waiting for first login.

                // Persist to backend
                final divName = selectedDivision.isEmpty
                    ? 'Umum'
                    : selectedDivision;
                if (isEdit) {
                  final ok = await _employeeService.updateEmployee(id, {
                    'name': name,
                    'email': email,
                    'position': positionCtrl.text.trim(),
                    'division': divName,
                    'locationId': selectedLocationId ?? '',
                    'status': status,
                  });
                  if (ok) {
                    // Reload dari backend untuk konsistensi
                    await _loadData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Data karyawan berhasil diperbarui'),
                        ),
                      );
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Gagal memperbarui data karyawan'),
                        ),
                      );
                    }
                  }
                } else {
                  // Store admin credentials BEFORE creating employee account
                  String createdByAdminId = '';
                  String createdByAdminEmail = '';
                  String adminPassword = ''; // We'll need this for re-login
                  final currentUser = _authService.currentUser;
                  debugPrint(
                    'DEBUG: currentUser.email = ${currentUser?.email}',
                  );
                  if (currentUser != null) {
                    final adminData = await _authService.fetchAdminByEmail(
                      currentUser.email ?? '',
                    );
                    debugPrint('DEBUG: adminData from GoCloud = $adminData');
                    createdByAdminId = adminData?['id']?.toString() ?? '';
                    createdByAdminEmail =
                        adminData?['email']?.toString() ??
                        currentUser.email ??
                        '';
                    adminPassword = adminData?['password']?.toString() ?? '';
                  }

                  debugPrint(
                    'Creating employee with creator id: $createdByAdminId, email: $createdByAdminEmail',
                  );
                  final ok = await _employeeService.createEmployee(
                    EmployeeModel(
                      id: id,
                      name: name,
                      email: email,
                      password: pass,
                      division: divName,
                      locationId: selectedLocationId ?? '',
                      position: positionCtrl.text.trim(),
                      isActive: status == 'Aktif',
                      createdByAdminId: createdByAdminId,
                      createdByAdminEmail: createdByAdminEmail,
                    ),
                  );
                  if (ok) {
                    // CREATE FIREBASE AUTH ACCOUNT for the employee
                    try {
                      debugPrint(
                        'Creating Firebase Auth account for employee: $email',
                      );
                      await _authService.registerWithEmail(email, pass);
                      debugPrint(
                        'Firebase Auth account created successfully for: $email',
                      );
                    } catch (firebaseErr) {
                      debugPrint(
                        'Failed to create Firebase Auth account: $firebaseErr',
                      );
                      // Continue anyway, as the employee record is already created
                      // Show warning to user
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Karyawan berhasil ditambahkan, namun akun Firebase gagal dibuat: $firebaseErr',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    }

                    // debug: fetch created employee to verify stored fields
                    try {
                      final createdRecord = await _authService
                          .fetchEmployeeByEmail(email);
                      debugPrint('Created employee record: $createdRecord');
                    } catch (e) {
                      debugPrint('Error fetching created employee: $e');
                    }

                    // RE-LOGIN TO ADMIN ACCOUNT
                    // Because registerWithEmail above auto-logged into the new employee account
                    debugPrint(
                      'Current user before re-login attempt: ${_authService.currentUser?.email}',
                    );

                    if (createdByAdminEmail.isNotEmpty &&
                        adminPassword.isNotEmpty) {
                      // Force sign out first to clear any existing session
                      try {
                        debugPrint(
                          'Signing out current user before re-login...',
                        );
                        await _authService.signOut();
                        await Future.delayed(
                          const Duration(milliseconds: 1000),
                        ); // Wait longer
                        debugPrint(
                          'Sign out completed. Current user: ${_authService.currentUser?.email}',
                        );
                      } catch (signOutErr) {
                        debugPrint(
                          'Sign out error (may be expected): $signOutErr',
                        );
                      }

                      // Now try to sign back in as admin
                      try {
                        debugPrint(
                          'Attempting to sign in as admin: $createdByAdminEmail',
                        );
                        final adminCredential = await _authService
                            .signInWithEmailAndPassword(
                              createdByAdminEmail,
                              adminPassword,
                            );
                        debugPrint(
                          'Admin sign-in successful: ${adminCredential.user?.email}',
                        );

                        // Double-check the current user
                        await Future.delayed(const Duration(milliseconds: 500));
                        final verifiedUser = _authService.currentUser;
                        debugPrint(
                          'Verified current user after admin login: ${verifiedUser?.email}',
                        );

                        if (verifiedUser?.email == createdByAdminEmail) {
                          debugPrint('SUCCESS: Admin session restored');
                        } else {
                          debugPrint(
                            'WARNING: Current user is still not admin: ${verifiedUser?.email}',
                          );
                        }
                      } catch (reLoginErr) {
                        debugPrint('Admin re-login failed: $reLoginErr');
                        // Show error but continue
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Karyawan berhasil ditambahkan, namun sesi admin terganggu. Silakan login ulang.',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      }
                    } else {
                      debugPrint(
                        'Cannot re-login: adminEmail="$createdByAdminEmail", password empty=${adminPassword.isEmpty}',
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Karyawan berhasil ditambahkan, namun tidak dapat memulihkan sesi admin.',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    }

                    // Reload dari backend untuk konsistensi
                    await _loadData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Data karyawan berhasil ditambahkan'),
                        ),
                      );
                    }
                  }
                }

                Navigator.pop(context);
              },
              child: Text(isEdit ? 'Simpan' : 'Tambah'),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  // DELETE EMPLOYEE
  // =====================================================================

  void _deleteEmployee(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: const Text('Hapus karyawan ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final ok = await _employeeService.deleteEmployee(id);
              if (mounted) {
                if (ok) {
                  await _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Karyawan berhasil dihapus')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        kIsWeb
                            ? 'Fitur hapus tidak tersedia di web. Silakan gunakan aplikasi mobile/desktop.'
                            : 'Gagal menghapus karyawan',
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
                Navigator.pop(context);
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // UI
  // =====================================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: const Center(child: CircularProgressIndicator()));
    }

    if (_loadError.isNotEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final divisionOptions = ['Semua'] + _divisions.map((d) => d.name).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditEmployee(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),

      body: Column(
        children: [
          // SEARCH & FILTER
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Cari nama atau email...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _filterStatus,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: _statuses
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _filterStatus = v ?? 'Semua'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: divisionOptions.contains(_filterDivision)
                            ? _filterDivision
                            : 'Semua',
                        decoration: InputDecoration(
                          labelText: 'Divisi',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: divisionOptions
                            .map(
                              (d) => DropdownMenuItem(value: d, child: Text(d)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _filterDivision = v ?? 'Semua'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // SUMMARY CARDS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _miniStatCard(
                  title: 'Aktif',
                  value: _employees
                      .where((e) => e['status'] == 'Aktif')
                      .length
                      .toString(),
                  color: Colors.green,
                ),
                const SizedBox(width: 10),
                _miniStatCard(
                  title: 'Ditemukan',
                  value: _filteredEmployees.length.toString(),
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                _miniStatCard(
                  title: 'Non-Aktif',
                  value:
                      (_employees.length -
                              _employees
                                  .where((e) => e['status'] == 'Aktif')
                                  .length)
                          .toString(),
                  color: Colors.red,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // EMPLOYEE LIST
          Expanded(
            child: _filteredEmployees.isEmpty
                ? Center(
                    child: Text(
                      'Tidak ada data',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _filteredEmployees.length,
                    itemBuilder: (context, i) {
                      final e = _filteredEmployees[i];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: AvatarHelper.buildSimpleAvatar(
                            avatarPath:
                                e['avatarPath'] ?? 'assets/karyawan1.jpeg',
                            radius: 26,
                          ),
                          title: Text(
                            e['name'],
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${e['position']} • ${e['division']} • ${_getLocationName(e)}',
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') _addOrEditEmployee(employee: e);
                              if (v == 'delete') _deleteEmployee(e['id']);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Hapus'),
                              ),
                            ],
                          ),
                          onTap: () => _showDetailsBottomSheet(e),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // MINI CARD
  // =====================================================================

  Widget _miniStatCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 6),
              Text(title, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================================
  // BOTTOM SHEET DETAILS
  // =====================================================================

  void _showDetailsBottomSheet(Map<String, dynamic> employee) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  AvatarHelper.buildSimpleAvatar(
                    avatarPath:
                        employee['avatarPath'] ?? 'assets/karyawan1.jpeg',
                    radius: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      employee['name'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              _detailRow('Email', employee['email'], Icons.email),
              const SizedBox(height: 8),
              _detailRow('Posisi', employee['position'], Icons.work),
              const SizedBox(height: 8),
              _detailRow('Divisi', employee['division'], Icons.business),
              const SizedBox(height: 8),
              _detailRow(
                'Lokasi',
                _getLocationName(employee),
                Icons.location_on,
              ),
              const SizedBox(height: 8),
              _detailRow(
                'Status',
                employee['status'],
                Icons.circle,
                color: employee['status'] == 'Aktif'
                    ? AppColors.success
                    : AppColors.error,
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _addOrEditEmployee(employee: employee);
                      },
                      child: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteEmployee(employee['id']);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                      ),
                      child: const Text('Hapus'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(
    String label,
    String value,
    IconData icon, {
    Color color = Colors.grey,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  String _getLocationName(Map<String, dynamic> employee) {
    final id = employee['locationId'];
    if (id != null) {
      final found = _locations.where((l) => l.id == id).toList();
      if (found.isNotEmpty) return found.first.name;
    }
    return employee['lokasi'] ?? '-';
  }
}
