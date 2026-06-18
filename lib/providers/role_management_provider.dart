import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/services/role_management_api.dart';
import '../core/services/request_api.dart';
import '../models/request_model.dart';

class RoleManagementState {
  final List<RequestModel> requests;
  final int totalItems;
  final int currentPage;
  final int limit;
  final bool isLoading;

  final List<String> names;
  final List<String> requestorDepts;
  final List<String> assignedDepts;
  final Map<String, dynamic>? dateRange;
  final List<Map<String, dynamic>> hodStatuses;
  final List<Map<String, dynamic>> rmStatuses;
  final List<String> assignedStatuses;

  final String? selectedName;
  final String? selectedRequestorDept;
  final String? selectedAssignedDept;
  final String? selectedHodStatus;
  final String? selectedRmStatus;
  final String? selectedStatus;
  final String? startDate;
  final String? endDate;
  final String search;

  RoleManagementState({
    this.requests = const [],
    this.totalItems = 0,
    this.currentPage = 1,
    this.limit = 20,
    this.isLoading = false,
    this.names = const [],
    this.requestorDepts = const [],
    this.assignedDepts = const [],
    this.dateRange,
    this.hodStatuses = const [],
    this.rmStatuses = const [],
    this.assignedStatuses = const [],
    this.selectedName,
    this.selectedRequestorDept,
    this.selectedAssignedDept,
    this.selectedHodStatus,
    this.selectedRmStatus,
    this.selectedStatus,
    this.startDate,
    this.endDate,
    this.search = '',
  });

  int get totalPages => (totalItems / limit).ceil();
  bool get hasNext => currentPage < totalPages;
  bool get hasPrev => currentPage > 1;

  RoleManagementState copyWith({
    List<RequestModel>? requests,
    int? totalItems,
    int? currentPage,
    int? limit,
    bool? isLoading,
    List<String>? names,
    List<String>? requestorDepts,
    List<String>? assignedDepts,
    Map<String, dynamic>? dateRange,
    List<Map<String, dynamic>>? hodStatuses,
    List<Map<String, dynamic>>? rmStatuses,
    List<String>? assignedStatuses,
    String? Function()? selectedName,
    String? Function()? selectedRequestorDept,
    String? Function()? selectedAssignedDept,
    String? Function()? selectedHodStatus,
    String? Function()? selectedRmStatus,
    String? Function()? selectedStatus,
    String? Function()? startDate,
    String? Function()? endDate,
    String? search,
  }) {
    return RoleManagementState(
      requests: requests ?? this.requests,
      totalItems: totalItems ?? this.totalItems,
      currentPage: currentPage ?? this.currentPage,
      limit: limit ?? this.limit,
      isLoading: isLoading ?? this.isLoading,
      names: names ?? this.names,
      requestorDepts: requestorDepts ?? this.requestorDepts,
      assignedDepts: assignedDepts ?? this.assignedDepts,
      dateRange: dateRange ?? this.dateRange,
      hodStatuses: hodStatuses ?? this.hodStatuses,
      rmStatuses: rmStatuses ?? this.rmStatuses,
      assignedStatuses: assignedStatuses ?? this.assignedStatuses,
      selectedName: selectedName != null ? selectedName() : this.selectedName,
      selectedRequestorDept: selectedRequestorDept != null ? selectedRequestorDept() : this.selectedRequestorDept,
      selectedAssignedDept: selectedAssignedDept != null ? selectedAssignedDept() : this.selectedAssignedDept,
      selectedHodStatus: selectedHodStatus != null ? selectedHodStatus() : this.selectedHodStatus,
      selectedRmStatus: selectedRmStatus != null ? selectedRmStatus() : this.selectedRmStatus,
      selectedStatus: selectedStatus != null ? selectedStatus() : this.selectedStatus,
      startDate: startDate != null ? startDate() : this.startDate,
      endDate: endDate != null ? endDate() : this.endDate,
      search: search ?? this.search,
    );
  }
}

class RoleManagementNotifier extends StateNotifier<RoleManagementState> {
  final RoleManagementApi _api;
  final RequestApi _standardRequestApi;
  Timer? _debounce;

