import 'dart:typed_data';
import 'package:flutter/foundation.dart';

enum RequestStatus { open, approved, rejected, pending, checking, closed, resolved, forwarded }

class RequestModel {
  final String id;
  final String slNo;
  final DateTime date;
  final String userId;
  final String empId;
  final String userName;
  final String department;
  final String designation;
  final String location;
  final String title;
  final String description;
  final RequestStatus rmStatus;
  final DateTime? rmStatusDate;
  final RequestStatus hodStatus;
  final DateTime? hodStatusDate;
  final RequestStatus assignedRmStatus;
  final DateTime? assignedRmStatusDate;
  final RequestStatus assignedHodStatus;
  final DateTime? assignedHodStatusDate;
  final RequestStatus deptHodStatus;
  final DateTime? deptHodStatusDate;
  final RequestStatus? assignedStatus;
  final List<String>? assignedDepartments;
  final List<String>? assignedPersons;
  final List<String>? assignedPersonEmpIds;
  final DateTime? dueDate;
  final DateTime? checkingDeadline;
  final String? checkingReason;
  final RequestStatus overallStatus;
  final DateTime? overallStatusDate;
  final bool isRead;
  final int unreadChatCount;
  final String? attachedFilePath;
  final String? attachedFileName;
  final String? attachedFileUrl;
  final Uint8List? attachedFileBytes;
  final String? resolutionNote;
  final List<String>? fileUrls;
  final List<String>? fileNames;
  
  // New fields from backend response
  final bool isForwarded;
  final String? forwardedBy;
  final String? forwardedFromDept;
  final String? requestorRole;
  final DateTime? forwardedAt;
  final String? resolvedBy;
  final String? dueDateRaw;
  final String? priority;
  final int? daysUntilDue;
  final String? checkingBy;
  final int? checkingDaysLeft;
  final String? acknowledgement;
  final DateTime? acknowledgedAt;
  final bool isGnRoute;
  final bool isOwnRequest;
  final bool isClosed;

  RequestModel({
    required this.id,
    required this.slNo,
    required this.date,
    required this.userId,
    required this.empId,
    required this.userName,
    required this.department,
    required this.designation,
    required this.location,
    required this.title,
    required this.description,
    this.rmStatus = RequestStatus.pending,
    this.rmStatusDate,
    this.hodStatus = RequestStatus.pending,
    this.hodStatusDate,
    this.assignedRmStatus = RequestStatus.pending,
    this.assignedRmStatusDate,
    this.assignedHodStatus = RequestStatus.pending,
    this.assignedHodStatusDate,
    this.deptHodStatus = RequestStatus.pending,
    this.deptHodStatusDate,
    this.assignedStatus,
    this.assignedDepartments,
    this.assignedPersons,
    this.assignedPersonEmpIds,
    this.dueDate,
    this.checkingDeadline,
    this.checkingReason,
    this.overallStatus = RequestStatus.open,
    this.overallStatusDate,
    this.isRead = false,
    this.unreadChatCount = 0,
    this.attachedFilePath,
    this.attachedFileName,
    this.attachedFileUrl,
    this.attachedFileBytes,
    this.resolutionNote,
    this.fileUrls,
    this.fileNames,
    this.isForwarded = false,
    this.forwardedBy,
    this.forwardedFromDept,
    this.requestorRole,
    this.forwardedAt,
    this.resolvedBy,
    this.dueDateRaw,
    this.priority,
    this.daysUntilDue,
    this.checkingBy,
    this.checkingDaysLeft,
    this.acknowledgement,
    this.acknowledgedAt,
    this.isGnRoute = false,
    this.isOwnRequest = false,
    this.isClosed = false,
  });

  String? get assignedDepartment => (assignedDepartments != null && assignedDepartments!.isNotEmpty)
      ? assignedDepartments!.join(', ')
      : null;

