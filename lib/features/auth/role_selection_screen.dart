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
  String? _selectedRoleName;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final List<dynamic> availableRoles = authState.availableRoles ?? [];

    // Group roles by name to identify those with multiple departments
    final Map<String, List<Map<String, dynamic>>> groupedRoles = {};
    for (var item in availableRoles) {
      final roleName = item['role']?.toString() ?? 'N/A';
      if (!groupedRoles.containsKey(roleName)) {
        groupedRoles[roleName] = [];
      }
      groupedRoles[roleName]!.add(Map<String, dynamic>.from(item));
    }

    final uniqueRoleNames = groupedRoles.keys.toList();

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
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with Gradient
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF4F46E5), Color(0xFF3730A3)],
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'TELE-RTS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedRoleName == null ? 'Select your active role' : _selectedRoleName!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      if (_selectedRoleName == null) ...[
                        // Step 1: Role Selection
                        Text(
                          'Your account has multiple roles. Choose how you\'d like to work today.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: const Color(0xFF475569), // Slate 600
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (authState.isLoading)
                          const Center(child: CircularProgressIndicator())
                        else if (uniqueRoleNames.isEmpty)
                          const Text('No roles assigned')
                        else
                          ...uniqueRoleNames.map((roleName) {
                            final roles = groupedRoles[roleName]!;
                            final bool hasMultiple = roles.length > 1;
                            final String subtitle = hasMultiple
                                ? '${roles.length} departments available'
                                : roles.first['dept']?.toString() ?? 'N/A';

                            return _buildRoleCard(
                              title: roleName,
                              subtitle: subtitle,
                              icon: _getIconForRole(roleName),
                              color: _getColorForRole(roleName),
                              showArrow: hasMultiple,
                              onTap: () {
                                if (hasMultiple) {
                                  setState(() => _selectedRoleName = roleName);
                                } else {
                                  _handleRoleSelection(roles.first);
                                }
                              },
                            );
                          }).toList(),
                      ] else ...[
                        // Step 2: Department Selection for the selected role
                        GestureDetector(
                          onTap: () => setState(() => _selectedRoleName = null),
                          child: Row(
                            children: [
                              const Icon(Icons.chevron_left, color: Color(0xFF4F46E5), size: 20),
                              const SizedBox(width: 4),
                              const Text(
                                'All Roles',
                                style: TextStyle(
                                  color: Color(0xFF4F46E5),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(fontSize: 14, color: Color(0xFF475569)), // Slate 600
                            children: [
                              const TextSpan(text: 'Select a department for '),
                              TextSpan(
                                text: _selectedRoleName,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ...groupedRoles[_selectedRoleName!]!.map((roleItem) {
                          return _buildDepartmentCard(
                            deptName: roleItem['dept']?.toString() ?? 'N/A',
                            onTap: () => _handleRoleSelection(roleItem),
                          );
                        }).toList(),
                      ],
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () async {
                          await ref.read(authProvider.notifier).logout();
                          if (mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                              (route) => false,
                            );
                          }
                        },
                        child: const Text(
                          '← Back to login',
                          style: TextStyle(
                            color: Color(0xFF94A3B8), // Slate 400
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
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
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool showArrow,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B), // Slate 500
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (showArrow)
                const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1), size: 20), // Slate 300
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentCard({
    required String deptName,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.location_on_outlined, color: Color(0xFF4F46E5), size: 24),
              ),
              const SizedBox(width: 16),
              Text(
                deptName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForRole(String role) {
    final r = role.toLowerCase();
    if (r.contains('requestor')) return Icons.person_outline;
    if (r.contains('reporting manager')) return Icons.group_outlined;
    if (r.contains('head of department')) return Icons.shield_outlined;
    return Icons.account_circle_outlined;
  }

  Color _getColorForRole(String role) {
    final r = role.toLowerCase();
    if (r.contains('requestor')) return const Color(0xFF4F46E5);
    if (r.contains('reporting manager')) return const Color(0xFF7C3AED);
    if (r.contains('head of department')) return const Color(0xFF92400E);
    return const Color(0xFF64748B);
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
