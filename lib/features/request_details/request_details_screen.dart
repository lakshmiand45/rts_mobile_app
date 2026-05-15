import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/widgets/status_badge.dart';
import '../../models/request_model.dart';
import '../../models/chat_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import 'widgets/close_ticket_modal.dart';
import 'widgets/checking_deadline_modal.dart';

class RequestDetailsScreen extends ConsumerStatefulWidget {
  final String ticketId;
  const RequestDetailsScreen({super.key, required this.ticketId});

  @override
  ConsumerState<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends ConsumerState<RequestDetailsScreen> {
  final TextEditingController _commentController = TextEditingController();
  String? selectedDept;
  final List<String> departments = [
    'Academic','Admin','Animation','Broadcasting',
    'Business Development','Corporate Communications','Documantation','Documentation','Govt.Relations',
    'HR','Management','Marketing','Operation','Purchase','Software','Store','System admin',
    'Technical Support', 'Finance', 'IT'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    await ref.read(requestProvider.notifier).fetchRequestById(widget.ticketId);
    ref.read(requestProvider.notifier).markAsRead(widget.ticketId);
    await ref.read(requestProvider.notifier).fetchChatMessages(widget.ticketId);

    final paginatedState = ref.read(requestProvider);
    final requests = paginatedState.requests;

    final currentTicket = requests.firstWhere(
          (r) => r.id == widget.ticketId || r.slNo == widget.ticketId,
      orElse: () => requests.isNotEmpty ? requests.first : RequestModel.fromMap({'id': widget.ticketId}),
    );

    if (mounted) {
      setState(() {
        final String? ticketDept = currentTicket.assignedDepartment;
        if (departments.contains(ticketDept)) {
          selectedDept = ticketDept;
        }
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _showChatBottomSheet() {
    ref.read(requestProvider.notifier).markChatAsRead(widget.ticketId);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ChatBottomSheet(ticketId: widget.ticketId),
    );
  }

  Future<void> _updateTicketStatus(RequestStatus status, {String? resolutionNote}) async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    final role = user?.role.toUpperCase();

    final paginatedState = ref.read(requestProvider);
    final requests = paginatedState.requests;
    final currentTicket = requests.firstWhere(
            (r) => r.id == widget.ticketId || r.slNo == widget.ticketId,
        orElse: () => requests.first
    );

    final bool isUserRequestor = user != null && (
        user.userId.toString().trim() == currentTicket.userId.toString().trim() ||
            user.empId.toString().trim() == currentTicket.empId.toString().trim() ||
            user.name.trim().toLowerCase() == currentTicket.userName.trim().toLowerCase()
    );

    bool success = false;
    String message = 'Status updated successfully';

    if (isUserRequestor && (status == RequestStatus.closed || status == RequestStatus.pending)) {
      final String acknowledgeStatus = (status == RequestStatus.closed) ? 'Received' : 'Not Received';
      success = await ref.read(requestProvider.notifier).acknowledgeRequest(currentTicket.id, acknowledgeStatus);
      message = (status == RequestStatus.closed) ? 'Ticket confirmed and closed' : 'Reported as not received';
    } else if (status == RequestStatus.closed) {
      success = await ref.read(requestProvider.notifier).closeTicket(currentTicket.id, resolutionNote ?? 'Ticket closed by department.');
      message = 'Ticket closed successfully';
    } else {
      success = await ref.read(requestProvider.notifier).updateStatus(
          currentTicket.id,
          status,
          comment: _commentController.text.trim(),
          isRM: role == 'RM',
          isHOD: role == 'HOD',
          isDeptHOD: role == 'DEPTHOD',
          isAdmin: role == 'ADMIN',
          isManagement: role == 'MANAGEMENT'
      );
    }

    if (success) {
      await _loadInitialData();
      if (mounted) {
        _commentController.clear();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action failed. Please check if you have permission.'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _forwardTicket() async {
    if (selectedDept != null) {
      final success = await ref.read(requestProvider.notifier).forwardRequest(widget.ticketId, selectedDept!);
      if (success) {
        await _loadInitialData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ticket forwarded to $selectedDept')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to forward ticket'), backgroundColor: Colors.red));
        }
      }
    }
  }

  void _previewDocument(RequestModel ticket, {String? customUrl, String? customName}) {
    final fileName = customName ?? ticket.attachedFileName ?? 'Document Preview';
    final url = customUrl ?? ticket.attachedFileUrl;

    if (ticket.attachedFileBytes != null || ticket.attachedFilePath != null || url != null) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: Text(fileName),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildPreviewWidget(ticket, customUrl: url, customName: fileName),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildPreviewWidget(RequestModel ticket, {String? customUrl, String? customName}) {
    final fileName = (customName ?? ticket.attachedFileName ?? '').toLowerCase();
    final url = customUrl ?? ticket.attachedFileUrl;

    if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg') || fileName.endsWith('.png') || fileName.endsWith('.gif')) {
      if (url != null && url.isNotEmpty) {
        return Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Center(child: Text('Failed to load image from server')),
        );
      } else if (kIsWeb && ticket.attachedFileBytes != null) {
        return Image.memory(ticket.attachedFileBytes!, fit: BoxFit.contain);
      } else if (ticket.attachedFilePath != null) {
        return Image.file(File(ticket.attachedFilePath!), fit: BoxFit.contain);
      }
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.insert_drive_file, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text('Preview not available for this file type.', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text(customName ?? ticket.attachedFileName ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paginatedState = ref.watch(requestProvider);
    final requests = paginatedState.requests;

    RequestModel? currentTicket;
    try {
      currentTicket = requests.firstWhere((r) => r.id == widget.ticketId || r.slNo == widget.ticketId);
    } catch (_) {
      if (!paginatedState.isLoading && requests.isNotEmpty) {
        currentTicket = requests.first;
      }
    }

    if (currentTicket == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final authState = ref.watch(authProvider);
    final user = authState.user;
    final String role = user?.role.toUpperCase() ?? '';
    final bool isAuthorizedRole = role == 'RM' || role == 'HOD' || role == 'DEPTHOD' || role == 'ADMIN' || role == 'MANAGEMENT';
    final bool isClosed = currentTicket.overallStatus == RequestStatus.closed;
    final bool isResolved = currentTicket.overallStatus == RequestStatus.resolved;

    final bool isUserRequestor = user != null && (
        user.userId.toString().trim() == currentTicket.userId.toString().trim() ||
            user.empId.toString().trim() == currentTicket.empId.toString().trim() ||
            user.name.trim().toLowerCase() == currentTicket.userName.trim().toLowerCase()
    );

    final bool buttonsEnabled = isAuthorizedRole && !isClosed && !isResolved;
    final bool showAdminSection = isAuthorizedRole && !isClosed && !isResolved;
    final bool canForward = isAuthorizedRole && !isClosed && !isResolved;
    final bool isForwarding = selectedDept != null && selectedDept != currentTicket.assignedDepartment;
    final bool canCloseTicket = (role == 'DEPTHOD' || role == 'ADMIN') && !isClosed && !isResolved;

    final bool showRequestorActions = isUserRequestor && !isClosed &&
        (isResolved ||
            (currentTicket.assignedHodStatus != RequestStatus.pending &&
                currentTicket.assignedHodStatus != RequestStatus.open &&
                currentTicket.assignedHodStatus != RequestStatus.checking));

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'REQUEST DETAILS — #${currentTicket.slNo}',
          style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w900, fontSize: 18),
        ),
        actions: [
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.black)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader(Icons.person_outline, 'USER INFORMATION'),
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF5C59E8).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        onPressed: _showChatBottomSheet,
                        icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF5C59E8)),
                        tooltip: 'Open Chat',
                      ),
                    ),
                    if (currentTicket.unreadChatCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildInfoField('DATE', DateFormat('dd/MM/yyyy').format(currentTicket.date)),
                const SizedBox(width: 16),
                _buildInfoField('EMP ID', currentTicket.empId),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildInfoField('NAME', currentTicket.userName),
                const SizedBox(width: 16),
                _buildInfoField('DEPARTMENT', currentTicket.department),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildInfoField('DESIGNATION', currentTicket.designation),
                const SizedBox(width: 16),
                _buildInfoField('LOCATION', currentTicket.location),
              ],
            ),
            const SizedBox(height: 24),
            const Text('REQUEST TITLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(8)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.computer, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currentTicket.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('ASSIGNED DEPARTMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedDept,
                  isExpanded: true,
                  hint: const Text("Select Department", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black),
                  items: departments.map((dept) => DropdownMenuItem(value: dept, child: Text(dept))).toList(),
                  onChanged: canForward ? (val) => setState(() => selectedDept = val) : null,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('REQUEST DESCRIPTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            _buildStaticField(currentTicket.description),
            const SizedBox(height: 16),

            _AttachmentsSection(
              ticket: currentTicket,
              onPreview: (url, name) => _previewDocument(currentTicket!, customUrl: url, customName: name),
            ),

            const SizedBox(height: 32),
            const Text('ADMIN ACTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _buildStatusBox('REQUESTOR RM STATUS', currentTicket.rmStatus),
                  const SizedBox(width: 24),
                  _buildStatusBox('REQUESTOR HOD STATUS', currentTicket.hodStatus),
                  const SizedBox(width: 24),
                  _buildStatusBox('ASSIGNED HOD STATUS', currentTicket.assignedHodStatus),
                ],
              ),
            ),

            if (currentTicket.dueDate != null) ...[
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final dueDate = currentTicket!.dueDate!;
                  final int requestorDaysLeft = dueDate.difference(today).inDays;
                  final bool isOverdue = requestorDaysLeft < 0;
                  int colorDays = requestorDaysLeft < 0 ? 0 : requestorDaysLeft;

                  Color bgColor; Color textColor; Color badgeColor; String urgencyText;
                  if (colorDays < 7) {
                    bgColor = const Color(0xFFFEF2F2); textColor = const Color(0xFF991B1B); badgeColor = const Color(0xFFEF4444); urgencyText = 'High Urgency';
                  } else if (colorDays <= 15) {
                    bgColor = const Color(0xFFFFF7ED); textColor = const Color(0xFF9A3412); badgeColor = const Color(0xFFF97316); urgencyText = 'Medium Urgency';
                  } else {
                    bgColor = const Color(0xFFF0FDF4); textColor = const Color(0xFF166534); badgeColor = const Color(0xFF10B981); urgencyText = 'Low Urgency';
                  }

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, color: textColor, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('DUE DATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(DateFormat('dd/MM/yyyy').format(dueDate), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(20)),
                          child: Column(
                            children: [
                              Text(urgencyText, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              Text(isOverdue ? 'Overdue' : '$requestorDaysLeft days left', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 8)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],

            if (currentTicket.checkingDeadline != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFFFFFBEB), border: Border.all(color: const Color(0xFFFEF3C7)), borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: Color(0xFFF59E0B), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CHECKING DEADLINE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                          const SizedBox(height: 4),
                          Text(DateFormat('d/M/yyyy').format(currentTicket.checkingDeadline!), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                          if (currentTicket.checkingDeadlineReason != null && currentTicket.checkingDeadlineReason!.isNotEmpty)
                            Padding(padding: const EdgeInsets.only(top: 4), child: Text(currentTicket.checkingDeadlineReason!, style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        (() {
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          final int diff = currentTicket!.checkingDeadline!.difference(today).inDays;
                          return diff <= 0 ? 'Due' : '${diff}d left';
                        })(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (showRequestorActions) ...[
              const SizedBox(height: 24),
              const Center(child: Text('Have you received the requested items/service?', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 13))),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildActionButton('RECEIVED', const Color(0xFF10B981), Icons.check_circle_outline, () => _updateTicketStatus(RequestStatus.closed))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildActionButton('NOT RECEIVED', const Color(0xFFEF4444), Icons.cancel_outlined, () => _updateTicketStatus(RequestStatus.pending))),
                ],
              ),
            ],

            const SizedBox(height: 16),
            if (showAdminSection) ...[
              TextField(controller: _commentController, decoration: const InputDecoration(hintText: 'Add your official comments here...', fillColor: Colors.white)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildActionButton(isForwarding ? 'FORWARD' : 'APPROVE', const Color(0xFF10B981), isForwarding ? Icons.arrow_forward : Icons.check_circle_outline, buttonsEnabled ? () => isForwarding ? _forwardTicket() : _updateTicketStatus(RequestStatus.approved) : null)),
                  if (role != 'MANAGEMENT') ...[
                    const SizedBox(width: 8),
                    Expanded(child: _buildActionButton('CHECKING', Colors.orange, Icons.access_time, buttonsEnabled ? () async {
                      final result = await showDialog(context: context, builder: (context) => CheckingDeadlineModal(ticketId: widget.ticketId));
                      if (result == true) _loadInitialData();
                    } : null)),
                  ],
                  const SizedBox(width: 8),
                  Expanded(child: _buildActionButton('REJECT', Colors.red, Icons.cancel_outlined, buttonsEnabled ? () => _updateTicketStatus(RequestStatus.rejected) : null)),
                ],
              ),
            ],
            const SizedBox(height: 12),
            if (canCloseTicket)
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await showDialog(context: context, builder: (context) => CloseTicketModal(ticketId: widget.ticketId));
                    if (result == true) _loadInitialData();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('Close Ticket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(children: [Icon(icon, size: 16, color: Colors.grey), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12))]);
  }

  Widget _buildInfoField(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildStaticField(String text) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: Text(text, style: const TextStyle(color: Colors.grey, fontSize: 12)));
  }

  Widget _buildStatusBox(String label, RequestStatus status) {
    return Column(children: [Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)), const SizedBox(height: 8), StatusBadge(status: status)]);
  }

  Widget _buildActionButton(String label, Color color, IconData icon, VoidCallback? onTap) {
    return SizedBox(height: 40, child: ElevatedButton.icon(onPressed: onTap, icon: Icon(icon, size: 16), label: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, disabledBackgroundColor: Colors.grey[300], disabledForegroundColor: Colors.grey[600], padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))));
  }
}