  RoleManagementNotifier(this._api, this._standardRequestApi) : super(RoleManagementState()) {
    fetchFilters();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> fetchFilters() async {
    debugPrint('DEBUG: RoleManagementNotifier - Entering fetchFilters');
    try {
      final results = await Future.wait([
        _api.fetchManagementFilters().catchError((e) {
          debugPrint('DEBUG: fetchManagementFilters error: $e');
          return <String, dynamic>{};
        }),
        _standardRequestApi.fetchFilterOptions().catchError((e) {
          debugPrint('DEBUG: fetchFilterOptions error: $e');
          return <String, dynamic>{};
        }),
      ]);

      final mgmtData = results[0];
      final stdData = results[1];

      List<String> getFilterList(dynamic source, String key) {
        final Set<String> uniqueItems = {};
        if (source is Map && source[key] is List) {
          uniqueItems.addAll((source[key] as List).map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty && e != 'null'));
        }
        return uniqueItems.toList()..sort();
      }

      List<Map<String, dynamic>> getStatusList(dynamic source, String key) {
        final List<Map<String, dynamic>> result = [];
        final Set<String> seenValues = {};
        if (source is Map && source[key] is List) {
          for (var item in source[key]) {
            String label, value;
            if (item is Map) {
              label = (item['label'] ?? item['name'] ?? item['value'] ?? '').toString();
              value = (item['value'] ?? item['id'] ?? label.toLowerCase()).toString();
            } else {
              label = item.toString();
              value = label.toLowerCase();
            }
            if (label.isNotEmpty && !seenValues.contains(value)) {
              result.add(<String, dynamic>{'label': label, 'value': value});
              seenValues.add(value);
            }
          }
        }
        return result;
      }

      var names = getFilterList(mgmtData, 'names');
      if (names.isEmpty) names = getFilterList(stdData, 'names');

      var rDepts = getFilterList(mgmtData, 'requestorDepts');
      if (rDepts.isEmpty) rDepts = getFilterList(stdData, 'depts');

      var aDepts = getFilterList(mgmtData, 'assignedDepts');
      if (aDepts.isEmpty) aDepts = getFilterList(stdData, 'assignedDepts');

      var hodS = getStatusList(mgmtData, 'hodStatuses');
      if (hodS.isEmpty) hodS = getStatusList(stdData, 'hodStatuses');

      var rmS = getStatusList(mgmtData, 'rmStatuses');
      if (rmS.isEmpty) rmS = getStatusList(stdData, 'rmStatuses');

      var aStatusesSet = <String>{};
      aStatusesSet.addAll(getFilterList(mgmtData, 'assignedStatuses'));
      aStatusesSet.addAll(getFilterList(stdData, 'statuses'));
      var aStatuses = aStatusesSet.toList()..sort();

      if (rDepts.isEmpty) {
        rDepts = ['Accounts', 'Animation', 'Broadcasting', 'HR', 'Interns', 'Management', 'Marketing', 'Software', 'System Admin', 'Technical Support'];
      }
      if (aDepts.isEmpty) aDepts = rDepts;

      final defaultStatuses = [
        <String, dynamic>{'label': 'Pending', 'value': 'pending'},
        <String, dynamic>{'label': 'Approved', 'value': 'approved'},
        <String, dynamic>{'label': 'Rejected', 'value': 'rejected'},
        <String, dynamic>{'label': 'Checking', 'value': 'checking'},
        <String, dynamic>{'label': 'Resolved', 'value': 'resolved'},
        <String, dynamic>{'label': 'Closed', 'value': 'closed'},
      ];

      if (hodS.isEmpty) hodS = List<Map<String, dynamic>>.from(defaultStatuses);
      if (rmS.isEmpty) rmS = List<Map<String, dynamic>>.from(defaultStatuses);

      state = state.copyWith(
        names: names,
        requestorDepts: rDepts,
        assignedDepts: aDepts,
        hodStatuses: hodS,
        rmStatuses: rmS,
        assignedStatuses: aStatuses,
        dateRange: mgmtData is Map ? mgmtData['dateRange'] : null,
      );
    } catch (e) {
      debugPrint('DEBUG: RoleManagementNotifier fetchFilters Error: $e');
    }
  }

