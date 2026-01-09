import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/services/auth_service.dart';
import '../../routes/app_routes.dart';
import '../../utils/theme/app_theme.dart';

class EmployeeLoginScreen extends StatefulWidget {
  const EmployeeLoginScreen({super.key});

  @override
  State<EmployeeLoginScreen> createState() => _EmployeeLoginScreenState();
}

class _EmployeeLoginScreenState extends State<EmployeeLoginScreen> {
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
            padding: const EdgeInsets.all(24),
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'assets/clockon.png',
                  height: 180,
                  width: 180,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),

                const Text(
                  "Selamat Datang",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.neutralDark,
                  ),
                ),

                const SizedBox(height: 6),
                const Text(
                  "Silakan masuk untuk melanjutkan",
                  style: TextStyle(fontSize: 14, color: AppColors.neutralGray),
                ),

                const SizedBox(height: 30),

                _inputField("Email", emailC, icon: Icons.email),
                const SizedBox(height: 14),

                _inputField(
                  "Password",
                  passC,
                  isPassword: true,
                  icon: Icons.lock,
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            setState(() => _isLoading = true);
                            try {
                              final email = emailC.text.trim();
                              final password = passC.text;
                              if (email.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Silakan masukkan email.'),
                                  ),
                                );
                                return;
                              }
                              if (password.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Silakan masukkan password.'),
                                  ),
                                );
                                return;
                              }
                              if (password.length < 6) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Password minimal 6 karakter.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              // Attempt sign-in directly
                              try {
                                await _auth.signInWithEmailAndPassword(
                                  email,
                                  password,
                                );
                              } on FirebaseAuthException catch (authErr) {
                                // If user not found, try to create account first
                                if (authErr.code == 'user-not-found') {
                                  debugPrint(
                                    'Employee account not found in Firebase, creating...',
                                  );
                                  try {
                                    await _auth.registerWithEmail(
                                      email,
                                      password,
                                    );
                                    debugPrint(
                                      'Employee Firebase account created successfully',
                                    );
                                  } catch (regErr) {
                                    if (regErr is FirebaseAuthException &&
                                        regErr.code == 'email-already-in-use') {
                                      // Account exists but wrong password
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Email dan password tidak cocok',
                                          ),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Gagal membuat akun: $regErr',
                                          ),
                                        ),
                                      );
                                    }
                                    return;
                                  }
                                } else {
                                  // Other auth error
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Login gagal: ${authErr.message ?? authErr.code}',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                              }

                              // Fetch employee record from backend
                              final employee = await _auth.fetchEmployeeByEmail(
                                emailC.text.trim(),
                              );
                              if (employee == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Akun tidak ditemukan pada sistem perusahaan',
                                    ),
                                  ),
                                );
                                await _auth.signOut();
                                return;
                              }

                              Navigator.pushReplacementNamed(
                                context,
                                AppRoutes.employeeDashboard,
                              );
                            } catch (e) {
                              if (e is FirebaseAuthException) {
                                debugPrint(
                                  'Employee sign-in error: ${e.code} ${e.message}',
                                );
                              } else {
                                debugPrint('Employee sign-in exception: $e');
                              }
                              final msg = (e is FirebaseAuthException)
                                  ? _authErrorMessage(e)
                                  : 'Login gagal: $e';
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(msg)));
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
                            AppRoutes.adminLoginScreen,
                          );
                        },
                        child: const Text(
                          "Masuk sebagai Admin",
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
