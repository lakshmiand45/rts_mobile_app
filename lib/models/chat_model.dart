import 'dart:convert';

class ChatModel {
  final int id;
  final int requestId;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String senderDepartment;
  final String type; // 'message', 'file', 'voice', 'approval'
  final String? text;
  final String? fileName;
  final String? fileUrl;
  final DateTime createdAt;

  ChatModel({
    required this.id,
    required this.requestId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.senderDepartment,
    required this.type,
    this.text,
    this.fileName,
    this.fileUrl,
    required this.createdAt,
  });

  factory ChatModel.fromMap(Map<String, dynamic> map) {
    return ChatModel(
      id: map['id'] is String ? int.parse(map['id']) : (map['id'] ?? 0),
      requestId: map['requestId'] ?? 0,
      senderId: (map['senderId'] ?? map['userId'] ?? '').toString(),
      senderName: map['author']?.toString() ?? map['senderName']?.toString() ?? map['name']?.toString() ?? 'System',
      senderRole: map['role']?.toString() ?? map['senderRole']?.toString() ?? 'User',
      senderDepartment: (
          map['senderDept'] ??
              map['dept'] ??
              map['department'] ??
              map['senderDepartment'] ??
              map['authorDept'] ??
              'System' // Fallback to System instead of N/A
      ).toString(),

      type: map['type'] ?? 'message',
      text: map['text'] ?? map['message'],
      fileName: map['fileName'],
      fileUrl: map['fileUrl'],
      createdAt: _parseDate(map['date'], map['time'] ?? map['createdAt'] ?? map['date']),
    );
  }

  String get initials {
    if (senderName.trim().isEmpty) return '??';
    List<String> parts = senderName.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  static DateTime _parseDate(dynamic dateStr, dynamic timeStr) {
    if (dateStr == null) return DateTime.now();
    String d = dateStr.toString().replaceAll(',', '').trim();
    String t = timeStr?.toString() ?? '';
    
    try {
      return DateTime.parse(d);
    } catch (_) {
      try {
        final parts = d.split(' ')[0].split('/');
        if (parts.length == 3) {
          final day = int.parse(parts[0].trim());
          final month = int.parse(parts[1].trim());
          final year = int.parse(parts[2].trim());
          
          int hour = 0;
          int minute = 0;
          
          if (t.isNotEmpty && t.contains(':')) {
            final timeParts = t.toLowerCase().split(' ');
            final hm = timeParts[0].split(':');
            hour = int.parse(hm[0]);
            minute = int.parse(hm[1]);
            if (timeParts.length > 1 && timeParts[1] == 'pm' && hour < 12) {
              hour += 12;
            } else if (timeParts.length > 1 && timeParts[1] == 'am' && hour == 12) {
              hour = 0;
            }
          }
          
          return DateTime(year, month, day, hour, minute);
        }
      } catch (e) {
        print('Chat Date Parsing Error: $e for strings: $d, $t');
      }
      return DateTime.now();
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'text': text,
      'fileName': fileName,
      'fileUrl': fileUrl,
    };
  }
}
