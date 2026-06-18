import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../models/request_model.dart';
import '../models/chat_model.dart';
import '../core/services/api_service.dart';
import '../core/services/request_api.dart';
import '../models/user_model.dart';
import 'auth_provider.dart';

class PaginatedRequestState {
  final List<RequestModel> requests;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final bool hasNext;
  final bool hasPrev;
  final bool isLoading;

  final List<String> filterNames;
  final List<String> filterDepts;
  final List<String> filterAssignedDepts;
  final List<String> filterStatuses;

  final String scope;
  final String? selectedName;
  final String? selectedDept;
  final String? selectedAssignedDept;
  final List<String> selectedStatuses;
  final String? selectedDate;
  final String? startDate;
  final String? endDate;
  final String search;

  PaginatedRequestState({
    required this.requests,
    this.currentPage = 1,
    this.totalPages = 1,
    this.totalItems = 0,
    this.hasNext = false,
    this.hasPrev = false,
    this.isLoading = false,
    this.filterNames = const [],
    this.filterDepts = const [],
    this.filterAssignedDepts = const [],
    this.filterStatuses = const [],
    this.scope = 'all',
    this.selectedName,
    this.selectedDept,
    this.selectedAssignedDept,
    this.selectedStatuses = const [],
    this.selectedDate,
    this.startDate,
    this.endDate,
    this.search = '',
  });

  PaginatedRequestState copyWith({
    List<RequestModel>? requests,
    int? currentPage,
    int? totalPages,
    int? totalItems,
    bool? hasNext,
    bool? hasPrev,
    bool? isLoading,
    List<String>? filterNames,
    List<String>? filterDepts,
    List<String>? filterAssignedDepts,
    List<String>? filterStatuses,
    String? scope,
    String? Function()? selectedName,
    String? Function()? selectedDept,
    String? Function()? selectedAssignedDept,
    List<String>? selectedStatuses,
    String? Function()? selectedDate,
    String? Function()? startDate,
    String? Function()? endDate,
    String? search,
  }) {
    final nextCurrentPage = currentPage ?? this.currentPage;
    final nextTotalPages = totalPages ?? this.totalPages;

    return PaginatedRequestState(
      requests: requests ?? this.requests,
      currentPage: nextCurrentPage,
      totalPages: nextTotalPages,
      totalItems: totalItems ?? this.totalItems,
      hasNext: hasNext ?? (nextCurrentPage < nextTotalPages),
      hasPrev: hasPrev ?? (nextCurrentPage > 1),
      isLoading: isLoading ?? this.isLoading,
      filterNames: filterNames ?? this.filterNames,
      filterDepts: filterDepts ?? this.filterDepts,
      filterAssignedDepts: filterAssignedDepts ?? this.filterAssignedDepts,
      filterStatuses: filterStatuses ?? this.filterStatuses,
      scope: scope ?? this.scope,
      selectedName: selectedName != null ? selectedName() : this.selectedName,
      selectedDept: selectedDept != null ? selectedDept() : this.selectedDept,
      selectedAssignedDept: selectedAssignedDept != null ? selectedAssignedDept() : this.selectedAssignedDept,
      selectedStatuses: selectedStatuses ?? this.selectedStatuses,
      selectedDate: selectedDate != null ? selectedDate() : this.selectedDate,
      startDate: startDate != null ? startDate() : this.startDate,
      endDate: endDate != null ? endDate() : this.endDate,
      search: search ?? this.search,
    );
  }

  PaginatedRequestState clearFilter({
    bool name = false,
    bool dept = false,
    bool assignedDept = false,
    bool date = false,
    bool range = false,
    bool status = false,
  }) {
    return PaginatedRequestState(
      requests: requests,
      currentPage: currentPage,
      totalPages: totalPages,
      totalItems: totalItems,
      hasNext: hasNext,
      hasPrev: hasPrev,
      isLoading: isLoading,
      filterNames: filterNames,
      filterDepts: filterDepts,
      filterAssignedDepts: filterAssignedDepts,
      filterStatuses: filterStatuses,
      scope: scope,
      selectedName: name ? null : selectedName,
      selectedDept: dept ? null : selectedDept,
      selectedAssignedDept: assignedDept ? null : selectedAssignedDept,
      selectedStatuses: status ? [] : selectedStatuses,
      selectedDate: date ? null : selectedDate,
      startDate: range ? null : startDate,
      endDate: range ? null : endDate,
      search: search,
    );
  }
}