  Future<void> fetchRequests({int page = 1}) async {
    state = state.copyWith(isLoading: true, currentPage: page);
    try {
      final filters = <String, String>{
        if (state.selectedName != null) 'search': state.selectedName!,
        if (state.selectedRequestorDept != null) 'dept': state.selectedRequestorDept!,
        if (state.selectedAssignedDept != null) 'assignedDept': state.selectedAssignedDept!,
        if (state.selectedHodStatus != null) 'hodStatus': state.selectedHodStatus!,
        if (state.selectedRmStatus != null) 'rmStatus': state.selectedRmStatus!,
        if (state.selectedStatus != null) 'status': state.selectedStatus!,
        if (state.startDate != null) 'startDate': state.startDate!,
        if (state.endDate != null) 'endDate': state.endDate!,
        if (state.search.isNotEmpty) 'search': state.search,
      };
      debugPrint("DEBUG: API Filters being sent -> $filters");
      final response = await _api.fetchManagementRequests(page: page, limit: state.limit, filters: filters);
      final List<dynamic> listData = (response['data'] ?? response['requests'] ?? []) as List<dynamic>;
      
      final mappedRequests = listData.map((json) => RequestModel.fromMap(json as Map<String, dynamic>)).toList();

      // Apply Local Filtering Logic (Safety Net)
      List<RequestModel> filteredRequests = mappedRequests;
      
      // Local Date Range Filtering
      if (state.startDate != null && state.endDate != null) {
        try {
          final start = DateFormat('yyyy-MM-dd').parse(state.startDate!);
          final end = DateFormat('yyyy-MM-dd').parse(state.endDate!).add(const Duration(days: 1));
          filteredRequests = filteredRequests.where((request) {
            return request.date.isAfter(start) && request.date.isBefore(end);
          }).toList();
        } catch (e) {
          debugPrint('DEBUG: Local date filtering error: $e');
        }
      }

      if (state.selectedAssignedDept != null) {
        final filter = state.selectedAssignedDept!.toLowerCase();
        filteredRequests = filteredRequests.where((r) => 
          (r.assignedDepartment?.toLowerCase() == filter) || 
          (r.assignedDepartments?.any((d) => d.toLowerCase() == filter) ?? false)
        ).toList();
      }

      if (state.search.isNotEmpty) {
        final q = state.search.toLowerCase();
        filteredRequests = filteredRequests.where((r) =>
          r.userName.toLowerCase().contains(q) ||
          r.title.toLowerCase().contains(q) ||
          r.department.toLowerCase().contains(q)
        ).toList();
      }

      state = state.copyWith(
        requests: filteredRequests,
        totalItems: response['total'] ?? response['totalItems'] ?? filteredRequests.length,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('DEBUG: RoleManagementNotifier fetchRequests Error: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> fetchPendingRequests() async {
    state = state.copyWith(isLoading: true, currentPage: 1);
    try {
      final response = await _api.fetchManagementRequests(page: 1, limit: state.limit, filters: {'hodStatus': 'pending', 'status': 'open'});
      final List<dynamic> listData = (response['data'] ?? response['requests'] ?? []) as List<dynamic>;
      state = state.copyWith(
        requests: listData.map((json) => RequestModel.fromMap(json as Map<String, dynamic>)).toList(),
        totalItems: response['total'] ?? response['totalItems'] ?? 0,
        isLoading: false,
        selectedHodStatus: () => 'pending',
        selectedStatus: () => 'open',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> fetchRequestById(String id) async {
    try {
      final data = await _api.fetchRequestById(id);
      final updatedReq = RequestModel.fromMap(data as Map<String, dynamic>);
      bool found = false;
      final newList = state.requests.map((req) {
        if (req.id == updatedReq.id || req.slNo == updatedReq.slNo) {
          found = true;
          return updatedReq;
        }
        return req;
      }).toList();
      if (!found) newList.add(updatedReq);
      state = state.copyWith(requests: newList);
    } catch (e) {}
  }

  void updateFilters({
    String? name, 
    String? requestorDept, 
    String? assignedDept, 
    String? hodStatus, 
    String? rmStatus, 
    String? status, 
    String? startDate, 
    String? endDate, 
    String? search, 
    bool clearAll = false,
    bool clearRange = false,
    bool resetName = false,
    bool resetRequestorDept = false,
    bool resetAssignedDept = false,
    bool resetHodStatus = false,
    bool resetRmStatus = false,
    bool resetStatus = false,
  }) {
    if (clearAll) {
      state = RoleManagementState(names: state.names, requestorDepts: state.requestorDepts, assignedDepts: state.assignedDepts, dateRange: state.dateRange, hodStatuses: state.hodStatuses, rmStatuses: state.rmStatuses, assignedStatuses: state.assignedStatuses);
    } else {
      state = state.copyWith(
        selectedName: resetName ? () => null : (name != null ? () => name : null),
        selectedRequestorDept: resetRequestorDept ? () => null : (requestorDept != null ? () => requestorDept : null),
        selectedAssignedDept: resetAssignedDept ? () => null : (assignedDept != null ? () => assignedDept : null),
        selectedHodStatus: resetHodStatus ? () => null : (hodStatus != null ? () => hodStatus : null),
        selectedRmStatus: resetRmStatus ? () => null : (rmStatus != null ? () => rmStatus : null),
        selectedStatus: resetStatus ? () => null : (status != null ? () => status : null),
        startDate: clearRange ? () => null : (startDate != null ? () => startDate : null),
        endDate: clearRange ? () => null : (endDate != null ? () => endDate : null),
        search: search,
      );
    }

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      fetchRequests(page: 1);
    });
  }

  Future<bool> approveRequest(String id, String comment) async {
    try {
      await _api.approveRequest(id, comment);
      await fetchRequestById(id);
      return true;
    } catch (e) { return false; }
  }

  Future<bool> rejectRequest(String id, String comment) async {
    try {
      await _api.rejectRequest(id, comment);
      await fetchRequestById(id);
      return true;
    } catch (e) { return false; }
  }

  Future<bool> checkingRequest(String id, {required String comment, required DateTime deadline, required String reason}) async {
    try {
      await _api.checkingRequest(id, comment: comment, deadline: deadline, reason: reason);
      await fetchRequestById(id);
      return true;
    } catch (e) { return false; }
  }

  Future<bool> closeRequest(String id, String comment) async {
    try {
      await _api.closeRequest(id, comment);
      await fetchRequestById(id);
      return true;
    } catch (e) { return false; }
  }
}

final roleManagementProvider = StateNotifierProvider<RoleManagementNotifier, RoleManagementState>((ref) {
  final api = ref.watch(roleManagementApiProvider);
  final standardApi = ref.watch(requestApiProvider);
  return RoleManagementNotifier(api, standardApi);
});
