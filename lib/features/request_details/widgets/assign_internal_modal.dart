import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/request_provider.dart';
import '../../../models/user_model.dart';

class AssignInternalModal extends ConsumerStatefulWidget {
  final String department;
  const AssignInternalModal({super.key, required this.department});

  @override
  ConsumerState<AssignInternalModal> createState() => _AssignInternalModalState();
}

class _AssignInternalModalState extends ConsumerState<AssignInternalModal> {
  List<UserModel> _users = [];
  List<UserModel> _filteredUsers = [];
  final List<UserModel> _selectedUsers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final users = await ref.read(requestProvider.notifier).fetchUsersByDept(widget.department);
      if (mounted) {
        setState(() {
          _users = users;
          _filteredUsers = _users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching users: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _filterUsers(String query) {
    setState(() {
      _filteredUsers = _users
          .where((u) => u.name.toLowerCase().contains(query.toLowerCase()) || 
                        u.empId.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context, 'back'),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Assign Internal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text('Select one or more people', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: _filterUsers,
              decoration: InputDecoration(
                hintText: 'Search employees...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredUsers.isEmpty
                      ? const Center(child: Text('No users found'))
                      : ListView.builder(
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = _filteredUsers[index];
                            final isSelected = _selectedUsers.any((u) => u.empId == user.empId);
                            return CheckboxListTile(
                              value: isSelected,
                              title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(user.designation, style: const TextStyle(fontSize: 12)),
                              secondary: CircleAvatar(
                                backgroundColor: Colors.indigo[50],
                                child: Text(user.initials, style: const TextStyle(fontSize: 12, color: Colors.indigo)),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedUsers.add(user);
                                  } else {
                                    _selectedUsers.removeWhere((u) => u.empId == user.empId);
                                  }
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, 'back'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectedUsers.isEmpty ? null : () => Navigator.pop(context, _selectedUsers),
                    icon: const Icon(Icons.send),
                    label: const Text('Send'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
