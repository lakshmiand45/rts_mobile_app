class FoodSubscriptionStatus {
  final bool subscribed;
  final bool isActive;
  final bool isCancelledNextWeek;
  final bool isBulkSuspendedNextWeek;
  final bool isEnabledNextWeekOnly;
  final String? suspendedFrom;
  final bool canCancelNow;
  final DateTime? startDate;

  FoodSubscriptionStatus({
    required this.subscribed,
    required this.isActive,
    required this.isCancelledNextWeek,
    required this.isBulkSuspendedNextWeek,
    required this.isEnabledNextWeekOnly,
    this.suspendedFrom,
    required this.canCancelNow,
    this.startDate,
  });

  FoodSubscriptionStatus copyWith({
    bool? subscribed,
    bool? isActive,
    bool? isCancelledNextWeek,
    bool? isBulkSuspendedNextWeek,
    bool? isEnabledNextWeekOnly,
    String? suspendedFrom,
    bool? canCancelNow,
    DateTime? startDate,
  }) {
    return FoodSubscriptionStatus(
      subscribed: subscribed ?? this.subscribed,
      isActive: isActive ?? this.isActive,
      isCancelledNextWeek: isCancelledNextWeek ?? this.isCancelledNextWeek,
      isBulkSuspendedNextWeek: isBulkSuspendedNextWeek ?? this.isBulkSuspendedNextWeek,
      isEnabledNextWeekOnly: isEnabledNextWeekOnly ?? this.isEnabledNextWeekOnly,
      suspendedFrom: suspendedFrom ?? this.suspendedFrom,
      canCancelNow: canCancelNow ?? this.canCancelNow,
      startDate: startDate ?? this.startDate,
    );
  }

  factory FoodSubscriptionStatus.fromMap(Map<String, dynamic> map) {
    final subscription = map['subscription'] as Map<String, dynamic>?;
    
    return FoodSubscriptionStatus(
      subscribed: map['subscribed'] ?? false,
      isActive: map['isActive'] ?? false,
      isCancelledNextWeek: map['isCancelledNextWeek'] ?? false,
      isBulkSuspendedNextWeek: map['isBulkSuspendedNextWeek'] ?? false,
      isEnabledNextWeekOnly: map['isEnabledNextWeekOnly'] ?? false,
      suspendedFrom: map['suspendedFrom'],
      canCancelNow: map['canCancelNow'] ?? false,
      startDate: subscription != null && subscription['startDate'] != null 
          ? DateTime.parse(subscription['startDate']) 
          : null,
    );
  }
}

class FoodCalendarDay {
  final DateTime date;
  final String type; // 'working', 'working-saturday', 'weekend', 'holiday'
  final String? name;

  FoodCalendarDay({
    required this.date,
    required this.type,
    this.name,
  });

  FoodCalendarDay copyWith({
    DateTime? date,
    String? type,
    String? name,
  }) {
    return FoodCalendarDay(
      date: date ?? this.date,
      type: type ?? this.type,
      name: name ?? this.name,
    );
  }

  factory FoodCalendarDay.fromMap(Map<String, dynamic> map) {
    return FoodCalendarDay(
      date: DateTime.parse(map['date']),
      type: map['type'] ?? 'working',
      name: map['name'],
    );
  }
}

class FoodCalendarResponse {
  final bool isActive;
  final bool subscribed;
  final String? suspendedFrom;
  final int workingDays;
  final int totalAmount;
  final List<FoodCalendarDay> days;

  FoodCalendarResponse({
    required this.isActive,
    required this.subscribed,
    this.suspendedFrom,
    required this.workingDays,
    required this.totalAmount,
    required this.days,
  });

  factory FoodCalendarResponse.fromMap(Map<String, dynamic> map) {
    return FoodCalendarResponse(
      isActive: map['isActive'] ?? false,
      subscribed: map['subscribed'] ?? false,
      suspendedFrom: map['suspendedFrom'],
      workingDays: map['workingDays'] ?? 0,
      totalAmount: map['totalAmount'] ?? 0,
      days: (map['days'] as List<dynamic>?)
              ?.map((x) => FoodCalendarDay.fromMap(x))
              .toList() ??
          [],
    );
  }
}