  factory RequestModel.fromMap(Map<String, dynamic> map) {
    String? rawStatus = (map['status'] ?? map['assignedStatus'] ?? map['overallStatus'])?.toString();
    RequestStatus status = _parseStatus(rawStatus);
    
    final rmStatus = _parseStatus(map['rmStatus'] ?? map['rm_status']);
    final hodStatus = _parseStatus(map['hodStatus'] ?? map['hod_status']);
    final assignedRmStatus = _parseStatus(map['assignedRmStatus'] ?? map['assigned_rm_status']);
    final assignedHodStatus = _parseStatus(map['assignedHodStatus'] ?? map['assigned_hod_status']);
    final deptHodStatus = _parseStatus(map['deptHodStatus'] ?? map['dept_hod_status']);

    final RequestStatus? parsedAssignedStatus = map['assignedStatus'] != null ? _parseStatus(map['assignedStatus']) : null;

    DateTime? extractedDeadline = _parseDateNullable(map['checkingDeadline'] ?? map['checking_deadline']);
    String? extractedReason = (map['checkingReason'] ?? map['checkingDeadlineReason'] ?? map['checking_deadline_reason'] ?? map['checking_reason'])?.toString();

    if (status != RequestStatus.closed && 
        status != RequestStatus.resolved && 
        status != RequestStatus.rejected && 
        (rmStatus == RequestStatus.checking || 
         hodStatus == RequestStatus.checking || 
         assignedRmStatus == RequestStatus.checking ||
         assignedHodStatus == RequestStatus.checking ||
         deptHodStatus == RequestStatus.checking ||
         extractedDeadline != null)) {
      status = RequestStatus.checking;
    }

    bool isActuallyClosed = map['isClosed'] == true || 
                            rawStatus?.toLowerCase() == 'received' ||
                            rawStatus?.toLowerCase() == 'fully closed' || 
                            rawStatus?.toLowerCase() == 'closed and finalized';

    if (isActuallyClosed) {
      status = RequestStatus.closed;
    } else if (rawStatus?.toLowerCase() == 'not received') {
      status = RequestStatus.open;
    } else if (rawStatus?.toLowerCase() == 'closed' || 
               (rawStatus?.toLowerCase().contains('acknowledgement') == true && rawStatus?.toLowerCase() != 'received') ||
               rawStatus?.toLowerCase() == 'resolved') {
      status = RequestStatus.resolved;
    }

    String? resNote;
    dynamic rawUrl;
    String? fileName;
    List<String>? multiUrls;
    List<String>? multiNames;

    if (map['closeData'] is Map) {
      final closeData = map['closeData'] as Map<String, dynamic>;
      resNote = closeData['description']?.toString() ?? closeData['resolutionNote']?.toString();
      rawUrl = closeData['fileUrl'] ?? closeData['filePath'];
      fileName = closeData['fileName'];

      if (closeData['fileUrls'] is List) {
        multiUrls = (closeData['fileUrls'] as List).map((e) => _normalizeUrl(e) ?? '').where((e) => e.isNotEmpty).toList();
      }
      if (closeData['fileNames'] is List) {
        multiNames = List<String>.from(closeData['fileNames']);
      }
    }

    if (map['fileUrls'] is List) {
      multiUrls ??= (map['fileUrls'] as List).map((e) => _normalizeUrl(e) ?? '').where((e) => e.isNotEmpty).toList();
    }
    if (map['fileNames'] is List) {
      multiNames ??= List<String>.from(map['fileNames']);
    }

    List<String>? depts;
    final rawDept = map['assignedDept'] ?? map['assigned_dept'] ?? map['assignedDepts'];
    if (rawDept != null) {
      if (rawDept is List) {
        depts = List<String>.from(rawDept);
      } else {
        depts = rawDept.toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
    }

    List<String>? persons;
    final rawPerson = map['assignedPersonName'] ?? map['assigned_person'];
    if (rawPerson != null) {
      if (rawPerson is List) {
        persons = List<String>.from(rawPerson);
      } else {
        persons = rawPerson.toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
    }

    List<String>? personEmpIds;
    final rawEmpId = map['assignedPersonEmpId'] ?? map['assigned_person_emp_id'];
    if (rawEmpId != null) {
      if (rawEmpId is List) {
        personEmpIds = List<String>.from(rawEmpId);
      } else {
        personEmpIds = rawEmpId.toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
    }

    if (extractedDeadline == null || extractedReason == null) {
      void deepSearch(dynamic data) {
        if (data is Map) {
          for (var entry in data.entries) {
            final val = entry.value;
            if (val is String && val.contains('DEADLINE:')) {
              try {
                final String deadlinePart = val.split('DEADLINE:')[1].split('|')[0].trim();
                final List<String> dateParts = deadlinePart.split('/');
                if (dateParts.length == 3) {
                  extractedDeadline ??= DateTime(int.parse(dateParts[2]), int.parse(dateParts[0]), int.parse(dateParts[1]));
                }
              } catch (_) {}
              if (val.contains('PLAN:')) extractedReason ??= val.split('PLAN:')[1].trim();
              if (val.contains('REASON:')) extractedReason ??= val.split('REASON:')[1].trim();
            }
            if (val is Map || val is List) deepSearch(val);
          }
        } else if (data is List) {
          for (var item in data) deepSearch(item);
        }
      }
      deepSearch(map);
    }

    return RequestModel(
      id: map['id']?.toString() ?? '',
      slNo: map['slNo']?.toString() ?? map['id']?.toString() ?? '',
      date: _parseDate(map['date'] ?? map['created_at']),
      userId: map['userId']?.toString() ?? map['user_id']?.toString() ?? '',
      empId: map['empId']?.toString() ?? map['emp_id']?.toString() ?? '',
      userName: map['name']?.toString() ?? map['user_name']?.toString() ?? '',
      department: map['dept']?.toString() ?? map['department']?.toString() ?? '',
      designation: map['designation']?.toString() ?? '',
      location: map['location']?.toString() ?? '',
      title: map['purpose'] ?? map['title'] ?? '',
      description: map['description'] ?? '',
      rmStatus: rmStatus,
      rmStatusDate: _parseDateNullable(map['rmDate'] ?? map['rm_date']),
      hodStatus: hodStatus,
      hodStatusDate: _parseDateNullable(map['hodDate'] ?? map['hod_date']),
      assignedRmStatus: assignedRmStatus,
      assignedRmStatusDate: _parseDateNullable(map['assignedRmDate'] ?? map['assigned_rm_date']),
      assignedHodStatus: assignedHodStatus,
      assignedHodStatusDate: _parseDateNullable(map['assignedHodDate'] ?? map['assigned_hod_date']),
      deptHodStatus: deptHodStatus,
      deptHodStatusDate: _parseDateNullable(map['deptHodDate'] ?? map['dept_hod_date']),
      assignedStatus: parsedAssignedStatus,
      assignedDepartments: depts,
      assignedPersons: persons,
      assignedPersonEmpIds: personEmpIds,
      dueDate: _parseDateNullable(map['dueDate'] ?? map['due_date']),
      checkingDeadline: extractedDeadline,
      checkingReason: extractedReason,
      overallStatus: status,
      overallStatusDate: _parseDateNullable(map['resolvedDate'] ?? map['updated_at']),
      isRead: map['seen'] ?? map['is_read'] ?? false,
      unreadChatCount: 0,
      attachedFileName: fileName ?? map['fileName'],
      attachedFileUrl: _normalizeUrl(rawUrl ?? map['fileUrl']),
      resolutionNote: resNote,
      fileUrls: multiUrls,
      fileNames: multiNames,
      isForwarded: map['forwarded'] == true,
      forwardedBy: map['forwardedBy']?.toString(),
      forwardedFromDept: map['forwardedFromDept']?.toString(),
      requestorRole: map['requestorRole']?.toString(),
      forwardedAt: _parseDateNullable(map['forwardedAt'] ?? map['forwarded_at']),
      resolvedBy: map['resolvedBy']?.toString(),
      dueDateRaw: map['dueDateRaw']?.toString() ?? map['due_date_raw']?.toString(),
      priority: map['priority']?.toString(),
      daysUntilDue: map['daysUntilDue'] as int?,
      checkingBy: map['checkingBy']?.toString() ?? map['checking_by']?.toString(),
      checkingDaysLeft: map['checkingDaysLeft'] as int?,
      acknowledgement: map['acknowledgement']?.toString(),
      acknowledgedAt: _parseDateNullable(map['acknowledgedAt'] ?? map['acknowledged_at']),
      isGnRoute: map['isGnRoute'] == true,
      isOwnRequest: map['isOwnRequest'] == true,
      isClosed: isActuallyClosed,
    );
  }

  static String? _normalizeUrl(dynamic url) {
    if (url == null || url == 'null' || url == '') return null;
    String s = url.toString().trim();
    const String serverHost = '192.168.1.128:5000';
    if (s.startsWith('http')) {
      if (s.contains(' ')) {
        final parts = s.split('/');
        final last = Uri.encodeComponent(parts.removeLast());
        return '${parts.join('/')}/$last';
      }
      return s;
    }
    if (s.startsWith('/')) s = s.substring(1);
    if (s.startsWith('api/files/')) s = s.substring(10);
    final String cleanFileName = s.split('/').last;
    return Uri.http(serverHost, '/api/files/$cleanFileName').toString();
  }

  static DateTime _parseDate(dynamic dateStr) {
    if (dateStr == null) return DateTime.now();
    String s = dateStr.toString().replaceAll(',', '').trim();
    try {
      return DateTime.parse(s);
    } catch (_) {
      try {
        final parts = s.split('/');
        if (parts.length == 3) {
          final day = int.parse(parts[0].trim());
          final month = int.parse(parts[1].trim());
          final year = int.parse(parts[2].trim());
          return DateTime(year, month, day);
        }
      } catch (_) {}
      return DateTime.now();
    }
  }

  static DateTime? _parseDateNullable(dynamic dateStr) {
    if (dateStr == null || dateStr == 'null' || dateStr == '') return null;
    return _parseDate(dateStr);
  }

  static RequestStatus _parseStatus(dynamic status) {
    if (status == null || status == '--' || status == '---') return RequestStatus.pending;
    String s = status.toString().toLowerCase().trim();
    if (s.contains('(') && s.contains(')')) {
      final startIndex = s.indexOf('(');
      final endIndex = s.indexOf(')');
      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        s = s.substring(startIndex + 1, endIndex).trim();
      }
    }
    if (s == 'open' || s == 'not received') return RequestStatus.open;
    if (s == 'closed' || s == 'received' || s == 'fully closed') return RequestStatus.closed;
    if (s == 'resolved' || s.contains('acknowledgement')) return RequestStatus.resolved;
    if (s.contains('checking')) return RequestStatus.checking;
    if (s == 'forwarded') return RequestStatus.forwarded;
    return RequestStatus.values.firstWhere(
          (e) => e.name.toLowerCase() == s,
      orElse: () => RequestStatus.pending,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'purpose': title,
      'assignedDept': assignedDepartments,
      'assignedPersonName': assignedPersons,
      'dueDate': dueDate?.toIso8601String(),
      'description': description,
      'requestorRole': requestorRole,
      'forwardedAt': forwardedAt?.toIso8601String(),
      'resolvedBy': resolvedBy,
      'dueDateRaw': dueDateRaw,
      'priority': priority,
      'daysUntilDue': daysUntilDue,
      'checkingBy': checkingBy,
      'checkingDaysLeft': checkingDaysLeft,
      'acknowledgement': acknowledgement,
      'acknowledgedAt': acknowledgedAt?.toIso8601String(),
      'isGnRoute': isGnRoute,
      'isOwnRequest': isOwnRequest,
      'isClosed': isClosed,
    };
  }

  RequestModel copyWith({
    String? id,
    String? slNo,
    DateTime? date,
    String? userId,
    String? empId,
    String? userName,
    String? department,
    String? designation,
    String? location,
    String? title,
    String? description,
    RequestStatus? rmStatus,
    DateTime? rmStatusDate,
    RequestStatus? hodStatus,
    DateTime? hodStatusDate,
    RequestStatus? assignedRmStatus,
    DateTime? assignedRmStatusDate,
    RequestStatus? assignedHodStatus,
    DateTime? assignedHodStatusDate,
    RequestStatus? deptHodStatus,
    DateTime? deptHodStatusDate,
    RequestStatus? assignedStatus,
    List<String>? assignedDepartments,
    List<String>? assignedPersons,
    List<String>? assignedPersonEmpIds,
    DateTime? dueDate,
    DateTime? checkingDeadline,
    String? checkingReason,
    RequestStatus? overallStatus,
    DateTime? overallStatusDate,
    bool? isRead,
    int? unreadChatCount,
    String? attachedFilePath,
    String? attachedFileName,
    String? attachedFileUrl,
    Uint8List? attachedFileBytes,
    String? resolutionNote,
    List<String>? fileUrls,
    List<String>? fileNames,
    bool? isForwarded,
    String? forwardedBy,
    String? forwardedFromDept,
    String? requestorRole,
    DateTime? forwardedAt,
    String? resolvedBy,
    String? dueDateRaw,
    String? priority,
    int? daysUntilDue,
    String? checkingBy,
    int? checkingDaysLeft,
    String? acknowledgement,
    DateTime? acknowledgedAt,
    bool? isGnRoute,
    bool? isOwnRequest,
    bool? isClosed,
  }) {
    return RequestModel(
      id: id ?? this.id,
      slNo: slNo ?? this.slNo,
      date: date ?? this.date,
      userId: userId ?? this.userId,
      empId: empId ?? this.empId,
      userName: userName ?? this.userName,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      location: location ?? this.location,
      title: title ?? this.title,
      description: description ?? this.description,
      rmStatus: rmStatus ?? this.rmStatus,
      rmStatusDate: rmStatusDate ?? this.rmStatusDate,
      hodStatus: hodStatus ?? this.hodStatus,
      hodStatusDate: hodStatusDate ?? this.hodStatusDate,
      assignedRmStatus: assignedRmStatus ?? this.assignedRmStatus,
      assignedRmStatusDate: assignedRmStatusDate ?? this.assignedRmStatusDate,
      assignedHodStatus: assignedHodStatus ?? this.assignedHodStatus,
      assignedHodStatusDate: assignedHodStatusDate ?? this.assignedHodStatusDate,
      deptHodStatus: deptHodStatus ?? this.deptHodStatus,
      deptHodStatusDate: deptHodStatusDate ?? this.deptHodStatusDate,
      assignedStatus: assignedStatus ?? this.assignedStatus,
      assignedDepartments: assignedDepartments ?? this.assignedDepartments,
      assignedPersons: assignedPersons ?? this.assignedPersons,
      assignedPersonEmpIds: assignedPersonEmpIds ?? this.assignedPersonEmpIds,
      dueDate: dueDate ?? this.dueDate,
      checkingDeadline: checkingDeadline ?? this.checkingDeadline,
      checkingReason: checkingReason ?? this.checkingReason,
      overallStatus: overallStatus ?? this.overallStatus,
      overallStatusDate: overallStatusDate ?? this.overallStatusDate,
      isRead: isRead ?? this.isRead,
      unreadChatCount: unreadChatCount ?? this.unreadChatCount,
      attachedFilePath: attachedFilePath ?? this.attachedFilePath,
      attachedFileName: attachedFileName ?? this.attachedFileName,
      attachedFileUrl: attachedFileUrl ?? this.attachedFileUrl,
      attachedFileBytes: attachedFileBytes ?? this.attachedFileBytes,
      resolutionNote: resolutionNote ?? this.resolutionNote,
      fileUrls: fileUrls ?? this.fileUrls,
      fileNames: fileNames ?? this.fileNames,
      isForwarded: isForwarded ?? this.isForwarded,
      forwardedBy: forwardedBy ?? this.forwardedBy,
      forwardedFromDept: forwardedFromDept ?? this.forwardedFromDept,
      requestorRole: requestorRole ?? this.requestorRole,
      forwardedAt: forwardedAt ?? this.forwardedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      dueDateRaw: dueDateRaw ?? this.dueDateRaw,
      priority: priority ?? this.priority,
      daysUntilDue: daysUntilDue ?? this.daysUntilDue,
      checkingBy: checkingBy ?? this.checkingBy,
      checkingDaysLeft: checkingDaysLeft ?? this.checkingDaysLeft,
      acknowledgement: acknowledgement ?? this.acknowledgement,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      isGnRoute: isGnRoute ?? this.isGnRoute,
      isOwnRequest: isOwnRequest ?? this.isOwnRequest,
      isClosed: isClosed ?? this.isClosed,
    );
  }
}
