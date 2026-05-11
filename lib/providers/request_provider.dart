import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/request_model.dart';
import '../models/chat_model.dart';
import '../core/services/api_service.dart';
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
    String? selectedName,
    String? selectedDept,
    String? selectedAssignedDept,
    List<String>? selectedStatuses,
    String? selectedDate,
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
      selectedName: selectedName ?? this.selectedName, 
      selectedDept: selectedDept ?? this.selectedDept,
      selectedAssignedDept: selectedAssignedDept ?? this.selectedAssignedDept,
      selectedStatuses: selectedStatuses ?? this.selectedStatuses,
      selectedDate: selectedDate ?? this.selectedDate,
      search: search ?? this.search,
    );
  }
  
  PaginatedRequestState clearFilter({
    bool name = false,
    bool dept = false,
    bool assignedDept = false,
    bool date = false,
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
      search: search,
    );
  }
}

class RequestNotifier extends StateNotifier<PaginatedRequestState> {
  final ApiService _apiService;
  final Ref _ref;

  RequestNotifier(this._apiService, this._ref) : super(PaginatedRequestState(requests: [])) {
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
    String? search,
    bool clearName = false,
    bool clearDept = false,
    bool clearAssignedDept = false,
    bool clearDate = false,
    bool clearStatus = false,
  }) async {
    bool resetName = clearName;
    bool resetAssignedDept = clearAssignedDept;

    if (scope == 'sent') resetName = true;
    if (scope == 'received') resetAssignedDept = true;

    if (resetName || clearDept || resetAssignedDept || clearDate || clearStatus) {
      state = state.clearFilter(name: resetName, dept: clearDept, assignedDept: resetAssignedDept, date: clearDate, status: clearStatus);
    }
    
    state = state.copyWith(
      scope: scope,
      selectedName: name,
      selectedDept: dept,
      selectedAssignedDept: assignedDept,
      selectedStatuses: statuses,
      selectedDate: date,
      search: search,
    );

    await fetchRequests(page: 1);
  }

  Future<void> fetchFilterOptions() async {
    try {
      final response = await _apiService.get('/requests/filters');
      final data = json.decode(response.body);
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

    if (user?.role.toLowerCase() == 'management') {
      await fetchHODPendingRequests();
      return;
    }

    state = state.copyWith(
      scope: scope,
      selectedName: name,
      selectedDept: dept,
      selectedAssignedDept: assignedDept,
      selectedStatuses: statuses,
      selectedDate: date,
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
      
      if (state.selectedStatuses.isNotEmpty) queryParams['status'] = state.selectedStatuses.join(',');
      if (state.selectedDate != null) queryParams['date'] = state.selectedDate!;
      if (state.search.isNotEmpty) queryParams['search'] = state.search;

      final queryString = Uri(queryParameters: queryParams).query;
      final response = await _apiService.get('/requests?$queryString');
      final dynamic decodedData = json.decode(response.body);
      
      List<dynamic> listData = [];
      int totalItems = 0;
      int totalPages = 1;

      if (decodedData is Map) {
        listData = decodedData['requests'] ?? decodedData['data'] ?? [];
        if (decodedData['pagination'] != null) {
          final p = decodedData['pagination'];
          totalItems = p['total'] ?? 0;
          totalPages = p['totalPages'] ?? 1;
        }
      }
      
      final mappedRequests = listData.map((json) => RequestModel.fromMap(json as Map<String, dynamic>)).toList();
      
      state = state.copyWith(
        requests: mappedRequests,
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

  Future<void> fetchHODPendingRequests() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _apiService.get('/requests/hod-pending');
      final dynamic decodedData = json.decode(response.body);
      
      List<dynamic> listData = [];
      if (decodedData is List) {
        listData = decodedData;
      } else if (decodedData is Map) {
        listData = decodedData['requests'] ?? decodedData['data'] ?? [];
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
  }

  Future<List<ChatModel>> fetchChatMessages(String ticketId) async {
    try {
      final response = await _apiService.get('/requests/$ticketId/chat');
      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        final List<dynamic> data = decoded is List ? decoded : (decoded['data'] ?? []);
        return data.map((json) => ChatModel.fromMap(json)).toList();
      }
      return [];
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
    }
  }

  void _sortRequests() {
    final sorted = List<RequestModel>.from(state.requests);
    sorted.sort((a, b) => b.date.compareTo(a.date));
    state = state.copyWith(requests: sorted);
  }

  Future<ChatModel?> sendChatMessage(String ticketId, String text, String type) async {
    try {
      final response = await _apiService.post('/requests/$ticketId/chat', {'type': type, 'text': text});
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = json.decode(response.body);
        final data = (decoded is Map && decoded.containsKey('data')) ? decoded['data'] : decoded;
        final newMessage = ChatModel.fromMap(data);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('$_lastMsgIdKey$ticketId', newMessage.id);
        return newMessage;
      }
      return null;
    } catch (e) { 
      debugPrint('DEBUG: sendChatMessage error: $e');
      return null; 
    }
  }

  Future<ChatModel?> sendFileAttachment(String ticketId, {String? text, String? filePath, Uint8List? fileBytes, String? fileName}) async {
    try {
      final Map<String, String> fields = {
        'type': 'file',
        'text': (text == null || text.trim().isEmpty) ? 'Attachment' : text,
      };

      final streamedResponse = await _apiService.postMultipart(
        '/requests/$ticketId/chat',
        fields,
        filePath: filePath,
        fileBytes: fileBytes,
        fileName: fileName,
        fileKey: 'file', 
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = json.decode(response.body);
        final data = (decoded is Map && decoded.containsKey('data')) ? decoded['data'] : decoded;
        final newMessage = ChatModel.fromMap(data);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('$_lastMsgIdKey$ticketId', newMessage.id);
        return newMessage;
      }
    } catch (e) {
      debugPrint('DEBUG: sendFileAttachment exception: $e');
    }
    return null;
  }

  Future<bool> addRequest(RequestModel newRequest) async {
    try {
      http.Response response;
      if (newRequest.attachedFileBytes != null || newRequest.attachedFilePath != null) {
        final fields = {
          'purpose': newRequest.title, 
          'assignedDept': (newRequest.assignedDepartments?.length == 1) 
              ? newRequest.assignedDepartments!.first 
              : json.encode(newRequest.assignedDepartments),
          'assignedPersonName': json.encode(newRequest.assignedPersons),
          'dueDate': newRequest.dueDate?.toIso8601String() ?? '',
          'description': newRequest.description
        };

        final streamedResponse = await _apiService.postMultipart(
          '/requests', 
          fields, 
          filePath: newRequest.attachedFilePath, 
          fileBytes: newRequest.attachedFileBytes, 
          fileName: newRequest.attachedFileName,
          fileKey: 'file' 
        );
        response = await http.Response.fromStream(streamedResponse);
      } else {
        response = await _apiService.post('/requests', newRequest.toMap());
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decodedBody = json.decode(response.body);
        final requestData = decodedBody is Map && decodedBody.containsKey('data') ? decodedBody['data'] : decodedBody;
        final createdRequest = RequestModel.fromMap(requestData as Map<String, dynamic>);
        
        state = state.copyWith(
          requests: [createdRequest, ...state.requests],
          totalItems: state.totalItems + 1,
        );
        _sortRequests();
        return true;
      }
      return false;
    } catch (e) { 
      debugPrint('DEBUG: Add Request Catch Error: $e');
      return false; 
    }
  }

  Future<bool> updateStatus(String ticketId, RequestStatus status, {String comment = '', bool isRM = false, bool isHOD = false, bool isAdmin = false, bool isDeptHOD = false, bool isManagement = false}) async {
    try {
      String decision = 'Pending';
      if (status == RequestStatus.approved) decision = 'Approved';
      else if (status == RequestStatus.rejected) decision = 'Rejected';
      else if (status == RequestStatus.checking) decision = 'Checking';
      else if (status == RequestStatus.closed) decision = 'Closed';
      else if (status == RequestStatus.resolved) decision = 'Resolved';

      final response = await _apiService.patch('/requests/$ticketId/approval', {
        'decision': decision,
        'comment': comment,
      });

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = json.decode(response.body);
        final data = (decoded is Map && decoded.containsKey('data')) ? decoded['data'] : decoded;
        final updatedReq = RequestModel.fromMap(data);
        
        state = state.copyWith(requests: [
          for (final req in state.requests)
            if (req.id == updatedReq.id) updatedReq.copyWith(unreadChatCount: req.unreadChatCount) else req
        ]);
        _sortRequests();
        return true;
      }
      return false;
    } catch (e) { 
      debugPrint('DEBUG: updateStatus error: $e');
      return false; 
    }
  }

  Future<bool> updateHODManagementApproval(String ticketId, RequestStatus status, {String comment = ''}) async {
    try {
      String decision = 'Pending';
      if (status == RequestStatus.approved) decision = 'Approved';
      else if (status == RequestStatus.rejected) decision = 'Rejected';

      final response = await _apiService.patch('/requests/$ticketId/hod-approval', {
        'decision': decision,
        'comment': comment,
      });

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = json.decode(response.body);
        final data = (decoded is Map && decoded.containsKey('data')) ? decoded['data'] : decoded;
        final updatedReq = RequestModel.fromMap(data);
        
        state = state.copyWith(requests: [
          for (final req in state.requests)
            if (req.id == updatedReq.id) updatedReq.copyWith(unreadChatCount: req.unreadChatCount) else req
        ]);
        _sortRequests();
        return true;
      }
      return false;
    } catch (e) { 
      debugPrint('DEBUG: updateHODManagementApproval error: $e');
      return false; 
    }
  }

  Future<bool> forwardRequest(String ticketId, String newDept) async {
    try {
      final response = await _apiService.patch('/requests/$ticketId/approval', {
        'decision': 'Forwarded',
        'newDept': newDept,
        'comment': 'Ticket forwarded to $newDept'
      });
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = json.decode(response.body);
        final data = (decoded is Map && decoded.containsKey('data')) ? decoded['data'] : decoded;
        final updatedReq = RequestModel.fromMap(data);
        
        state = state.copyWith(requests: [
          for (final req in state.requests)
            if (req.id == updatedReq.id) updatedReq.copyWith(unreadChatCount: req.unreadChatCount) else req
        ]);
        _sortRequests();
        return true;
      }
      return false;
    } catch (e) { 
      debugPrint('DEBUG: forwardRequest error: $e');
      return false; 
    }
  }

  Future<bool> closeTicket(String ticketId, String resolutionNote, {String? filePath, Uint8List? fileBytes, String? fileName}) async {
    try {
      http.Response response;
      if (filePath != null || fileBytes != null) {
        final streamedResponse = await _apiService.patchMultipart('/requests/$ticketId/close', {'resolutionNote': resolutionNote}, filePath: filePath, fileBytes: fileBytes, fileName: fileName, fileKey: 'file');
        response = await http.Response.fromStream(streamedResponse);
      } else {
        response = await _apiService.patch('/requests/$ticketId/close', {'resolutionNote': resolutionNote});
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = json.decode(response.body);
        final data = (decoded is Map && decoded.containsKey('data')) ? decoded['data'] : decoded;
        final updatedReq = RequestModel.fromMap(data);
        
        state = state.copyWith(requests: [for (final req in state.requests) if (req.id == updatedReq.id) updatedReq.copyWith(unreadChatCount: req.unreadChatCount) else req]);
        _sortRequests();
        return true;
      }
      return false;
    } catch (e) { 
      debugPrint('DEBUG: closeTicket error: $e');
      return false; 
    }
  }

  Future<bool> acknowledgeRequest(String ticketId, String status) async {
    try {
      final response = await _apiService.patch('/requests/$ticketId/acknowledge', {
        'status': status,
      });

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = json.decode(response.body);
        final data = (decoded is Map && decoded.containsKey('data')) ? decoded['data'] : decoded;
        final updatedReq = RequestModel.fromMap(data);
        
        state = state.copyWith(requests: [
          for (final req in state.requests)
            if (req.id == updatedReq.id) updatedReq.copyWith(unreadChatCount: req.unreadChatCount) else req
        ]);
        _sortRequests();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('DEBUG: acknowledgeRequest error: $e');
      return false;
    }
  }

  Future<void> markAsRead(String slNo) async {
    try {
      final request = state.requests.firstWhere((r) => r.id == slNo || r.slNo == slNo);
      final response = await _apiService.patch('/requests/${request.id}/seen', {});
      if (response.statusCode >= 200 && response.statusCode < 300) {
        state = state.copyWith(requests: [for (final req in state.requests) if (req.id == request.id) req.copyWith(isRead: true) else req]);
      }
    } catch (_) { }
  }
}

final requestProvider = StateNotifierProvider<RequestNotifier, PaginatedRequestState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return RequestNotifier(apiService, ref);
});
