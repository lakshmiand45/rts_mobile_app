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
  });

  String? get assignedDepartment => (assignedDepartments != null && assignedDepartments!.isNotEmpty) 
      ? assignedDepartments!.join(', ') 
      : null;

  factory RequestModel.fromMap(Map<String, dynamic> map) {
    String? rawStatus = map['status']?.toString() ?? map['assignedStatus']?.toString();
    RequestStatus status = _parseStatus(rawStatus);
    
    bool isActuallyClosed = map['isClosed'] == true || rawStatus?.toLowerCase() == 'fully closed' || rawStatus?.toLowerCase() == 'closed and finalized';
    
    if (isActuallyClosed) {
      status = RequestStatus.closed;
    } else if (rawStatus?.toLowerCase() == 'closed' || rawStatus?.toLowerCase().contains('acknowledgement') == true) {
      status = RequestStatus.resolved;
    }

    final dynamic rawUrl = map['fileUrl'] ?? map['filePath'];
    String? fileName = map['fileName'];

    List<String>? depts;
    if (map['assignedDept'] != null) {
      if (map['assignedDept'] is List) {
        depts = List<String>.from(map['assignedDept']);
      } else {
        depts = [map['assignedDept'].toString()];
      }
    }

    List<String>? persons;
    if (map['assignedPersonName'] != null) {
      if (map['assignedPersonName'] is List) {
        persons = List<String>.from(map['assignedPersonName']);
      } else {
        persons = [map['assignedPersonName'].toString()];
      }
    }

    // Attempt to extract checking details from various potential comment fields
    DateTime? extractedDeadline = _parseDateNullable(map['checkingDeadline']);
    String? extractedReason = map['checkingDeadlineReason']?.toString();

    // RTS systems often store approval comments in these fields
    final List<String> commentFields = [
      'comment', 'hodComment', 'rmComment', 'deptHodComment',
      'rmStatusComment', 'hodStatusComment', 'deptHodStatusComment',
      'rmApprovalComment', 'hodApprovalComment', 'deptHodApprovalComment',
      'statusComment', 'approvalComment', 'reason'
    ];

    String? combinedStatusComment;
    for (var field in commentFields) {
      if (map[field] != null && map[field].toString().contains('DEADLINE:')) {
        combinedStatusComment = map[field].toString();
        break;
      }
    }

    if (extractedDeadline == null && combinedStatusComment != null && combinedStatusComment.contains('DEADLINE:')) {
      try {
        final String deadlineStr = combinedStatusComment.split('DEADLINE:')[1].split('|')[0].trim();
        final List<String> dateParts = deadlineStr.split('/');
        if (dateParts.length == 3) {
          // Modal uses MM/dd/yyyy
          extractedDeadline = DateTime(
            int.parse(dateParts[2]), // Year
            int.parse(dateParts[0]), // Month
            int.parse(dateParts[1])  // Day
          );
        }
      } catch (_) {}
    }
    
    if (extractedReason == null && combinedStatusComment != null && combinedStatusComment.contains('PLAN:')) {
      try {
        extractedReason = combinedStatusComment.split('PLAN:')[1].trim();
      } catch (_) {}
    }

    return RequestModel(
      id: map['id']?.toString() ?? '',
      slNo: map['slNo']?.toString() ?? map['id']?.toString() ?? '',
      date: _parseDate(map['date']),
      userId: map['userId']?.toString() ?? '',
      empId: map['empId']?.toString() ?? '',
      userName: map['name']?.toString() ?? '',
      department: map['dept']?.toString() ?? '', 
      designation: map['designation']?.toString() ?? '',
      location: map['location']?.toString() ?? '',
      title: map['purpose'] ?? '',
      description: map['description'] ?? '',
      rmStatus: _parseStatus(map['rmStatus']),
      rmStatusDate: _parseDateNullable(map['rmDate']),
      hodStatus: _parseStatus(map['hodStatus']),
      hodStatusDate: _parseDateNullable(map['hodDate']),
      assignedHodStatus: _parseStatus(map['deptHodStatus']),
      assignedHodStatusDate: _parseDateNullable(map['deptHodDate']),
      assignedDepartments: depts,
      assignedPersons: persons,
      dueDate: _parseDateNullable(map['dueDate']),
      checkingDeadline: extractedDeadline,
      checkingDeadlineReason: extractedReason,
      overallStatus: status,
      overallStatusDate: _parseDateNullable(map['resolvedDate']),
      isRead: map['seen'] ?? false,
      unreadChatCount: 0,
      attachedFileName: fileName,
      attachedFileUrl: _normalizeUrl(rawUrl),
      resolutionNote: map['closeData']?['resolutionNote'],
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
    );
  }
}
