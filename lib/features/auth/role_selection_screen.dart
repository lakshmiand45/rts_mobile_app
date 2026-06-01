import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../dashboard/dashboard_screen.dart';
import '../food_request/food_request_screen.dart';
import '../food_request/food_subscription_screen.dart';
import '../../providers/food_provider.dart';
import '../auth/login_screen.dart';

class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final availableRoles = authState.availableRoles ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05), 
                  blurRadius: 20, 
                  offset: const Offset(0, 10)
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
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
                        'Select Your Role',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8), 
                          fontSize: 14, 
                          fontWeight: FontWeight.w500
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AVAILABLE ROLES',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      if (authState.isLoading)
                        const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
                      else if (availableRoles.isEmpty)
                        const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No roles assigned to this account')))
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: availableRoles.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = availableRoles[index];
                            final role = item['role']?.toString() ?? 'N/A';
                            final dept = item['dept']?.toString() ?? 'N/A';

                            return InkWell(
                              onTap: () => _handleRoleSelection(item),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE2E8F0),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.person_outline,
                                        size: 20,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            role,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                          Text(
                                            dept,
                                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () async {
                            await ref.read(authProvider.notifier).logout();
                            if (mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (context) => const LoginScreen()),
                                (route) => false,
                              );
                            }
                          },
                          child: const Text('Back to Login', style: TextStyle(color: Colors.red)),
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
    );
  }

  Future<void> _handleRoleSelection(Map<String, dynamic> roleItem) async {
    final Map<String, dynamic> result = await ref.read(authProvider.notifier).selectRole(roleItem);

    if (!mounted) return;

    if (result['success'] == true) {
      final user = ref.read(authProvider).user;
      final bool isIntern = user?.role.toLowerCase().contains('intern') ?? false;
      final bool isBangalore = user?.location.toLowerCase() == 'bangalore';

      if (isIntern) {
        if (isBangalore) {
          final foodState = ref.read(foodProvider);
          if (!foodState.hasSeenOnboarding) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const FoodRequestScreen()),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const FoodSubscriptionScreen()),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Access Denied: Food services are only available for Bangalore employees.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to select role. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
