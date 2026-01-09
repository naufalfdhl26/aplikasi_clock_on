import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/services/auth_service.dart';
import '../../routes/app_routes.dart';
import '../../utils/theme/app_theme.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final emailC = TextEditingController();
  final passC = TextEditingController();
  final AuthService _auth = AuthService();
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
                        "Selamat Datang Admin",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.neutralDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Silakan masuk untuk mengelola absensi perusahaan",
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.neutralGray,
                        ),
                      ),
                      const SizedBox(height: 30),
                      _inputField("Email Admin", emailC, icon: Icons.email),
                      const SizedBox(height: 18),
                      _inputField(
                        "Password",
                        passC,
                        isPassword: true,
                        icon: Icons.lock,
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  setState(() => _isLoading = true);
                                  try {
                                    // Attempt sign-in directly; `FirebaseAuthException` will indicate 'user-not-found' or other issues
                                    await _auth.signInWithEmailAndPassword(
                                      emailC.text.trim(),
                                      passC.text,
                                    );
                                    Navigator.pushReplacementNamed(
                                      context,
                                      AppRoutes.adminDashboard,
                                    );
                                  } catch (e) {
                                    if (e is FirebaseAuthException) {
                                      debugPrint(
                                        'Admin sign-in error: ${e.code} ${e.message}',
                                      );
                                    } else {
                                      debugPrint('Admin sign-in exception: $e');
                                    }
                                    final msg = (e is FirebaseAuthException)
                                        ? _authErrorMessage(e)
                                        : 'Login Admin gagal: $e';
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(msg)),
                                    );
                                  } finally {
                                    setState(() => _isLoading = false);
                                  }
                                },
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "Masuk",
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.adminRegister,
                                );
                              },
                              child: const Text(
                                "Register Admin",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextButton(
                              onPressed: () {
                                Navigator.pushReplacementNamed(
                                  context,
                                  AppRoutes.login,
                                );
                              },
                              child: const Text(
                                "Kembali ke Login Karyawan",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
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
                    onPressed: () {
                      setState(() => _showPassword = !_showPassword);
                    },
                  )
                : null,
          ),
        ),
      ],
    );
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
        return 'Password salah. Silakan coba lagi.';
      case 'user-not-found':
        return 'Akun tidak ditemukan. Periksa email Anda.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'invalid-credential':
        return 'Kredensial tidak valid atau kadaluarsa. Coba masuk lagi atau reset kata sandi.';
      case 'operation-not-allowed':
        return 'Tipe autentikasi tidak diizinkan pada server, aktifkan metode Email/Password pada Firebase Console.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan masuk. Coba lagi nanti.';
      case 'user-disabled':
        return 'Akun telah dinonaktifkan.';
      default:
        return 'Login gagal: ${e.message ?? e.code}';
    }
  }
}