class RequestNotifier extends StateNotifier<PaginatedRequestState> {
  final RequestApi _requestApi;
  final Ref _ref;

  RequestNotifier(this._requestApi, this._ref) : super(PaginatedRequestState(requests: [])) {
    fetchFilterOptions();
  }

  static const String _lastMsgIdKey = 'last_seen_msg_id_';

  Future<void> updateFilters({
    String? scope,
    String? name,
    String? dept,
    String? assignedDept,
    List<String>? statuses,
    String? date,
    String? startDate,
    String? endDate,
    String? search,
    bool clearName = false,
    bool clearDept = false,
    bool clearAssignedDept = false,
    bool clearDate = false,
    bool clearRange = false,
    bool clearStatus = false,
  }) async {
    bool resetName = clearName;
    bool resetAssignedDept = clearAssignedDept;

    if (scope == 'sent') resetName = true;
    if (scope == 'received') resetAssignedDept = true;

    if (resetName || clearDept || resetAssignedDept || clearDate || clearRange || clearStatus) {
      state = state.clearFilter(
        name: resetName,
        dept: clearDept,
        assignedDept: resetAssignedDept,
        date: clearDate,
        range: clearRange,
        status: clearStatus,
      );
    }

    state = state.copyWith(
      scope: scope,
      selectedName: name != null ? () => name : null,
      selectedDept: dept != null ? () => dept : null,
      selectedAssignedDept: assignedDept != null ? () => assignedDept : null,
      selectedStatuses: statuses,
      selectedDate: date != null ? () => date : null,
      startDate: startDate != null ? () => startDate : null,
      endDate: endDate != null ? () => endDate : null,
      search: search,
    );

    await fetchRequests(page: 1);
  }

  Future<void> fetchFilterOptions() async {
    try {
      final data = await _requestApi.fetchFilterOptions();
      state = state.copyWith(
        filterNames: List<String>.from(data['names'] ?? []),
        filterDepts: List<String>.from(data['depts'] ?? []),
        filterAssignedDepts: List<String>.from(data['assignedDepts'] ?? []),
        filterStatuses: List<String>.from(data['assignedStatuses'] ?? []),
      );
    } catch (e) {
      debugPrint('DEBUG: Fetch Filter Options Error: $e');
    }
  }

  Future<List<UserModel>> fetchUsersByDept(String depts) async {
    try {
      final listData = await _requestApi.fetchUsersByDept(depts);
      return listData.map((json) => UserModel.fromMap(json)).toList();
    } catch (e) {
      debugPrint('DEBUG: fetchUsersByDept Error: $e');
      return [];
    }
  }

  Future<List<String>> fetchAllDepartments() async {
    try {
      return await _requestApi.fetchAllDepartments();
    } catch (e) {
      debugPrint('DEBUG: fetchAllDepartments Error: $e');
      return [];
    }
  }

  Future<void> fetchRequests({
    int page = 1,
    String? scope,
    String? name,
    String? dept,
    String? assignedDept,
    List<String>? statuses,
    String? date,
    String? search,
  }) async {
    final authState = _ref.read(authProvider);
    final user = authState.user;

    final String path = user?.role.toLowerCase() == 'management'
        ? '/requests/hod-pending'
        : '/requests';

    state = state.copyWith(
      scope: scope,
      selectedName: name != null ? () => name : null,
      selectedDept: dept != null ? () => dept : null,
      selectedAssignedDept: assignedDept != null ? () => assignedDept : null,
      selectedStatuses: statuses,
      selectedDate: date != null ? () => date : null,
      search: search,
      isLoading: true,
      currentPage: page,
    );

    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': '50',
        'scope': state.scope,
      };

      if (state.scope == 'sent' && user != null) {
        queryParams['name'] = user.name;
      } else if (state.scope == 'received' && user != null) {
        queryParams['assignedDept'] = user.department;
      }

      if (state.selectedName != null && state.scope != 'sent') {
        queryParams['name'] = state.selectedName!;
      }
      if (state.selectedDept != null) queryParams['dept'] = state.selectedDept!;
      if (state.selectedAssignedDept != null && state.scope != 'received') {
        queryParams['assignedDept'] = state.selectedAssignedDept!;
      }

      if (state.selectedStatuses.isNotEmpty) {
        final statusList = state.selectedStatuses.join(',');
        queryParams['assignedStatus'] = statusList;
        queryParams['status'] = statusList;
        queryParams['overallStatus'] = statusList;
      }

      if (state.search.isNotEmpty) queryParams['search'] = state.search;