class _AttachmentsSection extends StatelessWidget {
  final RequestModel ticket;
  final Function(String url, String name) onPreview;

  const _AttachmentsSection({required this.ticket, required this.onPreview});

  bool _isImage(String fileName) {
    final lowerCaseFileName = fileName.toLowerCase();
    return lowerCaseFileName.endsWith('.jpg') || lowerCaseFileName.endsWith('.jpeg') || lowerCaseFileName.endsWith('.png') || lowerCaseFileName.endsWith('.webp');
  }

  @override
  Widget build(BuildContext context) {
    final List<String> urls = ticket.fileUrls ?? [];
    final List<String> names = ticket.fileNames ?? [];
    List<Widget> attachmentWidgets = [];

    if (urls.isNotEmpty && names.length == urls.length) {
      for (int i = 0; i < urls.length; i++) {
        attachmentWidgets.add(_buildAttachmentItem(context, urls[i], names[i]));
      }
    } else if (ticket.attachedFileUrl != null && ticket.attachedFileName != null) {
      attachmentWidgets.add(_buildAttachmentItem(context, ticket.attachedFileUrl!, ticket.attachedFileName!));
    }

    if (attachmentWidgets.isEmpty) {
      return Container(
        width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
        child: const Center(child: Text('No document attached', style: TextStyle(color: Colors.grey, fontSize: 12))),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: attachmentWidgets.map((w) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: w)).toList(),
    );
  }

