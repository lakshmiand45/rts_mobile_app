import 'dart:convert';

class UserModel {
  final String userId;
  final String empId;
  final String name;
  final String role;
  final String department;
  final String? email;
  final String designation;
  final String location;

  UserModel({
    required this.userId,
    required this.empId,
    required this.name,
    required this.role,
    required this.department,
    this.email,
    this.designation = 'Staff',
    this.location = 'Remote',
  });

  String get username => name;

  String get initials {
    try {
      final trimmedName = name.trim();
      if (trimmedName.isEmpty) return '??';
      
      // Filter out empty strings caused by multiple spaces
      final parts = trimmedName.split(' ').where((s) => s.isNotEmpty).toList();
      if (parts.isEmpty) return '??';

      if (parts.length >= 2) {
        final firstPart = parts[0];
        final secondPart = parts[1];
        if (firstPart.isNotEmpty && secondPart.isNotEmpty) {
          return (firstPart[0] + secondPart[0]).toUpperCase();
        }
      }
      
      final firstPart = parts[0];
      return firstPart.substring(0, firstPart.length >= 2 ? 2 : firstPart.length).toUpperCase();
    } catch (e) {
      return '??';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'empId': empId,
      'name': name,
      'role': role,
      'dept': department,
      'email': email,
      'designation': designation,
      'location': location,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      userId: map['userId']?.toString() ?? '',
      empId: map['empId']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      role: map['role']?.toString() ?? '',
      department: map['dept']?.toString() ?? map['department']?.toString() ?? '',
      email: map['email']?.toString(),
      designation: map['designation']?.toString() ?? 'Staff',
      location: map['location']?.toString() ?? 'Remote',
    );
  }

  String toJson() => json.encode(toMap());

  factory UserModel.fromJson(String source) => UserModel.fromMap(json.decode(source));
}
