import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/request_provider.dart';

class SwitchRoleModal extends ConsumerStatefulWidget {
  const SwitchRoleModal({super.key});

  @override
  ConsumerState<SwitchRoleModal> createState() => _SwitchRoleModalState();
}

class _SwitchRoleModalState extends ConsumerState<SwitchRoleModal> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final availableRoles = authState.availableRoles ?? [];
    final currentUser = authState.user;

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
            const Text(
              'SELECT A ROLE TO SWITCH',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: authState.isLoading
                  ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                  : availableRoles.isEmpty
                      ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No other roles available')))
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: availableRoles.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = availableRoles[index];
                            final role = item['role'].toString();
                            final dept = item['dept'].toString();
                            final isCurrent = currentUser?.role == role && currentUser?.department == dept;

                            return InkWell(
                              onTap: isCurrent ? null : () => _handleSwitch(role, dept),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isCurrent ? const Color(0xFF5C59E8).withOpacity(0.05) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isCurrent ? const Color(0xFF5C59E8) : const Color(0xFFE2E8F0),
                                    width: isCurrent ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isCurrent ? const Color(0xFF5C59E8) : const Color(0xFFE2E8F0),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.person_outline,
                                         size: 20,
                                        color: isCurrent ? Colors.white : const Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            role,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: isCurrent ? const Color(0xFF5C59E8) : const Color(0xFF1E293B),
                                            ),
                                          ),
                                          Text(
                                            dept,
                                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isCurrent)
                                      const Icon(Icons.check_circle, color: Color(0xFF5C59E8), size: 24)
                                    else
                                      const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
                                  ],
                                ),
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

  Future<void> _handleSwitch(String role, String dept) async {
    final success = await ref.read(authProvider.notifier).switchRole(role, dept);
    if (success && mounted) {
      await ref.read(requestProvider.notifier).fetchRequests(page: 1);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to $role in $dept'),
            backgroundColor: const Color(0xFF5C59E8),
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