  Widget _buildAttachmentItem(BuildContext context, String url, String name) {
    return InkWell(
      onTap: () => onPreview(url, name),
      child: Container(
        width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            _isImage(name)
                ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(url, width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 40, color: Colors.red)))
                : const Icon(Icons.insert_drive_file, color: Color(0xFF5C59E8), size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(name, style: const TextStyle(color: Color(0xFF5C59E8), fontWeight: FontWeight.bold, decoration: TextDecoration.underline, fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 1)),
          ],
        ),
      ),
    );
  }
}

class _ChatBottomSheet extends ConsumerStatefulWidget {
  final String ticketId;
  const _ChatBottomSheet({required this.ticketId});
  @override
  ConsumerState<_ChatBottomSheet> createState() => _ChatBottomSheetState();
}

class _ChatBottomSheetState extends ConsumerState<_ChatBottomSheet> {
  final TextEditingController _messageController = TextEditingController();
  List<ChatModel> _chatMessages = [];
  bool _isChatLoading = true;
  bool _isSending = false;
  PlatformFile? _stagedFile;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final messages = await ref.read(requestProvider.notifier).fetchChatMessages(widget.ticketId);
    if (mounted) setState(() { _chatMessages = messages; _isChatLoading = false; });
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(withData: true);
      if (result != null) setState(() => _stagedFile = result.files.single);
    } catch (e) { debugPrint('Error picking file: $e'); }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isNotEmpty || _stagedFile != null) {
      setState(() => _isSending = true);
      ChatModel? newMessage;
      if (_stagedFile != null) {
        newMessage = await ref.read(requestProvider.notifier).sendFileAttachment(widget.ticketId, text: text, fileBytes: _stagedFile?.bytes, fileName: _stagedFile?.name, filePath: kIsWeb ? null : _stagedFile?.path);
      } else {
        newMessage = await ref.read(requestProvider.notifier).sendChatMessage(widget.ticketId, text, 'message');
      }
      if (mounted) {
        setState(() => _isSending = false);
        if (newMessage != null) {
          setState(() { _chatMessages.add(newMessage!); _messageController.clear(); _stagedFile = null; });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final paginatedState = ref.watch(requestProvider);
    final requests = paginatedState.requests;
    final currentTicket = requests.firstWhere((r) => r.id == widget.ticketId || r.slNo == widget.ticketId, orElse: () => requests.first);

    return DraggableScrollableSheet(
      initialChildSize: 0.8, minChildSize: 0.5, maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xFF5C59E8)),
                  const SizedBox(width: 12),
                  const Text('ACTIVITY & CHAT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const Spacer(),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF5C59E8), borderRadius: BorderRadius.circular(12)), child: Text('${_chatMessages.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 8),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 20)),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: _isChatLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(controller: controller, padding: const EdgeInsets.all(24), itemCount: _chatMessages.length, itemBuilder: (context, index) => _buildChatBubble(_chatMessages[index], currentTicket)),
            ),
            _buildInputSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_stagedFile != null)
            ListTile(dense: true, leading: const Icon(Icons.attach_file, size: 16, color: Color(0xFF5C59E8)), title: Text(_stagedFile!.name, style: const TextStyle(fontSize: 12)), trailing: IconButton(onPressed: () => setState(() => _stagedFile = null), icon: const Icon(Icons.close, size: 16, color: Colors.red))),
          Row(
            children: [
              IconButton(onPressed: _pickFile, icon: const Icon(Icons.attach_file, color: Colors.grey)),
              Expanded(child: TextField(controller: _messageController, decoration: const InputDecoration(hintText: 'Type your message...', border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false))),
              IconButton(onPressed: _isSending ? null : _sendMessage, icon: _isSending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send, color: Color(0xFF5C59E8))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(ChatModel chat, RequestModel ticket) {
    final authState = ref.read(authProvider);
    final user = authState.user;
    final bool isMe = chat.senderId == user?.userId;
    final bool isClosureMessage = chat.text?.toLowerCase().contains('ticket closed') == true || chat.text?.toLowerCase().contains('resolution submitted') == true;
    String initials = '??';
    if (chat.senderName.trim().isNotEmpty) {
      List<String> nameParts = chat.senderName.trim().split(' ');
      initials = nameParts.length >= 2 ? (nameParts[0][0] + nameParts[1][0]).toUpperCase() : chat.senderName.substring(0, chat.senderName.length >= 2 ? 2 : 1).toUpperCase();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) CircleAvatar(radius: 16, backgroundColor: const Color(0xFFE2E8F0), child: Text(initials, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF5C59E8)))),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [Text(chat.senderRole, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), const SizedBox(width: 8), Text(DateFormat('dd/MM HH:mm').format(chat.createdAt), style: const TextStyle(fontSize: 10, color: Colors.grey))]),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: isMe ? const Color(0xFF5C59E8) : const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isClosureMessage) Text(chat.text!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isMe ? Colors.white : Colors.black))
                      else if (chat.text != null && chat.text!.isNotEmpty) Text(chat.text!, style: TextStyle(fontSize: 12, color: isMe ? Colors.white : Colors.black)),
                      if (chat.fileUrl != null || (isClosureMessage && ticket.attachedFileUrl != null))
                        InkWell(
                          onTap: () => _previewChatAttachment(chat),
                          child: Container(
                            margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.4), borderRadius: BorderRadius.circular(8)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.insert_drive_file, size: 16, color: isMe ? Colors.white : const Color(0xFF5C59E8)), const SizedBox(width: 8), Flexible(child: Text(chat.fileName ?? ticket.attachedFileName ?? 'Attachment', style: TextStyle(fontSize: 11, color: isMe ? Colors.white : const Color(0xFF5C59E8), decoration: TextDecoration.underline), overflow: TextOverflow.ellipsis))]),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMe) ...[const SizedBox(width: 12), CircleAvatar(radius: 16, backgroundColor: const Color(0xFF5C59E8), child: Text(initials, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)))],
        ],
      ),
    );
  }

  void _previewChatAttachment(ChatModel chat) {
    if (chat.fileUrl != null) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(title: Text(chat.fileName ?? 'Attachment Preview'), automaticallyImplyLeading: false, actions: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]),
                Expanded(child: Padding(padding: const EdgeInsets.all(16.0), child: _buildChatAttachmentPreview(chat))),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildChatAttachmentPreview(ChatModel chat) {
    final fileName = chat.fileName?.toLowerCase() ?? '';
    final url = chat.fileUrl ?? '';
    if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg') || fileName.endsWith('.png') || fileName.endsWith('.gif')) {
      return Image.network(url, fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) => const Center(child: Text('Failed to load image')), loadingBuilder: (context, child, loadingProgress) => loadingProgress == null ? child : const Center(child: CircularProgressIndicator()));
    }
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.insert_drive_file, size: 64, color: Colors.grey), const SizedBox(height: 16), Text('Preview not available for this file type.', style: TextStyle(color: Colors.grey[600])), const SizedBox(height: 8), Text(chat.fileName ?? '', style: const TextStyle(fontWeight: FontWeight.bold))]));
  }
}
