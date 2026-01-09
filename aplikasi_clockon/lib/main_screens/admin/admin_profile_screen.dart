import 'package:flutter/material.dart';
import '../../../utils/theme/app_theme.dart';
import '../../../utils/avatar_helper.dart';
import '../../data/services/auth_service.dart';
import '../../restapi.dart';
import '../../config.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final AuthService _authService = AuthService();
  final DataService _api = DataService();

  String _name = 'Nama Admin';
  String _email = 'admin@email.com';
  String _phone = '+62 812 3456 7890';
  static const String _avatarPath = 'assets/admin1.jpg'; // avatar static admin
  String? _adminId;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _authService.currentUser;
    if (user == null) return;
    final admin = await _authService.fetchAdminByEmail(user.email ?? '');
    if (admin != null) {
      setState(() {
        _name = admin['name'] ?? _name;
        _email = admin['email'] ?? _email;
        _phone = admin['phone'] ?? _phone;
        _adminId = admin['id']?.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Avatar berdasarkan pilihan
              AvatarHelper.buildAvatar(
                avatarPath: _avatarPath,
                radius: 55,
                showBorder: true,
              ),

              const SizedBox(height: 12),
              Text(
                _name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),

              // Informasi Admin
              _infoTile("Nama Lengkap", _name),
              _infoTile("Email", _email),
              _infoTile("Nomor Telepon", _phone),

              const SizedBox(height: 40),

              // Tombol Aksi
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    await _showEditDialog();
                  },
                  label: const Text("Edit Profil"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTile(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey.shade100,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog() async {
    final nameController = TextEditingController(text: _name);
    final phoneController = TextEditingController(text: _phone);
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Edit Profil Admin',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nama',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: 'No. Telepon',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () async {
                      if (_adminId == null) return;

                      final phone = phoneController.text.trim();
                      if (!RegExp(r'^\d+$').hasMatch(phone)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Nomor telepon tidak valid')),
                        );
                        return;
                      }

                      // Update name/phone via API
                      await _api.updateId(
                        'name',
                        nameController.text.trim(),
                        token,
                        project,
                        'admin',
                        appid,
                        _adminId!,
                      );
                      await _api.updateId(
                        'phone',
                        phone,
                        token,
                        project,
                        'admin',
                        appid,
                        _adminId!,
                      );
                      setState(() {
                        _name = nameController.text.trim();
                        _phone = phone;
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Simpan'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
