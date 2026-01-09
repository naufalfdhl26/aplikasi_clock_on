import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../utils/theme/app_theme.dart';
import '../../data/models/division_model.dart';
import '../../data/services/division_service.dart';
import '../../data/services/employee_service.dart';
import '../../data/models/employee_model.dart';

class DivisionManagementScreen extends StatefulWidget {
  const DivisionManagementScreen({super.key});

  @override
  State<DivisionManagementScreen> createState() =>
      _DivisionManagementScreenState();
}

class _DivisionManagementScreenState extends State<DivisionManagementScreen> {
  final DivisionService _service = DivisionService();
  final EmployeeService _employeeService = EmployeeService();
  final List<DivisionModel> _divisions = [];
  final List<DivisionModel> _filteredDivisions = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDivisions();
    _searchController.addListener(_filterDivisions);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDivisions() async {
    setState(() => _isLoading = true);
    final list = await _service.fetchAllDivisions();
    setState(() {
      _divisions.clear();
      _divisions.addAll(list);
      _filterDivisions();
      _isLoading = false;
    });
  }

  void _filterDivisions() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredDivisions.clear();
      if (query.isEmpty) {
        _filteredDivisions.addAll(_divisions);
      } else {
        _filteredDivisions.addAll(
          _divisions.where((div) => div.name.toLowerCase().contains(query)),
        );
      }
    });
  }

  void _addOrEditDivision({DivisionModel? current}) {
    final controller = TextEditingController(text: current?.name ?? '');
    String errorText = '';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(current == null ? "Tambah Divisi" : "Edit Divisi"),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: "Nama Divisi",
              errorText: errorText.isNotEmpty ? errorText : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isEmpty) {
                  setState(() => errorText = 'Nama divisi tidak boleh kosong');
                  return;
                }

                // Check for duplicate names (case-insensitive)
                // Fetch latest list from server to avoid race conditions
                final latest = await _service.fetchAllDivisions();
                final exists = latest.any(
                  (d) =>
                      d.name.trim().toLowerCase() == text.toLowerCase() &&
                      (current == null || d.id != current.id),
                );
                if (exists) {
                  setState(() => errorText = 'Nama divisi sudah ada');
                  return;
                }

                setState(() => errorText = '');
                Navigator.pop(context);

                setState(() => _isLoading = true);

                if (current == null) {
                  final model = DivisionModel(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: text,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  final created = await _service.createDivision(model);
                  if (created != null) {
                    setState(() {
                      _divisions.add(created);
                      _filterDivisions();
                    });
                  }
                } else {
                  final updated = DivisionModel(
                    id: current.id,
                    name: text,
                    createdAt: current.createdAt,
                    updatedAt: DateTime.now(),
                  );
                  final ok = await _service.updateDivision(updated);
                  if (ok) {
                    final i = _divisions.indexWhere((e) => e.id == current.id);
                    if (i != -1) {
                      setState(() {
                        _divisions[i] = updated;
                        _filterDivisions();
                      });
                    }
                  }
                }

                setState(() => _isLoading = false);
              },
              child: Text(current == null ? "Tambah" : "Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteDivision(DivisionModel model) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Hapus Divisi?"),
        content: Text("Divisi '${model.name}' akan dihapus."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              final ok = await _service.deleteDivision(model.id);
              if (mounted) {
                if (ok) {
                  setState(
                    () => _divisions.removeWhere((d) => d.id == model.id),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Divisi berhasil dihapus')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        kIsWeb
                            ? 'Fitur hapus tidak tersedia di web. Silakan gunakan aplikasi mobile/desktop.'
                            : 'Gagal menghapus divisi',
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              }
              setState(() => _isLoading = false);
            },
            child: const Text("Hapus"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // HEADER
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "Kelola Divisi",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => _addOrEditDivision(),
                      icon: const Icon(Icons.add),
                      label: const Text("Tambah Divisi"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Cari divisi...",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredDivisions.isEmpty
                ? const Center(child: Text('Tidak ada divisi ditemukan'))
                : ListView.builder(
                    itemCount: _filteredDivisions.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (_, i) {
                      final div = _filteredDivisions[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(
                            div.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          onTap: () => _openDivisionDetail(div),
                          trailing: PopupMenuButton(
                            onSelected: (v) {
                              if (v == 'edit') _addOrEditDivision(current: div);
                              if (v == 'delete') _deleteDivision(div);
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text("Edit"),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text("Hapus"),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _openDivisionDetail(DivisionModel division) {
    final futureEmployees = _employeeService
        .fetchAllEmployees()
        .then((list) {
          final name = division.name.trim().toLowerCase();
          return list
              .where((e) => e.division.trim().toLowerCase() == name)
              .toList();
        })
        .catchError((e) {
          debugPrint(
            'Error fetching employees for division ${division.name}: $e',
          );
          return <EmployeeModel>[];
        });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: DivisionEmployeeSheet(
          divisionName: division.name,
          employeesFuture: futureEmployees,
        ),
      ),
    );
  }
}

class DivisionEmployeeSheet extends StatelessWidget {
  final String divisionName;
  final Future<List<EmployeeModel>> employeesFuture;

  const DivisionEmployeeSheet({
    super.key,
    required this.divisionName,
    required this.employeesFuture,
  });

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
                  'Divisi: $divisionName',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<EmployeeModel>>(
            future: employeesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SizedBox(
                  height: 160,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }

              if (snapshot.hasError) {
                return SizedBox(
                  height: 160,
                  child: Center(child: Text('Gagal memuat daftar karyawan')),
                );
              }

              final items = snapshot.data ?? [];

              if (items.isEmpty) {
                return SizedBox(
                  height: 160,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.person_off, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          'Belum ada karyawan di divisi ini',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final e = items[i];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
                        ),
                      ),
                      title: Text(e.name),
                      subtitle: Text('ID: ${e.id}'),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
