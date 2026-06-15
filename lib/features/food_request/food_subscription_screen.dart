import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/food_provider.dart';
import '../../models/food_subscription_model.dart';
import '../auth/login_screen.dart';
import '../dashboard/dashboard_screen.dart';

class FoodSubscriptionScreen extends ConsumerStatefulWidget {
  const FoodSubscriptionScreen({super.key});

  @override
  ConsumerState<FoodSubscriptionScreen> createState() => _FoodSubscriptionScreenState();
}

class _FoodSubscriptionScreenState extends ConsumerState<FoodSubscriptionScreen> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _canGoBack(DateTime date) {
    final now = DateTime.now();
    final limit = DateTime(now.year, now.month - 1);
    return date.isAfter(limit);
  }

  bool _canGoForward(DateTime date) {
    final now = DateTime.now();
    final limit = DateTime(now.year, now.month + 1);
    return date.isBefore(limit);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final currentUser = authState.user;
    final foodState = ref.watch(foodProvider);

    // Listen for errors and show SnackBar
    ref.listen<FoodState>(foodProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: Colors.red),
        );
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF1F5F9),
      endDrawer: _buildEndDrawer(),
      body: SafeArea(
        child: foodState.isLoading && !foodState.isActionLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(foodProvider.notifier).refreshAll(
                month: _currentMonth.month,
                year: _currentMonth.year,
              ),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileHeader(currentUser),
                    const SizedBox(height: 20),
                    _buildBreadcrumb(currentUser),
                    const SizedBox(height: 16),
                    _buildSubscriptionCard(foodState),
                    const SizedBox(height: 16),
                    _buildCalendarCard(foodState),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildEndDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(color: Color(0xFF5C59E8)),
            child: Row(
              children: const [
                Text('RTS Menu', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildDrawerItem(
                  icon: Icons.add_circle_outline,
                  label: 'Add Request',
                  isSelected: false,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const DashboardScreen()),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.restaurant_menu,
                  label: 'Food Request',
                  isSelected: true,
                  iconColor: const Color(0xFF5C59E8),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildDrawerItem(
            icon: Icons.logout,
            label: 'Logout',
            isSelected: false,
            textColor: Colors.red,
            iconColor: Colors.red,
            onTap: () {
              Navigator.pop(context);
              _handleLogout();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return ListTile(
      selected: isSelected,
      selectedTileColor: const Color(0xFF5C59E8).withValues(alpha: 0.1),
      leading: Icon(
        icon,
        color: isSelected ? const Color(0xFF5C59E8) : (iconColor ?? const Color(0xFF64748B)),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? const Color(0xFF5C59E8) : (textColor ?? const Color(0xFF1E293B)),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () {
            ref.read(authProvider.notifier).logout();
            Navigator.pop(context);
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const LoginScreen()));
          }, child: const Text('Logout', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(currentUser) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFE2E8F0),
            child: Text(
              currentUser?.initials ?? '??',
              style: const TextStyle(
                color: Color(0xFF5C59E8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentUser?.name ?? 'User Name',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                Text(
                  'USER ID: ${currentUser?.empId ?? 'N/A'}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                Text(
                  (currentUser?.department ?? 'N/A').toUpperCase(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF5C59E8)),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _handleLogout(),
            icon: const Icon(Icons.logout, size: 16, color: Colors.red),
            label: const Text('LOGOUT', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFEE2E2)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb(currentUser) {
    final bool isIntern = currentUser?.role.toLowerCase() == 'intern';
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFF5C59E8), borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.restaurant, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Food Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        if (!isIntern) 
          IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF5C59E8), size: 30),
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
      ],
    );
  }

  Widget _buildSubscriptionCard(FoodState foodState) {
    final status = foodState.status;
    if (status == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (status.isActive ? const Color(0xFF10B981) : Colors.grey).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.restaurant, color: status.isActive ? const Color(0xFF10B981) : Colors.grey, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Food Subscription', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                        const SizedBox(width: 6),
                        Flexible(child: _buildStatusBadge(status)),
                      ],
                    ),
                    if (status.startDate != null)
                      Text('Opted in since ${DateFormat('dd MMM yyyy').format(status.startDate!)}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    Text('Any changes for next week can be made only before Saturday 6:30 PM of the current week.'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildButtonGrid(status, foodState.isActionLoading),
        ],
      ),
    );
  }

  Widget _buildButtonGrid(FoodSubscriptionStatus status, bool isActionLoading) {
    final bool isActive = status.isActive;
    final bool isSuspended = status.suspendedFrom != null;
    final bool isCancelledNextWeek = status.isCancelledNextWeek;
    final bool isBulkSuspendedNextWeek = status.isBulkSuspendedNextWeek;
    final bool isEnabledNextWeekOnly = status.isEnabledNextWeekOnly;
    final bool canCancelNow = status.canCancelNow;

    return Column(
      children: [
        Row(
          children: [
            // Button 1: Cancel Next Week / Undo Skip
            Expanded(
              child: _buildStatefulButton(
                label: isCancelledNextWeek ? "Undo Skip" : "Skip Next Week",
                icon: isCancelledNextWeek && !canCancelNow ? Icons.lock : Icons.calendar_today,
                color: isCancelledNextWeek ? Colors.green : Colors.amber,
                isLocked: isCancelledNextWeek && !canCancelNow,
                isDisabled: isBulkSuspendedNextWeek || !isActive || (!isCancelledNextWeek && isEnabledNextWeekOnly),
                isLoading: isActionLoading,
                onTap: () {
                  if (isCancelledNextWeek) {
                    debugPrint('DEBUG: Calling Undo Skip API');
                    ref.read(foodProvider.notifier).undoCancelNextWeek();
                  } else {
                    debugPrint('DEBUG: Calling Skip API');
                    ref.read(foodProvider.notifier).cancelNextWeek();
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            // Button 3: Enable Next Week / Undo Resume
            Expanded(
              child: _buildStatefulButton(
                label: isEnabledNextWeekOnly ? "Undo Resume" : "Resume Next Week",
                icon: isEnabledNextWeekOnly && !canCancelNow ? Icons.lock : Icons.event_available,
                color: isEnabledNextWeekOnly ? Colors.green : Colors.blue,
                isLocked: isEnabledNextWeekOnly && !canCancelNow,
                isDisabled: !isSuspended && !isEnabledNextWeekOnly,
                isLoading: isActionLoading,
                onTap: () {
                  if (isEnabledNextWeekOnly) {
                    debugPrint('DEBUG: Calling Undo Resume API');
                    ref.read(foodProvider.notifier).undoEnableNextWeek();
                  } else {
                    debugPrint('DEBUG: Calling Resume Next Week API');
                    ref.read(foodProvider.notifier).enableNextWeek();
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Button 2: Disable Year / Undo Year Pause
            Expanded(
              child: _buildStatefulButton(
                label: isBulkSuspendedNextWeek ? "Undo Year Pause" : "Pause for the Year",
                icon: isBulkSuspendedNextWeek && !canCancelNow ? Icons.lock : Icons.calendar_month,
                color: isBulkSuspendedNextWeek ? Colors.green : Colors.red,
                isLocked: (isBulkSuspendedNextWeek && !canCancelNow) || isEnabledNextWeekOnly,
                isDisabled: !isActive && !isBulkSuspendedNextWeek,
                isLoading: isActionLoading,
                onTap: () {
                  if (isBulkSuspendedNextWeek) {
                    debugPrint('DEBUG: Calling Undo Year Pause API');
                    ref.read(foodProvider.notifier).undoPauseYear();
                  } else {
                    _showPauseConfirmation();
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            // Button 4: Enable Year
            Expanded(
              child: _buildStatefulButton(
                label: "Resume for the Year",
                icon: Icons.calendar_today_rounded,
                color: Colors.green,
                isDisabled: isActive && !isSuspended,
                isLoading: isActionLoading,
                onTap: () {
                  debugPrint('DEBUG: Calling Enable Year API');
                  ref.read(foodProvider.notifier).enableYear();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showPauseConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Pause food for the rest of this year?"),
        content: const Text("Food will be paused from next week onwards. You can undo before Sunday 10:30 AM."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Keep")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              debugPrint('DEBUG: Calling Pause for Year API');
              ref.read(foodProvider.notifier).pauseYear();
            }, 
            child: const Text("Yes, Pause for Year")
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(FoodSubscriptionStatus status) {
    String label = "Active";
    Color color = Colors.green;

    if (!status.isActive) {
      label = "Year Disabled";
      color = Colors.orange;
    } else if (status.isBulkSuspendedNextWeek) {
      label = "Paused from ${status.suspendedFrom ?? 'next week'}";
      color = Colors.red;
    } else if (status.isEnabledNextWeekOnly) {
      label = "Next Week Resumed";
      color = Colors.indigo;
    } else if (status.isCancelledNextWeek) {
      label = "Next Week Skipped";
      color = Colors.amber;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label, 
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildStatefulButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isLocked = false,
    bool isDisabled = false,
    bool isLoading = false,
  }) {
    final bool effectEnabled = !isLocked && !isDisabled && !isLoading;
    final Color displayColor = effectEnabled ? color : Colors.grey;

    return OutlinedButton.icon(
      onPressed: effectEnabled ? onTap : null,
      icon: isLoading 
        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey))
        : Icon(icon, size: 14, color: displayColor),
      label: Text(
        label, 
        style: TextStyle(color: displayColor, fontSize: 10.5, fontWeight: FontWeight.bold),
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: effectEnabled ? color.withValues(alpha: 0.02) : Colors.grey.withValues(alpha: 0.02),
        side: BorderSide(color: effectEnabled ? color.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2)),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildCalendarCard(FoodState foodState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _buildCalendarHeader(),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: foodState.isActionLoading 
              ? const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                )
              : Column(
                  children: [
                    _buildWeekdayHeader(),
                    const SizedBox(height: 8),
                    _buildCalendarGrid(_currentMonth, foodState),
                  ],
                ),
          ),
          const Divider(height: 1),
          _buildHolidaysSection(),
          const Divider(height: 1),
          _buildLegend(),
          _buildCalendarFooter(foodState),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _canGoBack(_currentMonth) ? () {
              setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1));
              ref.read(foodProvider.notifier).refreshAll(month: _currentMonth.month, year: _currentMonth.year);
            } : null, 
            icon: Icon(
              Icons.chevron_left,
              color: _canGoBack(_currentMonth) ? const Color(0xFF1E293B) : Colors.grey[300],
            )
          ),
          Text(DateFormat('MMMM yyyy').format(_currentMonth), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          IconButton(
            onPressed: _canGoForward(_currentMonth) ? () {
              setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1));
              ref.read(foodProvider.notifier).refreshAll(month: _currentMonth.month, year: _currentMonth.year);
            } : null, 
            icon: Icon(
              Icons.chevron_right,
              color: _canGoForward(_currentMonth) ? const Color(0xFF1E293B) : Colors.grey[300],
            )
          ),
        ],
      ),
    );
  }

  Widget _buildHolidaysSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.calendar_month_outlined, size: 16, color: Color(0xFF5C59E8)),
              SizedBox(width: 8),
              Text('HOLIDAYS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF5C59E8))),
            ],
          ),
          const SizedBox(height: 12),
          const Text('2nd and 4th Saturdays are holidays.', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          _buildLegendItem('Working Day', const Color(0xFFDCFCE7)),
          _buildLegendItem('Cancelled', const Color(0xFFFEE2E2)),
          _buildLegendItem('Food Disabled', const Color(0xFFFEF9C3)),
          _buildLegendItem('Holiday', const Color(0xFFF3E8FF)),
          _buildLegendItem('Weekend / Off', const Color(0xFFF3E8FF)),
          _buildLegendItem('Inactive', const Color(0xFFF1F5F9)),
        ],
      ),
    );
  }

  Widget _buildCalendarFooter(FoodState foodState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: Color(0xFFEFF6FF), borderRadius: BorderRadius.vertical(bottom: Radius.circular(16))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Working Days: ${foodState.calendar?.workingDays ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          Text('₹${foodState.calendar?.totalAmount ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5C59E8), fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeader() {
    final days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return Row(
      children: days.map((d) => Expanded(child: Center(child: Text(d, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))))).toList(),
    );
  }

  Widget _buildCalendarGrid(DateTime month, FoodState state) {
    int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    DateTime firstDay = DateTime(month.year, month.month, 1);
    int startWeekday = firstDay.weekday; 
    List<Widget> rows = [];
    List<DateTime?> currentWeek = List.filled(7, null);

    for (int i = 0; i < startWeekday - 1; i++) currentWeek[i] = null;

    for (int day = 1; day <= daysInMonth; day++) {
      int columnIndex = (startWeekday - 1 + day - 1) % 7;
      DateTime date = DateTime(month.year, month.month, day);
      currentWeek[columnIndex] = date;
      if (columnIndex == 6 || day == daysInMonth) {
        rows.add(Row(children: currentWeek.map((d) => Expanded(child: _buildDayCell(d, state))).toList()));
        currentWeek = List.filled(7, null);
      }
    }
    return Column(children: rows);
  }

  Widget _buildDayCell(DateTime? date, FoodState state) {
    if (date == null) return const SizedBox(height: 44);
    final days = state.calendar?.days ?? [];
    final dayData = days.firstWhere(
      (d) => d.date.year == date.year && d.date.month == date.month && d.date.day == date.day,
      orElse: () => FoodCalendarDay(date: date, type: 'unknown')
    );

    Color bgColor = const Color(0xFFF3F4F6);
    Color textColor = const Color(0xFF6B7280);

    switch (dayData.type) {
      case 'working':
      case 'working-saturday': bgColor = const Color(0xFFDCFCE7); textColor = const Color(0xFF166534); break;
      case 'cancelled': bgColor = const Color(0xFFFEE2E2); textColor = const Color(0xFF991B1B); break;
      case 'disabled': bgColor = const Color(0xFFFEF9C3); textColor = const Color(0xFF854D0E); break;
      case 'holiday':
      case 'weekend': bgColor = const Color(0xFFF3E8FF); textColor = const Color(0xFF7C3AED); break;
      case 'inactive': bgColor = const Color(0xFFF1F5F9); textColor = const Color(0xFF94A3B8); break;
    }

    return Container(
      height: 40,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
      child: Center(child: Text(date.day.toString(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor))),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
      ],
    );
  }
}