      final dynamic decodedData = await _requestApi.fetchRequests(path, queryParams);

      List<dynamic> listData = [];
      int totalItems = 0;
      int totalPages = 1;

      if (decodedData is Map) {
        listData = (decodedData['requests'] ?? decodedData['data'] ?? []) as List<dynamic>;
        if (decodedData['pagination'] != null) {
          final p = decodedData['pagination'];
          totalItems = p['total'] ?? 0;
          totalPages = p['totalPages'] ?? 1;
        }
      } else if (decodedData is List) {
        listData = decodedData as List<dynamic>;
        totalItems = decodedData.length;
        totalPages = 1;
      }

      final mappedRequests = listData.map((json) => RequestModel.fromMap(json as Map<String, dynamic>)).toList();

      List<RequestModel> filteredRequests = mappedRequests;

      if (state.selectedName != null) {
        final filterName = state.selectedName!.toLowerCase();
        filteredRequests = filteredRequests.where((r) => r.userName.toLowerCase() == filterName).toList();
      }

      if (state.selectedDept != null) {
        final filterDept = state.selectedDept!.toLowerCase();
        filteredRequests = filteredRequests.where((r) => r.department.toLowerCase() == filterDept).toList();
      }

      if (state.selectedAssignedDept != null) {
        final filterAssignedDept = state.selectedAssignedDept!.toLowerCase();
        filteredRequests = filteredRequests.where((r) {
          return r.assignedDepartments?.any((d) => d.toLowerCase() == filterAssignedDept) ?? false;
        }).toList();
      }

      if (state.selectedStatuses.isNotEmpty) {
        final lowercaseSelectedStatuses = state.selectedStatuses.map((s) => s.toLowerCase()).toList();
        filteredRequests = filteredRequests.where((r) {
          final overallStatus = r.overallStatus.name.toLowerCase();
          return lowercaseSelectedStatuses.any((s) => overallStatus.contains(s) || s.contains(overallStatus));
        }).toList();
      }

      if (state.search.isNotEmpty) {
        final q = state.search.toLowerCase();
        filteredRequests = filteredRequests.where((r) {
          return r.userName.toLowerCase().contains(q) ||
                 r.slNo.toLowerCase().contains(q) ||
                 r.empId.toLowerCase().contains(q) ||
                 r.department.toLowerCase().contains(q) ||
                 r.designation.toLowerCase().contains(q) ||
                 r.location.toLowerCase().contains(q) ||
                 r.title.toLowerCase().contains(q) ||
                 r.description.toLowerCase().contains(q) ||
                 r.overallStatus.name.toLowerCase().contains(q);
        }).toList();
      }

      if (state.selectedDate != null) {
        filteredRequests = filteredRequests.where((request) {
          final requestDateFormatted = DateFormat('yyyy-MM-dd').format(request.date);
          return requestDateFormatted == state.selectedDate;
        }).toList();
      }

      if (state.startDate != null && state.endDate != null) {
        final start = DateFormat('yyyy-MM-dd').parse(state.startDate!);
        final end = DateFormat('yyyy-MM-dd').parse(state.endDate!).add(const Duration(days: 1));
        filteredRequests = filteredRequests.where((request) {
          return request.date.isAfter(start) && request.date.isBefore(end);
        }).toList();
      }

      state = state.copyWith(
        requests: filteredRequests,
        totalPages: totalPages,
        totalItems: totalItems,
        isLoading: false,
      );

