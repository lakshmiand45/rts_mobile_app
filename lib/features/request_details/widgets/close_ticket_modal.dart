import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../providers/request_provider.dart';

class CloseTicketModal extends ConsumerStatefulWidget {
  final String ticketId;
  const CloseTicketModal({super.key, required this.ticketId});

  @override
  ConsumerState<CloseTicketModal> createState() => _CloseTicketModalState();
}

class _CloseTicketModalState extends ConsumerState<CloseTicketModal> {
  final TextEditingController _noteController = TextEditingController();
  PlatformFile? pickedFile;
  bool _isSubmitting = false;

  // Expanded extensions to handle case-sensitivity and system categorization issues
  final List<String> _allowedExtensions = [
    'jpg', 'jpeg', 'png', 'pdf', 'docx', 'xlsx', 'csv', 'mp3', 'wav', 'm4a',
    'JPG', 'JPEG', 'PNG', 'PDF', 'DOCX', 'XLSX', 'CSV', 'MP3', 'WAV', 'M4A'
  ];

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
        withData: true,
      );
      if (result != null) {
        setState(() {
          pickedFile = result.files.first;
        });
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  Future<void> _submit() async {
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a resolution note')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Calling closeTicket which sends data to the backend.
      // The requirement states that after roles "close" it, it should show as "Resolved".
      final success = await ref.read(requestProvider.notifier).closeTicket(
        widget.ticketId,
        note,
        filePath: kIsWeb ? null : pickedFile?.path,
        fileBytes: pickedFile?.bytes,
        fileName: pickedFile?.name,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (success) {
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to close ticket. Please try again.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'CLOSE TICKET — #${widget.ticketId}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
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
                'RESOLUTION NOTE',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                maxLines: 4,
                enabled: !_isSubmitting,
                decoration: InputDecoration(
                  hintText: 'Describe how the ticket was resolved...',
                  hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                  fillColor: Colors.grey[50],
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'ATTACH FILE (OPTIONAL)',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              DottedBorder(
                color: Colors.grey.withAlpha(100),
                strokeWidth: 1,
                dashPattern: const [6, 3],
                borderType: BorderType.RRect,
                radius: const Radius.circular(12),
                child: InkWell(
                  onTap: _isSubmitting ? null : _pickFile,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        Icon(
                          pickedFile != null ? Icons.insert_drive_file : Icons.upload_outlined,
                          color: pickedFile != null ? const Color(0xFF5C59E8) : Colors.grey[400],
                          size: 32,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          pickedFile != null ? pickedFile!.name : 'CLICK TO UPLOAD FILE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: pickedFile != null ? const Color(0xFF1E293B) : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Supported: JPG, PNG, PDF, Docx, XLSX, CSV, Audio',
                          style: TextStyle(fontSize: 8, color: Color(0xFF5C59E8), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE2E8F0),
                          foregroundColor: const Color(0xFF475569),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: _isSubmitting 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Close Ticket', style: TextStyle(fontWeight: FontWeight.bold)),
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
