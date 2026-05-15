import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/request_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/request_provider.dart';

class AddRequestModal extends ConsumerStatefulWidget {
  const AddRequestModal({super.key});

  @override
  ConsumerState<AddRequestModal> createState() => _AddRequestModalState();
}

class _AddRequestModalState extends ConsumerState<AddRequestModal> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String? selectedDepartment;
  DateTime? selectedDueDate;
  List<PlatformFile> pickedFiles = [];

  final List<String> _departments = [
    'Academic', 'Admin', 'Animation', 'Broadcasting',
    'Business Development', 'Corporate Communications', 'Documantation', 'Govt.Relations',
    'HR', 'Management', 'Marketing', 'Operation', 'Purchase', 'Software', 'Store',
    'System admin', 'Technical Support'
  ];

  // Priority Logic (Frontend Only)
  String get _priority {
    if (selectedDueDate == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(selectedDueDate!.year, selectedDueDate!.month, selectedDueDate!.day);
    final difference = selected.difference(today).inDays;

    if (difference <= 7) return 'High';
    if (difference <= 15) return 'Medium';
    return 'Low';
  }

  Color get _priorityColor {
    final p = _priority;
    if (p == 'High') return const Color(0xFFEF4444);
    if (p == 'Medium') return const Color(0xFFF59E0B);
    if (p == 'Low') return const Color(0xFF10B981);
    return Colors.grey;
  }

  String get _daysRemaining {
    if (selectedDueDate == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(selectedDueDate!.year, selectedDueDate!.month, selectedDueDate!.day);
    final difference = selected.difference(today).inDays;
    return '$difference days remaining';
  }


  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        withData: true,
        allowMultiple: true,
      );
      if (result != null) {
        setState(() {
          pickedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  void _removeFile(int index) {
    setState(() {
      pickedFiles.removeAt(index);
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDueDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF5C59E8),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => selectedDueDate = picked);
    }
  }

  void _showSingleSelect({
    required String title,
    required List<String> options,
    required String? selected,
    required Function(String) onSelected,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Select $title', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                return ListTile(
                  title: Text(option, style: const TextStyle(fontSize: 14)),
                  trailing: selected == option ? const Icon(Icons.check_circle, color: Color(0xFF5C59E8)) : null,
                  onTap: () {
                    onSelected(option);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ],
        );
      },
    );
  }

  Future<void> _submit() async {
    if (_titleController.text.isNotEmpty && selectedDepartment != null) {
      final authState = ref.read(authProvider);
      final user = authState.user;
      final paginatedState = ref.read(requestProvider);

      final newRequest = RequestModel(
        slNo: (paginatedState.totalItems + 1).toString(),
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        userId: user?.userId ?? 'Unknown ID',
        empId: user?.empId ?? 'Unknown',
        userName: user?.name ?? 'Anonymous',
        department: user?.department ?? 'Unknown',
        designation: user?.designation ?? 'Staff',
        location: user?.location ?? 'Remote',
        title: _titleController.text,
        description: _descController.text,
        rmStatus: RequestStatus.pending,
        assignedDepartments: [selectedDepartment!],
        assignedPersons: [],
        dueDate: selectedDueDate,
        overallStatus: RequestStatus.pending,
      );

      final success = await ref.read(requestProvider.notifier).addRequest(
        newRequest,
        multiFiles: pickedFiles,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request submitted successfully'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to submit request. Please try again.'), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title and select a department.'), backgroundColor: Colors.orange),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ADD NEW REQUEST',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close )),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),

              // Request Title
              const Text('REQUEST TITLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Briefly describe your need...',
                  hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                  fillColor: const Color(0xFFF8FAFC),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              ),
              const SizedBox(height: 16),

              // Your Department (Auto-filled & Read-only)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('YOUR DEPARTMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    Text(user?.department ?? 'N/A', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF5C59E8))),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Assign to Department (Single-select)
              const Text('ASSIGN TO DEPARTMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _showSingleSelect(
                  title: 'Department',
                  options: _departments,
                  selected: selectedDepartment,
                  onSelected: (val) => setState(() => selectedDepartment = val),
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedDepartment ?? 'Select Department',
                          style: TextStyle(fontSize: 13, color: selectedDepartment == null ? Colors.grey : const Color(0xFF1E293B)),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Due Date Picker
              const Text('REQUIRED BY (DUE DATE) — OPTIONAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          selectedDueDate == null ? 'Select Date' : DateFormat('dd MMM yyyy').format(selectedDueDate!),
                          style: TextStyle(fontSize: 13, color: selectedDueDate == null ? Colors.grey : const Color(0xFF1E293B)),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                    ],
                  ),
                ),
              ),

              // Priority Display
              if (selectedDueDate != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: _priorityColor),
                      const SizedBox(width: 8),
                      Text('Urgency: $_priority', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _priorityColor)),
                      const Spacer(),
                      Text(_daysRemaining, style: TextStyle(fontSize: 11, color: _priorityColor)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Request Description
              const Text('REQUEST DESCRIPTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              TextField(
                controller: _descController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Provide detailed information about your request...',
                  hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                  fillColor: const Color(0xFFF8FAFC),
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              ),
              const SizedBox(height: 16),

              // File Upload
              const Text('ATTACH FILES (OPTIONAL)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              DottedBorder(
                color: const Color(0xFFE2E8F0),
                strokeWidth: 1,
                dashPattern: const [6, 3],
                borderType: BorderType.RRect,
                radius: const Radius.circular(12),
                child: InkWell(
                  onTap: _pickFile,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.upload_outlined,
                          color: Colors.grey[400],
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'CLICK TO UPLOAD FILES',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (pickedFiles.isNotEmpty) ...[
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pickedFiles.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final file = pickedFiles[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.insert_drive_file, size: 16, color: Color(0xFF5C59E8)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              file.name,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: () => _removeFile(index),
                            icon: const Icon(Icons.close, size: 16, color: Colors.red),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE2E8F0),
                          foregroundColor: const Color(0xFF475569),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}