import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/food_request_api.dart';
import '../models/food_subscription_model.dart';
import 'package:intl/intl.dart';
import 'auth_provider.dart';

class FoodState {
  final bool isLoading;
  final bool isActionLoading;
  final FoodSubscriptionStatus? status;
  final FoodCalendarResponse? calendar;
  final String? error;
  final bool hasSeenOnboarding;
  final bool isInitialized;

  FoodState({
    this.isLoading = false,
    this.isActionLoading = false,
    this.status,
    this.calendar,
    this.error,
    this.hasSeenOnboarding = false,
    this.isInitialized = false,
  });

  FoodState copyWith({
    bool? isLoading,
    bool? isActionLoading,
    FoodSubscriptionStatus? status,
    FoodCalendarResponse? calendar,
    String? error,
    bool? hasSeenOnboarding,
    bool? isInitialized,
  }) {
    return FoodState(
      isLoading: isLoading ?? this.isLoading,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      status: status ?? this.status,
      calendar: calendar ?? this.calendar,
      error: error,
      hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

class FoodNotifier extends StateNotifier<FoodState> {
  final FoodRequestApi _api;
  final Ref _ref;
  final String? _userId;

  FoodNotifier(this._api, this._ref, this._userId) : super(FoodState()) {
    if (_userId != null) {
      _init();
    }
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('food_onboarding_seen_$_userId') ?? false;
    
    state = state.copyWith(hasSeenOnboarding: hasSeen, isInitialized: true);
    
    final now = DateTime.now();
    await refreshAll(month: now.month, year: now.year, isSilent: true);
  }

  Future<void> completeOnboarding() async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('food_onboarding_seen_$_userId', true);
    state = state.copyWith(hasSeenOnboarding: true);
  }

  Future<void> refreshAll({int? month, int? year, bool isSilent = false}) async {
    if (!isSilent) state = state.copyWith(isLoading: true, error: null);
    try {
      final now = DateTime.now();
      final m = month ?? now.month;
      final y = year ?? now.year;

      final statusData = await _api.getStatus();
      final calendarData = await _api.getCalendar(m, y);

      final status = FoodSubscriptionStatus.fromMap(statusData['data'] ?? statusData);
      final calendar = FoodCalendarResponse.fromMap(calendarData['data'] ?? calendarData);

      state = state.copyWith(
        isLoading: false,
        status: status,
        calendar: calendar,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> subscribe({String? location}) async {
    if (state.isActionLoading) return false;
    state = state.copyWith(isActionLoading: true, error: null);
    try {
      final startDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await _api.subscribe(startDate, location ?? 'Office');
      await completeOnboarding(); 
      await refreshAll(isSilent: true);
      state = state.copyWith(isActionLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isActionLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> cancelNextWeek({int? month, int? year}) async => _performAction(() => _api.cancelNextWeek(), month: month, year: year);
  Future<bool> undoCancelNextWeek({int? month, int? year}) async => _performAction(() => _api.undoCancelNextWeek(), month: month, year: year);
  Future<bool> pauseYear({int? month, int? year}) async => _performAction(() => _api.pauseYear(), month: month, year: year);
  Future<bool> undoPauseYear({int? month, int? year}) async => _performAction(() => _api.undoPauseYear(), month: month, year: year);
  Future<bool> enableNextWeek({int? month, int? year}) => _performAction(() => _api.enableNextWeek(), month: month, year: year);
  Future<bool> undoEnableNextWeek({int? month, int? year}) => _performAction(() => _api.undoEnableNextWeek(), month: month, year: year);
  Future<bool> enableYear({int? month, int? year}) => _performAction(() => _api.enableYear(), month: month, year: year);
  Future<bool> disableYear({int? month, int? year}) => _performAction(() => _api.disableYear(), month: month, year: year);

  Future<bool> _performAction(Future<dynamic> Function() action, {int? month, int? year}) async {
    if (state.isActionLoading) return false;
    
    state = state.copyWith(isActionLoading: true, error: null);
    try {
      await action();
      // Success: Fetch latest fresh data from backend
      await refreshAll(month: month, year: year, isSilent: true);
      state = state.copyWith(isActionLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isActionLoading: false, error: e.toString());
      return false;
    }
  }
}

final foodProvider = StateNotifierProvider<FoodNotifier, FoodState>((ref) {
  final api = ref.watch(foodRequestApiProvider);
  final userId = ref.watch(authProvider.select((s) => s.user?.userId));
  return FoodNotifier(api, ref, userId);
});
