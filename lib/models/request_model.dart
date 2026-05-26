import 'dart:typed_data';
import 'package:flutter/foundation.dart';

enum RequestStatus { open, approved, rejected, pending, checking, closed, resolved }

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
  final RequestStatus assignedHodStatus;
  final DateTime? assignedHodStatusDate;
  final List<String>? assignedDepartments;
  final List<String>? assignedPersons;
  final DateTime? dueDate;
  final DateTime? checkingDeadline;
  final String? checkingDeadlineReason;
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
    this.assignedHodStatus = RequestStatus.pending,
    this.assignedHodStatusDate,
    this.assignedDepartments,
    this.assignedPersons,
    this.dueDate,
    this.checkingDeadline,
    this.checkingDeadlineReason,
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
  });

  String? get assignedDepartment => (assignedDepartments != null && assignedDepartments!.isNotEmpty)
      ? assignedDepartments!.join(', ')
      : null;

  factory RequestModel.fromMap(Map<String, dynamic> map) {
    debugPrint('DEBUG: RequestModel.fromMap received map: $map');
    
    // Status parsing with multiple fallback keys
    String? rawStatus = (map['status'] ?? map['assignedStatus'] ?? map['overallStatus'])?.toString();
    RequestStatus status = _parseStatus(rawStatus);
    
    // Check all role-based status fields with snake_case fallbacks
    final rmStatus = _parseStatus(map['rmStatus'] ?? map['rm_status']);
    final hodStatus = _parseStatus(map['hodStatus'] ?? map['hod_status']);
    final deptHodStatus = _parseStatus(map['deptHodStatus'] ?? map['dept_hod_status'] ?? map['assignedStatus']);

    // Checking Details with snake_case fallbacks
    DateTime? extractedDeadline = _parseDateNullable(map['checkingDeadline'] ?? map['checking_deadline']);
    String? extractedReason = (map['checkingDeadlineReason'] ?? map['checking_deadline_reason'])?.toString();

    // If any role-based status is checking, or we have a deadline, and the overall status is not finalized, set to checking
    if (status != RequestStatus.closed && 
        status != RequestStatus.resolved && 
        status != RequestStatus.rejected && 
        (rmStatus == RequestStatus.checking || 
         hodStatus == RequestStatus.checking || 
         deptHodStatus == RequestStatus.checking ||
         extractedDeadline != null)) {
      status = RequestStatus.checking;
    }

    bool isActuallyClosed = map['isClosed'] == true || 
                            rawStatus?.toLowerCase() == 'fully closed' || 
                            rawStatus?.toLowerCase() == 'closed and finalized' ||
                            rawStatus?.toLowerCase() == 'closed';

    if (isActuallyClosed) {
      status = RequestStatus.closed;
    } else if (rawStatus?.toLowerCase().contains('acknowledgement') == true || rawStatus?.toLowerCase() == 'resolved') {
      status = RequestStatus.resolved;
    }

    // Extraction for Resolution details
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

    // Fallbacks for files
    if (map['fileUrls'] is List) {
      multiUrls ??= (map['fileUrls'] as List).map((e) => _normalizeUrl(e) ?? '').where((e) => e.isNotEmpty).toList();
    }
    if (map['fileNames'] is List) {
      multiNames ??= List<String>.from(map['fileNames']);
    }

    List<String>? depts;
    final rawDept = map['assignedDept'] ?? map['assigned_dept'];
    if (rawDept != null) {
      if (rawDept is List) {
        depts = List<String>.from(rawDept);
      } else {
        depts = [rawDept.toString()];
      }
    }

    List<String>? persons;
    final rawPerson = map['assignedPersonName'] ?? map['assigned_person'];
    if (rawPerson != null) {
      if (rawPerson is List) {
        persons = List<String>.from(rawPerson);
      } else {
        persons = [rawPerson.toString()];
      }
    }

    // Deep Search for missed details in activity logs if still missing
    if (extractedDeadline == null) {
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
              if (val.contains('PLAN:')) {
                extractedReason ??= val.split('PLAN:')[1].trim();
              }
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
      assignedHodStatus: deptHodStatus,
      assignedHodStatusDate: _parseDateNullable(map['deptHodDate'] ?? map['dept_hod_date']),
      assignedDepartments: depts,
      assignedPersons: persons,
      dueDate: _parseDateNullable(map['dueDate'] ?? map['due_date']),
      checkingDeadline: extractedDeadline,
      checkingDeadlineReason: extractedReason,
      overallStatus: status,
      overallStatusDate: _parseDateNullable(map['resolvedDate'] ?? map['updated_at']),
      isRead: map['seen'] ?? map['is_read'] ?? false,
      unreadChatCount: 0,
      attachedFileName: fileName ?? map['fileName'],
      attachedFileUrl: _normalizeUrl(rawUrl ?? map['fileUrl']),
      resolutionNote: resNote,
      fileUrls: multiUrls,
      fileNames: multiNames,
    );
  }

  static String? _normalizeUrl(dynamic url) {
    if (url == null || url == 'null' || url == '') return null;
    String s = url.toString().trim();
    const String serverHost = '192.168.1.128:5000';
    s = s.replaceAll('\\', '/');
    if (s.contains('localhost')) {
      s = s.replaceAll('localhost', '192.168.1.128');
    } else if (s.contains('127.0.0.1')) {
      s = s.replaceAll('127.0.0.1', '192.168.1.128');
    }
    if (s.startsWith('http')) return s;
    final String cleanFileName = s.split('/').last;
    return 'http://$serverHost/api/files/$cleanFileName';
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
    final s = status.toString().toLowerCase().trim();
    if (s == 'open') return RequestStatus.open;
    if (s == 'closed') return RequestStatus.closed;
    if (s == 'resolved') return RequestStatus.resolved;
    if (s.contains('acknowledgement')) return RequestStatus.resolved;
    if (s.contains('checking')) return RequestStatus.checking;

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
    RequestStatus? assignedHodStatus,
    DateTime? assignedHodStatusDate,
    List<String>? assignedDepartments,
    List<String>? assignedPersons,
    DateTime? dueDate,
    DateTime? checkingDeadline,
    String? checkingDeadlineReason,
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
      assignedHodStatus: assignedHodStatus ?? this.assignedHodStatus,
      assignedHodStatusDate: assignedHodStatusDate ?? this.assignedHodStatusDate,
      assignedDepartments: assignedDepartments ?? this.assignedDepartments,
      assignedPersons: assignedPersons ?? this.assignedPersons,
      dueDate: dueDate ?? this.dueDate,
      checkingDeadline: checkingDeadline ?? this.checkingDeadline,
      checkingDeadlineReason: checkingDeadlineReason ?? this.checkingDeadlineReason,
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
    );
  }
}
