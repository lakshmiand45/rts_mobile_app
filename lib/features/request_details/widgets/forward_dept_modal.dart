import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/request_provider.dart';

class ForwardDeptModal extends ConsumerStatefulWidget {
  const ForwardDeptModal({super.key});

  @override
  ConsumerState<ForwardDeptModal> createState() => _ForwardDeptModalState();
}

class _ForwardDeptModalState extends ConsumerState<ForwardDeptModal> {
  final List<String> _selectedDepts = [];
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredDepts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    try {
      final departments = await ref.read(requestProvider.notifier).fetchAllDepartments();
      if (mounted) {
        setState(() {
          _filteredDepts = departments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterDepts(String query) {
    setState(() {
      _filteredDepts = _filteredDepts // Use the initial list if possible, but here we update state directly. 
          // Actually, we should probably keep a master list.
          .where((d) => d.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
    // Re-loading from provider state if filters are needed is better, but since it's an API call:
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
                        Text('Forward Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Select one or more departments', style: TextStyle(color: Colors.grey, fontSize: 10)),
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
              onChanged: (val) {
                // Simplified filtering for now as it's a fixed list after load
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: 'Search departments...',
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
                : _filteredDepts.isEmpty
                  ? const Center(child: Text('No departments found'))
                  : ListView.builder(
                      itemCount: _filteredDepts.length,
                      itemBuilder: (context, index) {
                        final dept = _filteredDepts[index];
                        if (_searchController.text.isNotEmpty && !dept.toLowerCase().contains(_searchController.text.toLowerCase())) {
                          return const SizedBox.shrink();
                        }
                        final isSelected = _selectedDepts.contains(dept);
                        return CheckboxListTile(
                          value: isSelected,
                          title: Text(dept, style: const TextStyle(fontWeight: FontWeight.bold)),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedDepts.add(dept);
                              } else {
                                _selectedDepts.remove(dept);
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
                    onPressed: _selectedDepts.isEmpty ? null : () => Navigator.pop(context, _selectedDepts),
                    icon: const Icon(Icons.send),
                    label: const Text('Send'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5C59E8),
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
