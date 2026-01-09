import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../data/services/auth_service.dart';
import '../../restapi.dart';
import '../../config.dart';
import '../../routes/app_routes.dart';
import '../../utils/theme/app_theme.dart';

class AdminRegisterScreen extends StatefulWidget {
  const AdminRegisterScreen({super.key});

  @override
  State<AdminRegisterScreen> createState() => _AdminRegisterScreenState();
}

class _AdminRegisterScreenState extends State<AdminRegisterScreen> {
  final nameC = TextEditingController();
  final emailC = TextEditingController();
  final passC = TextEditingController();
  final companyC = TextEditingController();
  final AuthService _auth = AuthService();
  final DataService _api = DataService();
  bool _isLoading = false;
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4C1D95), Colors.white],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 360,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Buat Akun Admin",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.neutralDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Isi data admin perusahaan Anda",
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.neutralGray,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _inputField("Nama Admin", nameC, icon: Icons.person),
                        const SizedBox(height: 14),
                        _inputField("Email", emailC, icon: Icons.email),
                        const SizedBox(height: 14),
                        _inputField(
                          "Password",
                          passC,
                          isPassword: true,
                          icon: Icons.lock,
                        ),
                        const SizedBox(height: 14),
                        _inputField(
                          "Nama Perusahaan",
                          companyC,
                          icon: Icons.business,
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () async {
                                    setState(() => _isLoading = true);
                                    try {
                                      // 1) Create Firebase user
                                      await _auth.registerWithEmail(
                                        emailC.text.trim(),
                                        passC.text,
                                      );

                                      // 2) Insert admin to GoCloud API
                                      final now = DateTime.now();
                                      final createdAt = DateFormat(
                                        'yyyy-MM-ddTHH:mm:ss',
                                      ).format(now);
                                      debugPrint(
                                        '=== Registering Admin to GoCloud ===',
                                      );
                                      debugPrint(
                                        '  Email: ${emailC.text.trim()}',
                                      );
                                      debugPrint(
                                        '  Name: ${nameC.text.trim()}',
                                      );
                                      debugPrint(
                                        '  Company: ${companyC.text.trim()}',
                                      );
                                      debugPrint('  CreatedAt: $createdAt');
                                      final adminInsertResponse = await _api
                                          .insertAdmin(
                                            appid,
                                            nameC.text.trim(),
                                            emailC.text.trim(),
                                            passC.text.trim(),
                                            companyC.text.trim(),
                                            createdAt,
                                          );
                                      debugPrint(
                                        'Admin insertAdmin response: $adminInsertResponse',
                                      );

                                      if (adminInsertResponse == null ||
                                          adminInsertResponse == '[]') {
                                        throw Exception(
                                          'Admin registration failed: empty or null response from GoCloud',
                                        );
                                      }

                                      Navigator.pop(context);
                                    } catch (e) {
                                      final msg = (e is FirebaseAuthException)
                                          ? _authErrorMessage(e)
                                          : 'Pendaftaran gagal: $e';
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text(msg)),
                                      );
                                    } finally {
                                      setState(() => _isLoading = false);
                                    }
                                  },
                            child: const Text(
                              "Daftar",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        Center(
                          child: TextButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(
                                context,
                                AppRoutes.adminLoginScreen,
                              );
                            },
                            child: const Text(
                              "Kembali ke Login Admin",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField(
    String label,
    TextEditingController controller, {
    bool isPassword = false,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.neutralDark,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isPassword && !_showPassword,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            prefixIcon: icon != null
                ? Icon(icon, color: AppColors.neutralGray)
                : null,
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Email sudah terdaftar.';
      case 'weak-password':
        return 'Password terlalu lemah.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'operation-not-allowed':
        return 'Tipe pendaftaran tidak diizinkan pada server. Periksa pengaturan Firebase.';
      case 'invalid-credential':
        return 'Kredensial tidak valid. Periksa input Anda.';
      default:
        return 'Pendaftaran gagal: ${e.message ?? e.code}';
    }
  }
}
