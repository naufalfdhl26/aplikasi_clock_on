import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../data/models/location_model.dart';
import '../../data/services/location_service.dart';

class OfficeManagementScreen extends StatefulWidget {
  const OfficeManagementScreen({super.key});

  @override
  State<OfficeManagementScreen> createState() => _OfficeManagementScreenState();
}

class _OfficeManagementScreenState extends State<OfficeManagementScreen> {
  final List<LocationModel> offices = [];
  final LocationService _location = LocationService();
  bool _isLoading = false;

  // Search state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<LocationModel> get _visibleOffices {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return offices;
    return offices.where((o) {
      final name = o.name.toLowerCase();
      final addr = (o.address ?? '').toLowerCase();
      final ssid = (o.ssid ?? []).join(' ').toLowerCase();
      return name.contains(q) || addr.contains(q) || ssid.contains(q);
    }).toList();
  }

  void _addOffice(LocationModel model) async {
    setState(() => _isLoading = true);
    final created = await _location.createLocation(model);
    if (created != null) {
      await _loadLocations();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan lokasi ke server')),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  void _updateOffice(String id, LocationModel updated) async {
    setState(() => _isLoading = true);
    final ok = await _location.updateLocation(updated);
    if (ok) {
      await _loadLocations();
    }
    setState(() => _isLoading = false);
  }

  void _removeOffice(String id) async {
    setState(() => _isLoading = true);
    final ok = await _location.deleteLocation(id);
    if (mounted) {
      if (ok) {
        await _loadLocations();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lokasi berhasil dihapus')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kIsWeb
                  ? 'Fitur hapus tidak tersedia di web. Silakan gunakan aplikasi mobile/desktop.'
                  : 'Gagal menghapus lokasi',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  // dialog create / edit
  void _showOfficeDialog({LocationModel? data}) {
    final isEdit = data != null;
    final nameC = TextEditingController(text: data?.name ?? "");
    final addrC = TextEditingController(text: data?.address ?? "");
    final ssidC = TextEditingController(text: (data?.ssid ?? []).join(', '));
    final bssidC = TextEditingController(text: (data?.bssid ?? []).join(', '));

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? "Edit Lokasi WiFi" : "Tambah Lokasi WiFi"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              _field(nameC, "Nama Lokasi"),
              const SizedBox(height: 10),
              _field(addrC, "Alamat"),
              const SizedBox(height: 10),
              _field(ssidC, "SSID (pisahkan koma)"),
              const SizedBox(height: 10),
              _field(bssidC, "BSSID (pisahkan koma)"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameC.text.trim().isEmpty || addrC.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nama dan alamat wajib diisi')),
                );
                return;
              }

              final trimmedName = nameC.text.trim();
              final trimmedAddr = addrC.text.trim();

              if (!isEdit) {
                // Check for duplicate name when adding
                final isDuplicate = offices.any((o) => o.name.trim().toLowerCase() == trimmedName.toLowerCase());
                if (isDuplicate) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nama lokasi sudah ada, silakan gunakan nama yang berbeda')),
                  );
                  return;
                }
              }

              final ssid = ssidC.text.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
              final bssid = bssidC.text
                  .split(',')
                  .map((x) => x.trim())
                  .where((x) => x.isNotEmpty)
                  .toList();

              if (isEdit) {
                _updateOffice(
                  data.id,
                  LocationModel(
                    id: data.id,
                    name: trimmedName,
                    address: trimmedAddr,
                    latitude: data.latitude,
                    longtitude: data.longtitude,
                    radius: data.radius,
                    ssid: ssid,
                    bssid: bssid,
                  ),
                );
              } else {
                _addOffice(
                  LocationModel(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: trimmedName,
                    address: trimmedAddr,
                    latitude: 0,
                    longtitude: 0,
                    ssid: ssid,
                    bssid: bssid,
                  ),
                );
              }

              Navigator.pop(context);
            },
            child: Text(isEdit ? "Simpan" : "Tambah"),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Safely format an SSID/BSSID value that may be a List<String> or String.
  /// Returns '-' when input is null or empty.
  String _formatWifiList(dynamic v) {
    if (v == null) return '-';
    if (v is String) {
      final s = v.trim();
      return s.isEmpty ? '-' : s;
    }
    if (v is List) {
      final list = v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      if (list.isEmpty) return '-';
      return list.join(', ');
    }
    final s = v.toString().trim();
    return s.isEmpty ? '-' : s;
  }

  void _showDetail(LocationModel x) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              x.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text("Alamat: ${x.address ?? '-'}"),
            const SizedBox(height: 10),
            Text("SSID: ${_formatWifiList(x.ssid)}"),
            Text("BSSID: ${_formatWifiList(x.bssid)}"),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showOfficeDialog(data: x);
                    },
                    child: const Text("Edit"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _removeOffice(x.id);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                    ),
                    child: const Text(
                      "Hapus",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showOfficeDialog(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLocations,
              child: offices.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height:
                            MediaQuery.of(context).size.height - kToolbarHeight,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.wifi_off,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Belum ada lokasi Wi‑Fi',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () => _showOfficeDialog(),
                                icon: const Icon(Icons.add),
                                label: const Text('Tambah Lokasi'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Cari lokasi...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onChanged: (v) => setState(() => _searchQuery = v),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _visibleOffices.isEmpty
                              ? SingleChildScrollView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  child: SizedBox(
                                    height: MediaQuery.of(context).size.height -
                                        kToolbarHeight -
                                        120,
                                    child: Center(
                                      child: Text(
                                        'Tidak ada lokasi cocok untuk "$_searchQuery"',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 8, 16, 88),
                                  itemCount: _visibleOffices.length,
                                  itemBuilder: (_, i) {
                                    final x = _visibleOffices[i];
                                    return Card(
                                      child: ListTile(
                                        leading: const Icon(Icons.wifi),
                                        title: Text(x.name),
                                        subtitle:
                                            Text("SSID: ${_formatWifiList(x.ssid)}"),
                                        onTap: () => _showDetail(x),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
            ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    setState(() => _isLoading = true);
    final list = await _location.fetchAllLocations();
    setState(() {
      offices.clear();
      offices.addAll(list);
      _isLoading = false;
    });
  }
}
