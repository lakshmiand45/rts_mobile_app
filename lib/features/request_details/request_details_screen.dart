import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/widgets/status_badge.dart';
import '../../models/request_model.dart';
import '../../models/chat_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/role_management_provider.dart';
import 'widgets/close_ticket_modal.dart';
import 'widgets/checking_deadline_modal.dart';
import 'widgets/approve_choice_modal.dart';
import 'widgets/assign_internal_modal.dart';
import 'widgets/forward_dept_modal.dart';

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
    'Academics-Assam','Academics-Karnataka','Academics-Tripura','Academics-Uttarakhand','Accounts-A','Accounts-G','Animation','Broadcasting-Assam',
    'Broadcasting-Karnataka','Broadcasting-Tripura','Broadcasting-Uttarakhand','Business Development','Corporate Communications','Documentation','Facilities',
    'Food Committee','Game Development','Govt. Relations','HR','Interns','Management','Marketing','Operations-Assam','Operations-Bihar','Operations-Karnataka',
    'Operations-Maharashtra','Operations-Mizoram','Operations-Nagaland','Operations-Tripura','Operations-Uttarakhand','Purchase','RTS Help Desk','Software',
    'Stores-Assam','Stores-Karnataka','Stores-Mizoram','Stores-Tripura','System Admin-Assam','System Admin-Karnataka','System Admin-Uttarakhand','TA Committee',
    'Technical Support'
  ];

  bool _isActionInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    final role = ref.read(authProvider).user?.role.toLowerCase();
    
    if (role == 'management') {
      await ref.read(roleManagementProvider.notifier).fetchRequestById(widget.ticketId);
    } else {
      await ref.read(requestProvider.notifier).fetchRequestById(widget.ticketId);
      ref.read(requestProvider.notifier).markAsRead(widget.ticketId);
      await ref.read(requestProvider.notifier).fetchChatMessages(widget.ticketId);
    }

    // Determine the current ticket based on the source provider
    final RequestModel? currentTicket = _getCurrentTicket();

    if (mounted && currentTicket != null) {
      setState(() {
        final String? ticketDept = currentTicket.assignedDepartment;
        if (departments.contains(ticketDept)) {
          selectedDept = ticketDept;
        } else if (currentTicket.assignedDepartments != null && currentTicket.assignedDepartments!.isNotEmpty) {
          final firstAssigned = currentTicket.assignedDepartments!.first;
          if (departments.contains(firstAssigned)) {
            selectedDept = firstAssigned;
          }
        }
      });
    }
  }

  RequestModel? _getCurrentTicket() {
    final role = ref.read(authProvider).user?.role.toLowerCase();
    if (role == 'management') {
      final mgmtState = ref.read(roleManagementProvider);
      try {
        return mgmtState.requests.firstWhere((r) => r.id == widget.ticketId || r.slNo == widget.ticketId);
      } catch (_) { return null; }
    } else {
      final standardState = ref.read(requestProvider);
      try {
        return standardState.requests.firstWhere((r) => r.id == widget.ticketId || r.slNo == widget.ticketId);
      } catch (_) { return null; }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _showChatBottomSheet() {
    final role = ref.read(authProvider).user?.role.toLowerCase();
    if (role != 'management') {
      ref.read(requestProvider.notifier).markChatAsRead(widget.ticketId);
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ChatBottomSheet(ticketId: widget.ticketId),
    );
  }

  Future<bool> _updateTicketStatus(RequestStatus status, {String? resolutionNote}) async {
    if (_isActionInProgress) return false;

    setState(() => _isActionInProgress = true);

    final authState = ref.read(authProvider);
    final user = authState.user;
    final bool isManagementRole = user?.role.toLowerCase() == 'management';
    final role = user?.role.toUpperCase();

    bool success = false;
    String message = 'Status updated successfully';

    try {
      if (isManagementRole) {
        // Specialized Management Actions
        if (status == RequestStatus.approved) {
          success = await ref.read(roleManagementProvider.notifier).approveRequest(widget.ticketId, _commentController.text.trim());
        } else if (status == RequestStatus.rejected) {
          success = await ref.read(roleManagementProvider.notifier).rejectRequest(widget.ticketId, _commentController.text.trim());
        } else if (status == RequestStatus.closed) {
          success = await ref.read(roleManagementProvider.notifier).closeRequest(widget.ticketId, resolutionNote ?? 'Closed by Management');
        }
      } else {
        // Standard Action Logic
        if (status == RequestStatus.resolved || status == RequestStatus.open) {
          final String acknowledgeStatus = (status == RequestStatus.resolved) ? 'Resolved' : 'Not Resolved';
          success = await ref.read(requestProvider.notifier).acknowledgeRequest(widget.ticketId, acknowledgeStatus);
          message = (status == RequestStatus.resolved) ? 'Ticket marked as Resolved' : 'Ticket marked as Not Resolved';
        } else if (status == RequestStatus.closed) {
          success = await ref.read(requestProvider.notifier).closeTicket(widget.ticketId, resolutionNote ?? 'Ticket closed.');
          message = 'Ticket closed successfully';
        } else {
          success = await ref.read(requestProvider.notifier).updateStatus(
              widget.ticketId,
              status,
              comment: _commentController.text.trim(),
              isRM: role == 'RM',
              isHOD: role == 'HOD',
              isDeptHOD: role == 'DEPTHOD',
              isAdmin: role == 'ADMIN',
              isManagement: false
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isActionInProgress = false);
      }
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
    return success;
  }

  Future<void> _handleApproveAction(RequestModel ticket) async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    final role = user?.role.toUpperCase() ?? '';

    if (role == 'MANAGEMENT') {
      _updateTicketStatus(RequestStatus.approved);
      return;
    }

    if (role == 'DEPTHOD') {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => const ApproveChoiceModal(),
      );

      if (choice == 'assign_internal') {
        final dynamic selectedUsers = await showDialog(
          context: context,
          builder: (context) => AssignInternalModal(department: user!.department),
        );

        if (selectedUsers is List<UserModel>) {
          setState(() => _isActionInProgress = true);
          try {
            final empIds = selectedUsers.map((u) => u.empId).toList();
            final names = selectedUsers.map((u) => u.name).toList();
            final success = await ref.read(requestProvider.notifier).approveAndAssignInternal(
              widget.ticketId,
              empIds,
              names,
              comment: _commentController.text.trim(),
            );
            if (success) {
              await _loadInitialData();
              if (mounted) {
                _commentController.clear();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request approved and assigned internally')));
              }
            }
          } finally {
            if (mounted) setState(() => _isActionInProgress = false);
          }
        } else if (selectedUsers == 'back') {
          _handleApproveAction(ticket);
        }
      } else if (choice == 'forward_dept') {
        final dynamic selectedDepts = await showDialog(
          context: context,
          builder: (context) => const ForwardDeptModal(),
        );

        if (selectedDepts is List<String>) {
          setState(() => _isActionInProgress = true);
          try {
            final success = await ref.read(requestProvider.notifier).approveAndForwardDept(
              widget.ticketId,
              selectedDepts,
              comment: _commentController.text.trim(),
            );
            if (success) {
              await _loadInitialData();
              if (mounted) {
                _commentController.clear();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request approved and forwarded')));
              }
            }
          } finally {
            if (mounted) setState(() => _isActionInProgress = false);
          }
        } else if (selectedDepts == 'back') {
          _handleApproveAction(ticket);
        }
      }
    } else if (role == 'HOD') {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Approve Action'),
          content: const Text('Choose an approval method:'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 'approve'), child: const Text('Only Approve')),
            TextButton(onPressed: () => Navigator.pop(context, 'forward'), child: const Text('Approve & Forward')),
          ],
        ),
      );

      if (choice == 'approve') {
        _updateTicketStatus(RequestStatus.approved);
      } else if (choice == 'forward') {
        final dynamic selectedDepts = await showDialog(
          context: context,
          builder: (context) => const ForwardDeptModal(),
        );
        if (selectedDepts is List<String>) {
          setState(() => _isActionInProgress = true);
          try {
            final success = await ref.read(requestProvider.notifier).approveAndForwardDept(
              widget.ticketId,
              selectedDepts,
              comment: _commentController.text.trim(),
            );
            if (success) {
              await _loadInitialData();
              if (mounted) {
                _commentController.clear();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request approved and forwarded')));
              }
            }
          } finally {
            if (mounted) setState(() => _isActionInProgress = false);
          }
        }
      }
    } else {
      _updateTicketStatus(RequestStatus.approved);
    }
  }

  Future<void> _forwardTicket() async {
    if (selectedDept != null && !_isActionInProgress) {
      setState(() => _isActionInProgress = true);
      try {
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
      } finally {
        if (mounted) {
          setState(() => _isActionInProgress = false);
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
                    if (url != null)
                      IconButton(
                        onPressed: () => _downloadFile(url),
                        icon: const Icon(Icons.download),
                        tooltip: 'Download',
                      ),
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

  Future<void> _downloadFile(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not download file'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildPreviewWidget(RequestModel ticket, {String? customUrl, String? customName}) {
    final fileName = (customName ?? ticket.attachedFileName ?? '').toLowerCase();
    final url = customUrl ?? ticket.attachedFileUrl;

    if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg') || fileName.endsWith('.png') || fileName.endsWith('.gif') || fileName.endsWith('.webp')) {
      if (url != null && url.isNotEmpty) {
        return Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            print('Failed to load image from server. URL: $url, Error: $error');
            return const Center(child: Text('Failed to load image from server'));
          },
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
          if (url != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _downloadFile(url),
              icon: const Icon(Icons.download),
              label: const Text('Download File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5C59E8),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final bool isManagementUser = user?.role.toLowerCase() == 'management';

    RequestModel? ticket;
    if (isManagementUser) {
      final mgmtState = ref.watch(roleManagementProvider);
      try {
        ticket = mgmtState.requests.firstWhere((r) => r.id == widget.ticketId || r.slNo == widget.ticketId);
      } catch (_) { if (mgmtState.requests.isNotEmpty && !mgmtState.isLoading) ticket = mgmtState.requests.first; }
    } else {
      final paginatedState = ref.watch(requestProvider);
      try {
        ticket = paginatedState.requests.firstWhere((r) => r.id == widget.ticketId || r.slNo == widget.ticketId);
      } catch (_) { if (paginatedState.requests.isNotEmpty && !paginatedState.isLoading) ticket = paginatedState.requests.first; }
    }

    if (ticket == null || user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentTicket = ticket;

    // --- FLAGS & LOGIC ---
    final bool isClosed = currentTicket.isClosed || currentTicket.acknowledgement != null;
    final bool isPendingAck = currentTicket.overallStatus == RequestStatus.resolved && currentTicket.acknowledgement == null;
    final bool isForwarded = currentTicket.isForwarded;
    final String currentEmpId = user.empId;
    final String currentDept = user.department;
    final String currentRole = user.role;

    final bool isRM = currentRole.toUpperCase() == 'RM';
    final bool isHOD = currentRole.toUpperCase() == 'HOD';
    final bool isDeptHOD = currentRole.toUpperCase() == 'DEPTHOD';
    final bool isManagement = currentRole.toUpperCase() == 'MANAGEMENT';
    final bool isAdmin = currentRole.toUpperCase() == 'ADMIN';
    final bool isRequestor = currentRole.toUpperCase() == 'REQUESTOR';

    final bool isOwnRequest = currentTicket.empId == currentEmpId;
    final bool isFromOtherDept = currentTicket.department.toLowerCase() != currentDept.toLowerCase();
    final bool isAssignedToMyDept = currentTicket.assignedDepartments != null &&
        currentTicket.assignedDepartments!.map((e) => e.toLowerCase()).contains(currentDept.toLowerCase());

    final bool isTeamMemberIncoming = isFromOtherDept && isAssignedToMyDept;
    final bool isAssignedDeptUser = (isRM || isHOD) && isAssignedToMyDept && isFromOtherDept;
    final bool isSpecificallyAssigned = (currentTicket.assignedPersonEmpIds != null &&
        currentTicket.assignedPersonEmpIds!.contains(currentEmpId)) && !isOwnRequest;

    final bool isForwardedAway = isForwarded && !isAssignedToMyDept && !isManagement && !isOwnRequest;

    RequestStatus myApprovalStatus = RequestStatus.pending;
    if (isRM) {
      myApprovalStatus = isAssignedDeptUser ? currentTicket.assignedRmStatus : currentTicket.rmStatus;
    } else if (isHOD) {
      myApprovalStatus = isAssignedDeptUser ? currentTicket.assignedHodStatus : currentTicket.hodStatus;
    } else if (isDeptHOD || isManagement) {
      myApprovalStatus = currentTicket.deptHodStatus;
    }

    final bool isActedApproved = myApprovalStatus == RequestStatus.approved || myApprovalStatus == RequestStatus.forwarded;
    final bool isActedChecking = myApprovalStatus == RequestStatus.checking;

    final bool canApprove = (isRM || isHOD || isDeptHOD || isManagement) && !isClosed && !isPendingAck && !isOwnRequest && !isForwardedAway;
    final bool canUserCheck = isTeamMemberIncoming && !isClosed && !isPendingAck && !isAdmin && !canApprove && !isForwardedAway;
    final bool canUserForward = (currentDept == 'Facilities') && isTeamMemberIncoming && !isClosed && !isPendingAck && !isAdmin && !canApprove && !isForwardedAway;

    final bool showActionSection = canApprove || canUserCheck || canUserForward;
    final bool deptChanged = selectedDept != null && selectedDept != currentTicket.assignedDepartment;
    final bool isFacilitiesRequestorClose = (currentDept == 'Facilities' && isRequestor && currentTicket.department == 'Facilities' && !isAssignedToMyDept && !isClosed && !isPendingAck);

    final bool canClose = ((isDeptHOD || isManagement) && !isOwnRequest && !isClosed && !isPendingAck && !isForwardedAway) ||
        (isTeamMemberIncoming && !isClosed && !isPendingAck && !isAdmin && !isForwardedAway) ||
        (isSpecificallyAssigned && !isClosed && !isPendingAck && !isAdmin) || isFacilitiesRequestorClose;

    final bool showAcknowledgement = (isPendingAck || currentTicket.overallStatus == RequestStatus.closed) && isOwnRequest;
    final bool canChat = !isAdmin;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: Text('REQUEST DETAILS — #${currentTicket.slNo}', style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w900, fontSize: 16)),
        actions: [
          IconButton(onPressed: _loadInitialData, icon: const Icon(Icons.refresh, color: Color(0xFF5C59E8)), tooltip: 'Refresh'),
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
                if (canChat)
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(color: const Color(0xFF5C59E8).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: IconButton(onPressed: _showChatBottomSheet, icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF5C59E8))),
                      ),
                      if (currentTicket.unreadChatCount > 0)
                        Positioned(right: 8, top: 8, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(children: [_buildInfoField('DATE', DateFormat('dd/MM/yyyy').format(currentTicket.date)), const SizedBox(width: 16), _buildInfoField('EMP ID', currentTicket.empId)]),
            const SizedBox(height: 16),
            Row(children: [_buildInfoField('NAME', currentTicket.userName), const SizedBox(width: 16), _buildInfoField('DEPARTMENT', currentTicket.department)]),
            const SizedBox(height: 16),
            Row(children: [_buildInfoField('DESIGNATION', currentTicket.designation), const SizedBox(width: 16), _buildInfoField('LOCATION', currentTicket.location)]),
            const SizedBox(height: 24),
            const Text('REQUEST TITLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(8)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.computer, size: 16, color: Colors.orange), const SizedBox(width: 8), Expanded(child: Text(currentTicket.title, style: const TextStyle(fontWeight: FontWeight.bold)))])) ,
            const SizedBox(height: 24),
            const Text('ASSIGNED DEPARTMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: (selectedDept != null && departments.contains(selectedDept)) ? selectedDept : null,
                  isExpanded: true,
                  hint: const Text("Select Department", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black),
                  items: departments.map((dept) => DropdownMenuItem(value: dept, child: Text(dept))).toList(),
                  onChanged: (canApprove || canUserForward) ? (val) => setState(() => selectedDept = val) : null,
                ),
              ),
            ),
            if (currentTicket.assignedDepartments != null && currentTicket.assignedDepartments!.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text('ALL ASSIGNED DEPARTMENTS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: currentTicket.assignedDepartments!.map((dept) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF5C59E8).withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF5C59E8).withOpacity(0.2))), child: Text(dept, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF5C59E8))))).toList()),
            ],
            const SizedBox(height: 24),
            const Text('REQUEST DESCRIPTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            _buildStaticField(currentTicket.description),
            const SizedBox(height: 16),
            _AttachmentsSection(ticket: currentTicket, onPreview: (url, name) => _previewDocument(currentTicket, customUrl: url, customName: name), onDownload: _downloadFile),
            const SizedBox(height: 32),
            const Text('ADMIN ACTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 16),
            Column(children: [Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: _buildStatusBox('RM STATUS', currentTicket.rmStatus)), const SizedBox(width: 8), Expanded(child: _buildStatusBox('HOD STATUS', currentTicket.hodStatus)), const SizedBox(width: 8), Expanded(child: _buildStatusBox('ASSIGNED RM', currentTicket.assignedRmStatus))]), const SizedBox(height: 24), Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [_buildStatusBox('ASSIGNED HOD', currentTicket.assignedHodStatus), const SizedBox(width: 40), _buildStatusBox('DeptHOD STATUS', currentTicket.deptHodStatus)])]),
            if (currentTicket.dueDate != null) ...[
              const SizedBox(height: 24),
              _buildDueDateInfo(currentTicket.dueDate!),
            ],
            if (currentTicket.checkingDeadline != null) ...[
              const SizedBox(height: 12),
              _buildCheckingDeadlineInfo(currentTicket),
            ],
            if (showAcknowledgement) ...[
              const SizedBox(height: 24),
              const Center(child: Text('Have you received the requested items/service?', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 13))),
              const SizedBox(height: 16),
              if (currentTicket.acknowledgement != null) Center(child: StatusBadge(status: currentTicket.acknowledgement!.toLowerCase().contains('not') ? RequestStatus.open : RequestStatus.resolved))
              else Row(children: [Expanded(child: _buildActionButton('RESOLVED', const Color(0xFF10B981), Icons.check_circle_outline, _isActionInProgress ? null : () => _updateTicketStatus(RequestStatus.resolved))), const SizedBox(width: 12), Expanded(child: _buildActionButton('NOT RESOLVED', const Color(0xFFEF4444), Icons.cancel_outlined, _isActionInProgress ? null : () => _updateTicketStatus(RequestStatus.open)))]),
            ],
            const SizedBox(height: 16),
            if (showActionSection) ...[
              TextField(controller: _commentController, enabled: !isActedApproved, decoration: const InputDecoration(hintText: 'Add your official comments here...', fillColor: Colors.white)),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                if (canApprove) ...[Expanded(child: _buildActionButton(deptChanged ? 'FORWARD' : 'APPROVE', deptChanged ? Colors.blue : const Color(0xFF10B981), deptChanged ? Icons.arrow_forward : Icons.check_circle_outline, isActedApproved ? null : () => deptChanged ? _forwardTicket() : _handleApproveAction(currentTicket))), const SizedBox(width: 8)],
                if (canUserForward) ...[Expanded(child: _buildActionButton('FORWARD', Colors.blue, Icons.arrow_forward, deptChanged ? () => _forwardTicket() : null)), const SizedBox(width: 8)],
                if (canApprove || canUserCheck || canUserForward) ...[if (!(canApprove && isActedApproved || isActedChecking)) Expanded(child: _buildActionButton('CHECKING', Colors.orange, Icons.access_time, () async { final result = await showDialog(context: context, builder: (context) => CheckingDeadlineModal(ticketId: widget.ticketId)); if (result == true) _loadInitialData(); })), const SizedBox(width: 8)],
                if (canApprove) Expanded(child: _buildActionButton('REJECT', Colors.red, Icons.cancel_outlined, isActedApproved ? null : () => _updateTicketStatus(RequestStatus.rejected))),
              ]),
            ],
            const SizedBox(height: 12),
            if (canClose) SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: () async { final result = await showDialog(context: context, builder: (context) => CloseTicketModal(ticketId: widget.ticketId)); if (result == true) _loadInitialData(); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Close Ticket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
          ],
        ),
      ),
    );
  }

  Widget _buildDueDateInfo(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final int requestorDaysLeft = dueDate.difference(today).inDays;
    final bool isOverdue = requestorDaysLeft < 0;
    int colorDays = requestorDaysLeft < 0 ? 0 : requestorDaysLeft;
    Color bgColor; Color textColor; Color badgeColor; String urgencyText;
    if (colorDays < 7) { bgColor = const Color(0xFFFEF2F2); textColor = const Color(0xFF991B1B); badgeColor = const Color(0xFFEF4444); urgencyText = 'High Urgency'; }
    else if (colorDays <= 15) { bgColor = const Color(0xFFFFF7ED); textColor = const Color(0xFF9A3412); badgeColor = const Color(0xFFF97316); urgencyText = 'Medium Urgency'; }
    else { bgColor = const Color(0xFFF0FDF4); textColor = const Color(0xFF166534); badgeColor = const Color(0xFF10B981); urgencyText = 'Low Urgency'; }

    return Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)), child: Row(children: [Icon(Icons.calendar_today_outlined, color: textColor, size: 20), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('DUE DATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)), const SizedBox(height: 4), Text(DateFormat('dd/MM/yyyy').format(dueDate), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor))])), Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(20)), child: Column(children: [Text(urgencyText, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)), Text(isOverdue ? 'Overdue' : '$requestorDaysLeft days left', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 8))]))]));
  }

  Widget _buildCheckingDeadlineInfo(RequestModel ticket) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFFFFBEB), border: Border.all(color: const Color(0xFFFEF3C7)), borderRadius: BorderRadius.circular(16)), child: Row(children: [const Icon(Icons.access_time, color: Color(0xFFF59E0B), size: 20), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('CHECKING DEADLINE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309))), const SizedBox(height: 4), Text(DateFormat('d/M/yyyy').format(ticket.checkingDeadline!), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF92400E))), if (ticket.checkingReason != null && ticket.checkingReason!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(ticket.checkingReason!, style: const TextStyle(fontSize: 12, color: Color(0xFF92400E))))])), Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(20)), child: Text((() { final now = DateTime.now(); final today = DateTime(now.year, now.month, now.day); final int diff = ticket.checkingDeadline!.difference(today).inDays; return diff <= 0 ? 'Due' : '${diff}d left'; })(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))]));
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(children: [Icon(icon, size: 16, color: Colors.grey), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12))]);
  }

  Widget _buildInfoField(String label, String value) {
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))]));
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
  final Function(String url) onDownload;

  const _AttachmentsSection({required this.ticket, required this.onPreview, required this.onDownload});

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
      return Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)), child: const Center(child: Text('No document attached', style: TextStyle(color: Colors.grey, fontSize: 12))));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: attachmentWidgets.map((w) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: w)).toList());
  }

  Widget _buildAttachmentItem(BuildContext context, String url, String name) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)), child: Row(children: [InkWell(onTap: () => onPreview(url, name), child: Row(mainAxisSize: MainAxisSize.min, children: [_isImage(name) ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(url, width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 40, color: Colors.red))) : const Icon(Icons.insert_drive_file, color: Color(0xFF5C59E8), size: 20), const SizedBox(width: 8)])), Expanded(child: InkWell(onTap: () => onPreview(url, name), child: Text(name, style: const TextStyle(color: Color(0xFF5C59E8), fontWeight: FontWeight.bold, decoration: TextDecoration.underline, fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 1))), IconButton(onPressed: () => onDownload(url), icon: const Icon(Icons.download_rounded, color: Color(0xFF5C59E8), size: 20), tooltip: 'Download')]));
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
  final List<ChatModel> _chatMessages = [];
  bool _isChatLoading = true;
  bool _isSending = false;
  PlatformFile? _stagedFile;

  final List<String> _allowedExtensions = ['jpg', 'jpeg', 'png', 'pdf', 'docx', 'xlsx', 'csv', 'mp3', 'wav', 'm4a'];

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
    if (!mounted) return;
    setState(() => _isChatLoading = true);

    final role = ref.read(authProvider).user?.role.toLowerCase();
    
    if (role == 'management') {
      await ref.read(roleManagementProvider.notifier).fetchRequestById(widget.ticketId);
      final mgmtState = ref.read(roleManagementProvider);
      try {
        final ticket = mgmtState.requests.firstWhere((r) => r.id == widget.ticketId || r.slNo == widget.ticketId);
        if (mounted) setState(() { _chatMessages.clear(); _chatMessages.addAll(ticket.chatMessages); _isChatLoading = false; });
      } catch (_) { if (mounted) setState(() => _isChatLoading = false); }
    } else {
      await ref.read(requestProvider.notifier).fetchRequestById(widget.ticketId);
      final messages = await ref.read(requestProvider.notifier).fetchChatMessages(widget.ticketId);
      if (mounted) setState(() { _chatMessages.clear(); _chatMessages.addAll(messages); _isChatLoading = false; });
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: _allowedExtensions, withData: true);
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

  Future<void> _downloadFile(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) { await launchUrl(uri, mode: LaunchMode.externalApplication); }
    else { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not download file'), backgroundColor: Colors.red)); } }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).user?.role.toLowerCase();
    RequestModel? currentTicket;

    if (role == 'management') {
      final mgmtState = ref.watch(roleManagementProvider);
      try {
        currentTicket = mgmtState.requests.firstWhere((r) => r.id == widget.ticketId || r.slNo == widget.ticketId);
      } catch (_) { if (mgmtState.requests.isNotEmpty) currentTicket = mgmtState.requests.first; }
    } else {
      final paginatedState = ref.watch(requestProvider);
      try {
        currentTicket = paginatedState.requests.firstWhere((r) => r.id == widget.ticketId || r.slNo == widget.ticketId);
      } catch (_) { if (paginatedState.requests.isNotEmpty) currentTicket = paginatedState.requests.first; }
    }

    if (currentTicket == null) return const Center(child: CircularProgressIndicator());
    final bool isChatDisabled = currentTicket.isClosed || currentTicket.acknowledgement != null;

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
                  const SizedBox(width: 4),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 20)),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: _isChatLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(controller: controller, padding: const EdgeInsets.all(24), itemCount: _chatMessages.length, itemBuilder: (context, index) => _buildChatBubble(_chatMessages[index], currentTicket!)),
            ),
            _buildInputSection(currentTicket!),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection(RequestModel ticket) {
    final bool isChatDisabled = ticket.isClosed || ticket.acknowledgement != null;
    if (isChatDisabled) {
      return Container(padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + MediaQuery.of(context).viewInsets.bottom), decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))), child: Container(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16), decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFEE2E2))), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.lock_outline, size: 18, color: Color(0xFFEF4444)), SizedBox(width: 12), Expanded(child: Text('This ticket has been closed. Chat is disabled.', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center))])));
    }
    return Container(padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + MediaQuery.of(context).viewInsets.bottom), decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))), child: Column(mainAxisSize: MainAxisSize.min, children: [if (_stagedFile != null) ListTile(dense: true, leading: const Icon(Icons.attach_file, size: 16, color: Color(0xFF5C59E8)), title: Text(_stagedFile!.name, style: const TextStyle(fontSize: 12)), trailing: IconButton(onPressed: () => setState(() => _stagedFile = null), icon: const Icon(Icons.close, size: 16, color: Colors.red))), Row(children: [IconButton(onPressed: _pickFile, icon: const Icon(Icons.attach_file, color: Colors.grey)), Expanded(child: TextField(controller: _messageController, decoration: const InputDecoration(hintText: 'Type your message...', border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false))), IconButton(onPressed: _isSending ? null : _sendMessage, icon: _isSending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send, color: Color(0xFF5C59E8)))])]));
  }

  Widget _buildChatBubble(ChatModel chat, RequestModel ticket) {
    final authState = ref.read(authProvider);
    final user = authState.user;
    final bool isMe = chat.senderId == user?.userId;
    final String chatText = chat.text?.toLowerCase() ?? '';
    final String status = chat.status?.toLowerCase() ?? '';
    final bool isApproved = status == 'approved' || chatText.contains('approved the request');
    final bool isChecking = status == 'checking' || chatText.contains('checking the request');
    final bool isRejected = status == 'rejected' || chatText.contains('rejected the request');
    final bool isForwarded = status == 'forwarded' || chatText.contains('forwarded');
    final bool isNotResolved = chatText.contains('not resolved') || chatText.contains('not received');
    final bool isResolved = (status == 'resolved' || chatText.contains('resolved') || chatText.contains('received') || chatText.contains('receipt') || chatText.contains('confirmed receipt')) && !isNotResolved && !chatText.contains('resolution submitted');
    final bool isClosureMessage = status == 'closed' || chatText.contains('ticket closed') || chatText.contains('resolution submitted') || (chatText.contains('officially closed') && !isResolved);

    Color cardBg = const Color(0xFFF8FAFC); Color borderColor = const Color(0xFFE2E8F0); Color primaryColor = const Color(0xFF64748B); IconData statusIcon = Icons.message_outlined; String pillLabel = "PURPOSE";
    if (isApproved || isResolved) { cardBg = const Color(0xFFF0FDF4); borderColor = const Color(0xFFDCFCE7); primaryColor = const Color(0xFF10B981); statusIcon = Icons.check_circle_outline; pillLabel = isResolved ? "RESOLVED" : "APPROVED"; }
    else if (isForwarded) { cardBg = const Color(0xFFF0F7FF); borderColor = const Color(0xFFD0E7FF); primaryColor = const Color(0xFF3B82F6); statusIcon = Icons.shortcut; pillLabel = "FORWARDED"; }
    else if (isChecking) { cardBg = const Color(0xFFFFFBEB); borderColor = const Color(0xFFFEF3C7); primaryColor = const Color(0xFFF59E0B); statusIcon = Icons.access_time; pillLabel = "CHECKING"; }
    else if (isRejected || isNotResolved) { cardBg = const Color(0xFFFEF2F2); borderColor = const Color(0xFFFEE2E2); primaryColor = const Color(0xFFEF4444); statusIcon = Icons.cancel_outlined; pillLabel = isRejected ? "REJECTED" : "NOT RESOLVED"; }
    else if (isClosureMessage) { cardBg = const Color(0xFFFEF2F2); borderColor = const Color(0xFFFEE2E2); primaryColor = const Color(0xFFEF4444); statusIcon = Icons.lock_outline; }

    return Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor, width: 1.5)), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(statusIcon, size: 18, color: primaryColor), const SizedBox(width: 10), Expanded(child: (isClosureMessage) ? const SizedBox.shrink() : Text(isMe && user != null ? "${user.department} - ${user.role}" : (chat.senderDepartment == 'N/A' || chat.senderDepartment == 'System') ? (chat.senderRole.toLowerCase().contains('requestor') ? "${ticket.department} - ${chat.senderRole}" : "${ticket.assignedDepartment ?? ticket.department} - ${chat.senderRole}") : "${chat.senderDepartment} - ${chat.senderRole}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF1E293B)))), Text(DateFormat('d/M/yyyy - hh:mm a').format(chat.createdAt), style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500))]), const SizedBox(height: 10), if (!isClosureMessage) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: primaryColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Text("$pillLabel: ${ticket.title.toUpperCase()}", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: primaryColor))), const SizedBox(height: 12), if (isForwarded) Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Row(mainAxisSize: MainAxisSize.min, children: [const Text("Dept: ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))), Text(chat.originalDept ?? ticket.department, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, decoration: TextDecoration.lineThrough, color: Colors.grey)), const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_forward, size: 12, color: Color(0xFF475569))), Text(chat.changedDept ?? ticket.assignedDepartment ?? 'N/A', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: primaryColor))])), Text(chat.text ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.5, fontWeight: FontWeight.w500)), if (chat.fileUrl != null || (isClosureMessage && ticket.attachedFileUrl != null)) Padding(padding: const EdgeInsets.only(top: 12), child: InkWell(onTap: () => _previewChatAttachment(chat), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(8), border: Border.all(color: primaryColor.withOpacity(0.3))), child: Row(children: [Icon(Icons.insert_drive_file, size: 16, color: primaryColor), const SizedBox(width: 8), Expanded(child: Text(chat.fileName ?? ticket.attachedFileName ?? 'Attachment', style: TextStyle(fontSize: 11, color: primaryColor, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)), IconButton(onPressed: () => _downloadFile(chat.fileUrl ?? ticket.attachedFileUrl!), icon: Icon(Icons.download_rounded, size: 18, color: primaryColor), padding: EdgeInsets.zero, constraints: const BoxConstraints())]))))])));
  }

  void _previewChatAttachment(ChatModel chat) {
    if (chat.fileUrl != null) {
      showDialog(context: context, builder: (context) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600), child: Column(mainAxisSize: MainAxisSize.min, children: [AppBar(title: Text(chat.fileName ?? 'Attachment Preview'), automaticallyImplyLeading: false, actions: [IconButton(onPressed: () => _downloadFile(chat.fileUrl!), icon: const Icon(Icons.download), tooltip: 'Download'), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]), Expanded(child: Padding(padding: const EdgeInsets.all(16.0), child: _buildChatAttachmentPreview(chat)))]))));
    }
  }

  Widget _buildChatAttachmentPreview(ChatModel chat) {
    final fileName = chat.fileName?.toLowerCase() ?? '';
    final url = chat.fileUrl ?? '';
    if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg') || fileName.endsWith('.png') || fileName.endsWith('.gif') || fileName.endsWith('.webp')) {
      return Image.network(url, fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) => const Center(child: Text('Failed to load image')), loadingBuilder: (context, child, loadingProgress) => loadingProgress == null ? child : const Center(child: CircularProgressIndicator()));
    }
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.insert_drive_file, size: 64, color: Colors.grey), const SizedBox(height: 16), Text('Preview not available for this file type.', style: TextStyle(color: Colors.grey[600])), const SizedBox(height: 8), Text(chat.fileName ?? '', style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 24), ElevatedButton.icon(onPressed: () => _downloadFile(url), icon: const Icon(Icons.download), label: const Text('Download File'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5C59E8), foregroundColor: Colors.white))]));
  }
}
