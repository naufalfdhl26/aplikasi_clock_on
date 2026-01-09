import 'package:flutter/material.dart';
import '../../utils/theme/app_theme.dart';
import '../../utils/avatar_helper.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/permission_service.dart';
import '../../data/services/location_service.dart';
import '../../restapi.dart';
import '../../config.dart';

class EmployeeProfileScreen extends StatefulWidget {
  const EmployeeProfileScreen({super.key});

  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  final AuthService _authService = AuthService();
  final PermissionService _permission = PermissionService();
  final DataService _api = DataService();
  final LocationService _locationService = LocationService();

  String _name = 'Karyawan';
  String _nip = 'EMP-00001';
  String _email = 'employee@email.com';
  String _phone = '-';
  String _division = '-';
  String _position = '-';
  String _office = '-';
  String _avatarPath = 'assets/karyawan1.jpeg'; // default avatar
  String? _employeeId;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = _authService.currentUser;
    if (user == null) return;
    final emp = await _authService.fetchEmployeeByEmail(user.email ?? '');
    if (emp != null) {
      // Fetch location name if locationId exists
      String officeName = '-';
      final locationId = emp['locationId'] ?? emp['location_id'];
      if (locationId != null && locationId.toString().isNotEmpty) {
        try {
          final locations = await _locationService.fetchAllLocations();
          final location = locations
              .where((l) => l.id == locationId.toString())
              .toList();
          if (location.isNotEmpty) {
            officeName = location.first.name;
          }
        } catch (e) {
          debugPrint('Error fetching location: $e');
        }
      }

      setState(() {
        _name = emp['name'] ?? emp['nama'] ?? _name;
        _nip = emp['nip'] ?? emp['id'] ?? _nip;
        _email = (emp['email'] ?? user.email ?? _email).toString();
        _phone = emp['phone'] ?? _phone;
        _division = emp['division'] ?? emp['divisi'] ?? _division;
        _position = emp['position'] ?? emp['jabatan'] ?? _position;
        _office = officeName;
        _avatarPath =
            emp['avatarPath'] ?? emp['avatar_path'] ?? 'assets/karyawan1.jpeg';
        _employeeId = emp['id']?.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          // Photo Profile Section dengan Avatar - Clickable untuk view
          GestureDetector(
            onTap: _viewAvatar,
            child: Stack(
              children: [
                AvatarHelper.buildAvatar(
                  avatarPath: _avatarPath,
                  radius: 65,
                  showBorder: true,
                ),
                // Edit button pada avatar
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _editAvatar,
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(8),
                      child: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(_position, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          _buildInfoRow('NIP / ID', _nip),
          _buildInfoRow('Email', _email),
          _buildInfoRowWithEdit('No. Telepon', _phone, _editPhone),
          _buildInfoRow('Divisi', _division),
          _buildInfoRow('Jabatan', _position),
          _buildInfoRow('Lokasi Kantor', _office),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              await _authService.signOut();
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (r) => false,
              );
            },
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowWithEdit(
    String label,
    String value,
    VoidCallback onEdit,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.edit,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editPhone() async {
    final phoneController = TextEditingController(text: _phone);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit No. Telepon'),
        content: TextField(
          controller: phoneController,
          decoration: const InputDecoration(labelText: 'No. Telepon'),
          keyboardType: TextInputType.phone,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_employeeId == null || _employeeId!.isEmpty) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Employee ID tidak ditemukan')),
                );
                return;
              }

              await _api.updateId(
                'phone',
                phoneController.text.trim(),
                token,
                project,
                'employee',
                appid,
                _employeeId!,
              );

              setState(() {
                _phone = phoneController.text.trim();
              });

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No. Telepon berhasil diperbarui'),
                ),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _viewAvatar() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar besar tanpa animasi
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: AvatarHelper.buildSimpleAvatar(
                  avatarPath: _avatarPath,
                  radius: 80,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _position,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              const SizedBox(height: 24),
              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Tutup'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.black87,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _editAvatar();
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Ubah'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editAvatar() async {
    await showDialog(
      context: context,
      builder: (_) {
        String tempAvatarPath = _avatarPath;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Pilih Avatar'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: AvatarHelper.availableAvatars.length,
                itemBuilder: (context, index) {
                  final avatarPath = AvatarHelper.availableAvatars[index];
                  final isSelected = tempAvatarPath == avatarPath;
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        tempAvatarPath = avatarPath;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.grey.shade300,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: ClipOval(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Image.asset(
                            avatarPath,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_employeeId == null || _employeeId!.isEmpty) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Employee ID tidak ditemukan'),
                      ),
                    );
                    return;
                  }

                  await _api.updateId(
                    'avatarPath',
                    tempAvatarPath,
                    token,
                    project,
                    'employee',
                    appid,
                    _employeeId!,
                  );

                  setState(() {
                    _avatarPath = tempAvatarPath;
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Avatar berhasil diperbarui')),
                  );
                },
                child: const Text('Simpan'),
              ),
            ],
          ),
        );
      },
    );
  }
}
