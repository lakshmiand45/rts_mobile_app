import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/request_provider.dart';
import '../../auth/login_screen.dart';

class SwitchRoleModal extends ConsumerStatefulWidget {
  const SwitchRoleModal({super.key});

  @override
  ConsumerState<SwitchRoleModal> createState() => _SwitchRoleModalState();
}

class _SwitchRoleModalState extends ConsumerState<SwitchRoleModal> {
  String? _selectedRoleName;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final availableRoles = authState.availableRoles ?? [];
    final currentUser = authState.user;

    // Group roles by name
    final Map<String, List<Map<String, dynamic>>> groupedRoles = {};
    for (var item in availableRoles) {
      final roleName = item['role']?.toString() ?? 'N/A';
      if (!groupedRoles.containsKey(roleName)) {
        groupedRoles[roleName] = [];
      }
      groupedRoles[roleName]!.add(Map<String, dynamic>.from(item));
    }

    final uniqueRoleNames = groupedRoles.keys.toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'SWITCH ROLE',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),
            
            if (_selectedRoleName == null) ...[
              const Text(
                'SELECT A ROLE TO SWITCH',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: authState.isLoading
                    ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                    : uniqueRoleNames.isEmpty
                        ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No other roles available')))
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: uniqueRoleNames.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final roleName = uniqueRoleNames[index];
                              final roles = groupedRoles[roleName]!;
                              final bool hasMultiple = roles.length > 1;
                              
                              // Check if this role (single dept) is the current one
                              final bool isCurrent = !hasMultiple && 
                                  currentUser?.role == roleName && 
                                  currentUser?.department == roles.first['dept'];

                              final String subtitle = hasMultiple
                                  ? '${roles.length} departments available'
                                  : roles.first['dept']?.toString() ?? 'N/A';

                              return _buildRoleCard(
                                title: roleName,
                                subtitle: subtitle,
                                icon: _getIconForRole(roleName),
                                color: _getColorForRole(roleName),
                                showArrow: hasMultiple,
                                isCurrent: isCurrent,
                                onTap: () {
                                  if (hasMultiple) {
                                    setState(() => _selectedRoleName = roleName);
                                  } else if (!isCurrent) {
                                    _handleSwitch(roleName, roles.first['dept'].toString());
                                  }
                                },
                              );
                            },
                          ),
              ),
            ] else ...[
              // Department selection Step
              GestureDetector(
                onTap: () => setState(() => _selectedRoleName = null),
                child: const Row(
                  children: [
                    Icon(Icons.chevron_left, color: Color(0xFF4F46E5), size: 20),
                    SizedBox(width: 4),
                    Text(
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
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
                  children: [
                    const TextSpan(text: 'Select department for '),
                    TextSpan(
                      text: _selectedRoleName,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: groupedRoles[_selectedRoleName!]!.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final roleItem = groupedRoles[_selectedRoleName!]![index];
                    final deptName = roleItem['dept']?.toString() ?? 'N/A';
                    final isCurrent = currentUser?.role == _selectedRoleName && currentUser?.department == deptName;

                    return _buildDepartmentCard(
                      deptName: deptName,
                      isCurrent: isCurrent,
                      onTap: isCurrent ? null : () => _handleSwitch(_selectedRoleName!, deptName),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (mounted) {
                    Navigator.pop(context);
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                child: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
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
    required bool isCurrent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCurrent ? color.withOpacity(0.1) : color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrent ? color : color.withOpacity(0.1),
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isCurrent ? color : color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isCurrent ? Colors.white : color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isCurrent ? color : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isCurrent ? color.withOpacity(0.8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            if (isCurrent)
              Icon(Icons.check_circle, color: color, size: 20)
            else if (showArrow)
              Icon(Icons.chevron_right, color: color.withOpacity(0.3), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentCard({
    required String deptName,
    required bool isCurrent,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCurrent ? const Color(0xFF4F46E5).withOpacity(0.05) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrent ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isCurrent ? const Color(0xFF4F46E5) : const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.location_on_outlined, 
                color: isCurrent ? Colors.white : const Color(0xFF4F46E5), 
                size: 20
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                deptName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isCurrent ? const Color(0xFF4F46E5) : const Color(0xFF1E293B),
                ),
              ),
            ),
            if (isCurrent)
              const Icon(Icons.check_circle, color: Color(0xFF4F46E5), size: 20),
          ],
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

  Future<void> _handleSwitch(String role, String dept) async {
    final success = await ref.read(authProvider.notifier).switchRole(role, dept);
    if (success && mounted) {
      await ref.read(requestProvider.notifier).fetchRequests(page: 1);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to $role in $dept'),
            backgroundColor: const Color(0xFF4F46E5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to switch role'), backgroundColor: Colors.red),
      );
    }
  }
}