      _sortRequests();
      _checkAllUnreadStatus();
    } catch (e) {
      debugPrint('DEBUG: Fetch Requests Error: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> fetchRequestById(String id) async {
    try {
      final data = await _requestApi.fetchRequestById(id);
      final updatedReq = RequestModel.fromMap(data as Map<String, dynamic>);

      bool found = false;
      final newList = state.requests.map((req) {
        if (req.id == updatedReq.id || req.slNo == updatedReq.slNo) {
          found = true;
          return updatedReq.copyWith(
            unreadChatCount: req.unreadChatCount,
            isRead: updatedReq.isRead || req.isRead,
          );
        }
        return req;
      }).toList();

      if (!found) {
        newList.add(updatedReq);
      }

      state = state.copyWith(requests: newList);
      _sortRequests();
    } catch (e) {
      debugPrint('DEBUG: fetchRequestById Error: $e');
    }
  }

  Future<void> fetchHODPendingRequests() async {
    state = state.copyWith(isLoading: true);
    try {
      final dynamic decodedData = await _requestApi.fetchHODPendingRequests();

      List<dynamic> listData = [];
      if (decodedData is List) {
        listData = decodedData as List<dynamic>;
      } else if (decodedData is Map) {
        listData = (decodedData['requests'] ?? decodedData['data'] ?? []) as List<dynamic>;
      }

      final mappedRequests = listData.map((json) => RequestModel.fromMap(json as Map<String, dynamic>)).toList();

      state = state.copyWith(
        requests: mappedRequests,
        isLoading: false,
        totalPages: 1,
        currentPage: 1,
      );
      _sortRequests();
    } catch (e) {
      debugPrint('DEBUG: Fetch HOD Pending Requests Error: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _checkAllUnreadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final authState = _ref.read(authProvider);
    final user = authState.user;
    if (user == null) return;

    final updatedRequests = <RequestModel>[];
    for (var req in state.requests) {
      try {
        final messages = await fetchChatMessages(req.id);
        if (messages.isNotEmpty) {
          final lastMsg = messages.last;
          final lastSeenId = prefs.getInt('$_lastMsgIdKey${req.id}') ?? 0;
          if (lastMsg.id > lastSeenId && lastMsg.senderId != user.userId) {
            final unreadCount = messages.where((m) => m.id > lastSeenId && m.senderId != user.userId).length;
            updatedRequests.add(req.copyWith(unreadChatCount: unreadCount));
          } else {
            updatedRequests.add(req.copyWith(unreadChatCount: 0));
          }
        } else { updatedRequests.add(req); }
      } catch (_) { updatedRequests.add(req); }
    }
    state = state.copyWith(requests: updatedRequests);
    _sortRequests();
  }

  Future<List<ChatModel>> fetchChatMessages(String ticketId) async {
    try {
      final data = await _requestApi.fetchChatMessages(ticketId);
      return data.map((json) => ChatModel.fromMap(json)).toList();
    } catch (e) { return []; }
  }

  Future<void> markChatAsRead(String ticketId) async {
    final messages = await fetchChatMessages(ticketId);
    if (messages.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_lastMsgIdKey$ticketId', messages.last.id);
      state = state.copyWith(requests: [
        for (final req in state.requests)
          if (req.id == ticketId || req.slNo == ticketId) req.copyWith(unreadChatCount: 0) else req,
      ]);
      _sortRequests();
    }
  }

  void _sortRequests() {
    final sorted = List<RequestModel>.from(state.requests);
    sorted.sort((a, b) {
      final aUnread = !a.isRead || a.unreadChatCount > 0;
      final bUnread = !b.isRead || b.unreadChatCount > 0;

      if (aUnread && !bUnread) return -1;
      if (!aUnread && bUnread) return 1;

      return b.date.compareTo(a.date);
    });
    state = state.copyWith(requests: sorted);
  }

  Future<ChatModel?> sendChatMessage(String ticketId, String text, String type) async {
    try {
      final data = await _requestApi.sendChatMessage(ticketId, text, type);
      final newMessage = ChatModel.fromMap(data);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_lastMsgIdKey$ticketId', newMessage.id);
      return newMessage;
    } catch (e) {
      return null;
    }
  }

  Future<ChatModel?> sendFileAttachment(String ticketId, {String? text, String? filePath, Uint8List? fileBytes, String? fileName}) async {
    try {
      final Map<String, String> fields = {
        'type': 'file',
        'text': (text == null || text.trim().isEmpty) ? 'Attachment' : text,
      };

      final data = await _requestApi.sendFileAttachment(
        ticketId,
        fields: fields,
        filePath: filePath,
        fileBytes: fileBytes,
        fileName: fileName,
      );

      final newMessage = ChatModel.fromMap(data);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_lastMsgIdKey$ticketId', newMessage.id);
      return newMessage;
    } catch (e) {
      debugPrint('DEBUG: sendFileAttachment exception: $e');
    }
    return null;
  }

  Future<bool> addRequest(RequestModel newRequest, {List<PlatformFile>? multiFiles}) async {
    try {
      final fields = {
        'purpose': newRequest.title,
        'assignedDept': (newRequest.assignedDepartments?.length == 1)
            ? newRequest.assignedDepartments!.first
            : json.encode(newRequest.assignedDepartments),
        'assignedPersonName': json.encode(newRequest.assignedPersons),
        'dueDate': newRequest.dueDate?.toIso8601String() ?? '',
        'description': newRequest.description
      };

      List<FileData>? fileDataList;
      if (multiFiles != null && multiFiles.isNotEmpty) {
        fileDataList = multiFiles.map((f) => FileData(
          path: kIsWeb ? null : f.path,
          bytes: f.bytes,
          name: f.name,
        )).toList();
      }

      final requestData = await _requestApi.addRequest(
        data: newRequest.toMap(),
        fields: fields,
        files: fileDataList,
        filePath: newRequest.attachedFilePath,
        fileBytes: newRequest.attachedFileBytes,
        fileName: newRequest.attachedFileName,
      );

      final createdRequest = RequestModel.fromMap(requestData as Map<String, dynamic>);

      state = state.copyWith(
        requests: [createdRequest, ...state.requests],
        totalItems: state.totalItems + 1,
      );
      _sortRequests();
      return true;
    } catch (e) {
      debugPrint('DEBUG: Add Request Catch Error: $e');
      return false;
    }
  }

  Future<bool> updateStatus(String ticketId, RequestStatus status, {String comment = '', bool isRM = false, bool isHOD = false, bool isAdmin = false, bool isDeptHOD = false, bool isManagement = false, DateTime? checkingDeadline, String? checkingReason}) async {
    try {
      String decision = 'Pending';
      Map<String, dynamic> body = {'comment': comment};

      if (status == RequestStatus.approved) decision = 'Approved';
      else if (status == RequestStatus.rejected) decision = 'Rejected';
      else if (status == RequestStatus.checking) {
        decision = 'Checking';
        if (checkingDeadline != null) {
          body['checkingDeadline'] = checkingDeadline.toIso8601String();
        }
        if (checkingReason != null) {
          body['checkingReason'] = checkingReason;
          body['checkingDeadlineReason'] = checkingReason;
          body['checking_reason'] = checkingReason;
        }
      }
      else if (status == RequestStatus.closed) decision = 'Closed';
      else if (status == RequestStatus.resolved) decision = 'Resolved';

      body['decision'] = decision;

      final data = await _requestApi.updateApproval(ticketId, body);
      final updatedReq = RequestModel.fromMap(data as Map<String, dynamic>);

      state = state.copyWith(requests: [
        for (final req in state.requests)
          if (req.id == updatedReq.id) updatedReq.copyWith(unreadChatCount: req.unreadChatCount) else req
      ]);
      
      if (status == RequestStatus.checking && checkingDeadline != null) {
           final formattedDate = DateFormat('dd/MM/yyyy').format(checkingDeadline);
           final chatText = "Checking status set with deadline: $formattedDate\nReason: ${checkingReason ?? 'No reason provided.'}";
           await sendChatMessage(ticketId, chatText, 'status_update');
      }

      _sortRequests();
      return true;
    } catch (e) {
      debugPrint('DEBUG: updateStatus error: $e');
      return false;
    }
  }

  Future<bool> approveAndAssignInternal(String ticketId, List<String> empIds, List<String> names, {String comment = 'Approved & assigned to internal team.'}) async {
    try {
      final data = await _requestApi.updateApproval(ticketId, {
        'decision': 'Approved',
        'comment': comment,
        'assignedPersonEmpId': empIds.join(', '),
        'assignedPersonName': names.join(', '),
      });

      final updatedReq = RequestModel.fromMap(data as Map<String, dynamic>);

      state = state.copyWith(requests: [
        for (final req in state.requests)
          if (req.id == updatedReq.id) updatedReq.copyWith(unreadChatCount: req.unreadChatCount) else req
      ]);
      _sortRequests();
      return true;
    } catch (e) {
      debugPrint('DEBUG: approveAndAssignInternal error: $e');
      return false;
    }
  }

  Future<bool> approveAndForwardDept(String ticketId, List<String> depts, {String comment = ''}) async {
    try {
      final data = await _requestApi.updateApproval(ticketId, {
        'decision': 'Forwarded',
        'comment': comment.isEmpty ? 'Approved and forwarded to ${depts.join(', ')} for technical fulfilment.' : comment,
        'newDept': depts.join(', '),
        'dualDept': true
      });

      final updatedReq = RequestModel.fromMap(data as Map<String, dynamic>);

      state = state.copyWith(requests: [
        for (final req in state.requests)
          if (req.id == updatedReq.id) updatedReq.copyWith(unreadChatCount: req.unreadChatCount) else req
      ]);
      _sortRequests();
      return true;
    } catch (e) {
      debugPrint('DEBUG: approveAndForwardDept error: $e');
      return false;
    }
  }

  Future<bool> updateHODManagementApproval(String ticketId, RequestStatus status, {String comment = ''}) async {
    try {
      String decision = 'Pending';
      if (status == RequestStatus.approved) decision = 'Approved';
      else if (status == RequestStatus.rejected) decision = 'Rejected';

      final data = await _requestApi.updateHODApproval(ticketId, {
        'decision': decision,
        'comment': comment,
      });

      final updatedReq = RequestModel.fromMap(data as Map<String, dynamic>);

      state = state.copyWith(requests: [
        for (final req in state.requests)
          if (req.id == updatedReq.id) updatedReq.copyWith(unreadChatCount: req.unreadChatCount) else req
      ]);
      _sortRequests();
      return true;
    } catch (e) {
      debugPrint('DEBUG: updateHODManagementApproval error: $e');
      return false;
    }
  }

  Future<bool> forwardRequest(String ticketId, String newDept, {bool isRM = false, bool isHOD = false, bool isDeptHOD = false, bool isAdmin = false, bool isManagement = false}) async {
    try {
      final data = await _requestApi.updateApproval(ticketId, {
        'decision': 'Forwarded',
        'newDept': newDept,
        'comment': 'Ticket forwarded to $newDept',
        'isRM': isRM,
        'isHOD': isHOD,
        'isDeptHOD': isDeptHOD,
        'isAdmin': isAdmin,
        'isManagement': isManagement,
      });
      
      final updatedReq = RequestModel.fromMap(data as Map<String, dynamic>);

      state = state.copyWith(requests: [
        for (final req in state.requests)
          if (req.id == updatedReq.id) updatedReq.copyWith(unreadChatCount: req.unreadChatCount) else req
      ]);
      _sortRequests();
      return true;
    } catch (e) {
      debugPrint('DEBUG: forwardRequest error: $e');
      return false;
    }
  }

  Future<bool> closeTicket(String ticketId, String note, {String? filePath, Uint8List? fileBytes, String? fileName}) async {
    try {
      final Map<String, String> fields = {
        'note': note,
        'comment': note,
        'description': note,
        'resolutionNote': note,
        'resolution_note': note,
      };

      final data = await _requestApi.closeTicket(
        ticketId,
        fields,
        filePath: filePath,
        fileBytes: fileBytes,
        fileName: fileName,
      );

      final updatedReq = RequestModel.fromMap(data as Map<String, dynamic>);

      state = state.copyWith(requests: [
        for (final req in state.requests)
          if (req.id == updatedReq.id) updatedReq.copyWith(unreadChatCount: req.unreadChatCount) else req
      ]);
      _sortRequests();
      return true;
    } catch (e) {
      debugPrint('DEBUG: closeTicket Exception: $e');
      return false;
    }
  }

  Future<bool> acknowledgeRequest(String ticketId, String status) async {
    try {
      final data = await _requestApi.acknowledgeRequest(ticketId, status);
      RequestModel updatedReq = RequestModel.fromMap(data as Map<String, dynamic>);

      if (status.toLowerCase() == 'received') {
        updatedReq = updatedReq.copyWith(overallStatus: RequestStatus.closed);
      } else if (status.toLowerCase() == 'not received') {
        updatedReq = updatedReq.copyWith(overallStatus: RequestStatus.open);
      }

      state = state.copyWith(requests: [
        for (final req in state.requests)
          if (req.id == updatedReq.id) updatedReq.copyWith(unreadChatCount: req.unreadChatCount) else req
      ]);
      _sortRequests();
      return true;
    } catch (e) {
      debugPrint('DEBUG: acknowledgeRequest error: $e');
      return false;
    }
  }

  Future<void> markAsRead(String slNo) async {
    try {
      final request = state.requests.firstWhere((r) => r.id == slNo || r.slNo == slNo);
      await _requestApi.markAsRead(request.id);
      state = state.copyWith(requests: [for (final req in state.requests) if (req.id == request.id) req.copyWith(isRead: true) else req]);
      _sortRequests();
    } catch (_) { }
  }

  Future<void> markAsUnread(String ticketId) async {
    try {
      await _requestApi.markAsUnread(ticketId);
      state = state.copyWith(requests: [
        for (final req in state.requests)
          if (req.id == ticketId) req.copyWith(isRead: false) else req
      ]);
      _sortRequests();
    } catch (_) { }
  }
}

final requestProvider = StateNotifierProvider<RequestNotifier, PaginatedRequestState>((ref) {
  final requestApi = ref.watch(requestApiProvider);
  return RequestNotifier(requestApi, ref);
});
