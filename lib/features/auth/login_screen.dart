import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../dashboard/dashboard_screen.dart';
import '../food_request/food_request_screen.dart';
import 'reset_password_screen.dart';
import 'role_selection_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isForgotPasswordView = false;
  bool _isResetEmailSent = false;
  List<String> _recentEmails = [];

  @override
  void initState() {
    super.initState();
    _loadRecentEmails();
  }

  Future<void> _loadRecentEmails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentEmails = prefs.getStringList('recent_emails') ?? [];
    });
  }

  Future<void> _saveEmail(String email) async {
    if (email.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (!_recentEmails.contains(email)) {
      _recentEmails.add(email);
      await prefs.setStringList('recent_emails', _recentEmails);
      setState(() {});
    }
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final email = _usernameController.text.trim();
      final result = await ref.read(authProvider.notifier).login(
        email,
        _passwordController.text,
      );
      
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success']) {
        await _saveEmail(email);
        if (result['needsRoleSelection'] == true) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
          );
        } else {
          final user = ref.read(authProvider).user;
          final role = user?.role.toLowerCase();
          
          // Direct Interns to FoodRequestScreen as requested
          if (role == 'intern' || role == 'interns') {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const FoodRequestScreen()),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Login failed'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      final result = await ref.read(authProvider.notifier).forgotPassword(
        _usernameController.text.trim(),
      );
      
      if (!mounted) return;
      setState(() => _isLoading = false);
      
      if (result['success']) {
        setState(() {
          _isResetEmailSent = true;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: const BoxDecoration(
                    color: Color(0xFF5C59E8),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'RTS SYSTEM',
                        style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isForgotPasswordView ? 'Password Recovery' : 'Tele Education Portal',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
                  child: _isResetEmailSent 
                    ? _buildSuccessView()
                    : Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            if (_isForgotPasswordView) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: const Color(0xFF5C59E8).withOpacity(0.1), shape: BoxShape.circle),
                                child: const Icon(Icons.email_outlined, color: Color(0xFF5C59E8), size: 32),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Forgot your password?',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Enter your email and we\'ll send you a reset link.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.5),
                              ),
                              const SizedBox(height: 32),
                            ],

                            Autocomplete<String>(
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  return const Iterable<String>.empty();
                                }
                                return _recentEmails.where((String option) {
                                  return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                                });
                              },
                              onSelected: (String selection) {
                                _usernameController.text = selection;
                              },
                              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                if (controller.text != _usernameController.text) {
                                  controller.text = _usernameController.text;
                                }
                                
                                return TextFormField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  onChanged: (value) {
                                    _usernameController.text = value;
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Email address',
                                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                  ),
                                  validator: (value) => value == null || value.isEmpty ? 'Please enter email' : null,
                                  onFieldSubmitted: (value) => onFieldSubmitted(),
                                );
                              },
                              optionsViewBuilder: (context, onSelected, options) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4.0,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: 336,
                                      constraints: const BoxConstraints(maxHeight: 200),
                                      child: ListView.builder(
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        itemCount: options.length,
                                        itemBuilder: (context, index) {
                                          final String option = options.elementAt(index);
                                          return ListTile(
                                            leading: const Icon(Icons.history, size: 18, color: Color(0xFF94A3B8)),
                                            title: Text(option, style: const TextStyle(fontSize: 14)),
                                            onTap: () => onSelected(option),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            if (!_isForgotPasswordView) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: !_isPasswordVisible,
                                decoration: InputDecoration(
                                  hintText: 'Password',
                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                  suffixIcon: IconButton(
                                    icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: const Color(0xFF94A3B8), size: 20),
                                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                  ),
                                ),
                                validator: (value) => value == null || value.isEmpty ? 'Please enter password' : null,
                              ),
                            ],

                            const SizedBox(height: 24),

                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : (_isForgotPasswordView ? _handleForgotPassword : _handleLogin),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5C59E8),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: _isLoading 
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Text(_isForgotPasswordView ? 'Send Reset Link' : 'Login', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),

                            const SizedBox(height: 24),

                            if (!_isForgotPasswordView)
                              TextButton(
                                onPressed: () => setState(() => _isForgotPasswordView = true),
                                child: const Text('Forgot password?', style: TextStyle(color: Color(0xFF5C59E8), fontWeight: FontWeight.w600)),
                              )
                            else
                              TextButton.icon(
                                onPressed: () => setState(() => _isForgotPasswordView = false),
                                icon: const Icon(Icons.arrow_back, size: 16, color: Color(0xFF64748B)),
                                label: const Text('Back to login', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                              ),
                          ],
                        ),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 48),
        ),
        const SizedBox(height: 24),
        const Text(
          'Check your email',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 16),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.6),
            children: [
              const TextSpan(text: 'If '),
              TextSpan(
                text: _usernameController.text.trim(),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const TextSpan(text: ' is registered, you\'ll receive a reset link shortly. It expires in '),
              const TextSpan(
                text: '1 hour.',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Didn\'t receive it? Check your spam folder.',
          style: TextStyle(color: Colors.grey[500], fontSize: 13),
        ),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: () => setState(() {
            _isForgotPasswordView = false;
            _isResetEmailSent = false;
            _usernameController.clear();
          }),
          icon: const Icon(Icons.arrow_back, size: 16, color: Color(0xFF5C59E8)),
          label: const Text('Back to login', style: TextStyle(color: Color(0xFF5C59E8), fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
