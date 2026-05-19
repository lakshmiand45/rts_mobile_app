import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/request_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/food_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/status_badge.dart';
import '../auth/login_screen.dart';
import '../food_request/food_request_screen.dart';
import '../food_request/food_subscription_screen.dart';
import '../request_details/request_details_screen.dart';
import 'widgets/add_request_modal.dart';
import 'widgets/switch_role_modal.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _selectedMenuItem = 'Add Request';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(foodProvider.notifier).refreshAll(isSilent: true);
      // Trigger initial fetch based on role
      ref.read(requestProvider.notifier).fetchRequests();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(requestProvider.notifier).updateFilters(search: query);
    });
  }

  String _getDisplayScope(String scope) {
    if (scope == 'sent') return 'Sent';
    if (scope == 'received') return 'Received';
    return 'Request type';
  }

  Future<void> _triggerFoodReminder() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.post('/push/trigger-reminder', {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🍱 Food reminder sent to all subscribers!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to trigger reminder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(requestProvider);
    final authState = ref.watch(authProvider);
    final currentUser = authState.user;
    final bool isManagement = currentUser?.role.toLowerCase() == 'management';
    final bool isRM = currentUser?.role.toLowerCase() == 'rm';
    final bool isHOD = currentUser?.role.toLowerCase() == 'hod';
    final bool isDeptHOD = currentUser?.role.toLowerCase() == 'depthod';

    final bool canAddRequest = !(isRM || isHOD || isDeptHOD || isManagement);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF1F5F9),
      endDrawer: isManagement ? null : _buildEndDrawer(currentUser, canAddRequest),
      body: SafeArea(
        child: Column(
          children: [
            // User Profile Section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Container(
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
                    GestureDetector(
                      onTap: () => showDialog(
                        context: context,
                        builder: (context) => const SwitchRoleModal(),
                      ),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFFE2E8F0),
                        child: Text(
                            currentUser?.initials ?? '??',
                            style: const TextStyle(
                                color: Color(0xFF5C59E8),
                                fontWeight: FontWeight.bold
                            )
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
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B)
                              )
                          ),
                          Text(
                              currentUser?.department ?? 'Department',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569)
                              )
                          ),
                          Text(
                              'USER ID: ${currentUser?.empId ?? 'N/A'}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B)
                              )
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: Icon(
                          isManagement ? Icons.logout : Icons.menu,
                          color: isManagement ? Colors.red : const Color(0xFF5C59E8),
                        ),
                        onPressed: () {
                          if (isManagement) {
                            _handleLogout();
                          } else {
                            _scaffoldKey.currentState?.openEndDrawer();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Search Bar Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: const InputDecoration(
                          hintText: 'Search by name....',
                          hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                          suffixIcon: Icon(Icons.search, color: Color(0xFF94A3B8)),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  if (canAddRequest) ...[
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => showDialog(context: context, builder: (context) => const AddRequestModal()),
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text('Add Request', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Filter Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Row(
                  children: [
                    const Text('Filters', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            if (!isManagement && state.scope != 'all')
                              _buildFilterChip(_getDisplayScope(state.scope), () {
                                ref.read(requestProvider.notifier).updateFilters(scope: 'all');
                              }),
                            if (isManagement)
                              _buildFilterChip('HOD Pending', () {}, showClose: false),
                            if (state.selectedName != null)
                              _buildFilterChip(state.selectedName!, () => ref.read(requestProvider.notifier).updateFilters(clearName: true)),
                            if (state.selectedDept != null)
                              _buildFilterChip(state.selectedDept!, () => ref.read(requestProvider.notifier).updateFilters(clearDept: true)),
                            if (state.selectedAssignedDept != null)
                              _buildFilterChip(state.selectedAssignedDept!, () => ref.read(requestProvider.notifier).updateFilters(clearAssignedDept: true)),
                            if (state.selectedDate != null)
                              _buildFilterChip(state.selectedDate!, () => ref.read(requestProvider.notifier).updateFilters(clearDate: true)),
                            ...state.selectedStatuses.map((s) => _buildFilterChip(s, () {
                              final newList = List<String>.from(state.selectedStatuses)..remove(s);
                              ref.read(requestProvider.notifier).updateFilters(statuses: newList);
                            })),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.filter_list, color: Color(0xFF64748B)),
                      onPressed: () => _showFilterOptions(context, isManagement),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: Stack(
                children: [
                  Opacity(
                    opacity: state.isLoading ? 0.5 : 1.0,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: state.requests.length,
                      itemBuilder: (context, index) => _RequestCard(request: state.requests[index]),
                    ),
                  ),
                  if (state.isLoading)
                    const Center(child: CircularProgressIndicator()),
                  if (!state.isLoading && state.requests.isEmpty)
                    const Center(child: Text('No requests found matching filters')),
                ],
              ),
            ),

            if (!state.isLoading && state.totalPages > 1 && !isManagement)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPageButton('Prev', state.hasPrev ? () {
                      ref.read(requestProvider.notifier).fetchRequests(page: state.currentPage - 1);
                    } : null),
                    const SizedBox(width: 8),
                    ..._buildPageNumbers(state),
                    const SizedBox(width: 8),
                    _buildPageButton('Next', state.hasNext ? () {
                      ref.read(requestProvider.notifier).fetchRequests(page: state.currentPage + 1);
                    } : null),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndDrawer(UserModel? currentUser, bool canAddRequest) {
    final bool canTriggerReminder = currentUser?.role == 'DeptHOD' &&
        (currentUser?.department == 'HR' || currentUser?.department == 'Food Committee');
    final bool isBangalore = currentUser?.location.toLowerCase() == 'bangalore';
    final bool isManagement = currentUser?.role.toLowerCase() == 'management';

    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
            decoration: const BoxDecoration(color: Color(0xFF5C59E8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RTS Menu',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  currentUser?.name ?? 'User Name',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${currentUser?.empId ?? 'N/A'}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
                ),
                Text(
                  'Dept: ${currentUser?.department ?? 'N/A'}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (canAddRequest)
                  _buildDrawerItem(
                    icon: Icons.add_circle_outline,
                    label: 'Add Request',
                    isSelected: _selectedMenuItem == 'Add Request',
                    onTap: () {
                      setState(() => _selectedMenuItem = 'Add Request');
                      Navigator.pop(context);
                      showDialog(context: context, builder: (context) => const AddRequestModal());
                    },
                  ),
                if (isBangalore)
                  _buildDrawerItem(
                    icon: Icons.restaurant_menu,
                    label: 'Food Request',
                    isSelected: _selectedMenuItem == 'Food Request',
                    iconColor: const Color(0xFFF59E0B),
                    onTap: () {
                      setState(() => _selectedMenuItem = 'Food Request');
                      Navigator.pop(context);

                      final foodState = ref.read(foodProvider);
                      if (!foodState.hasSeenOnboarding) {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const FoodRequestScreen()));
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const FoodSubscriptionScreen()));
                      }
                    },
                  ),
                if (canTriggerReminder && isBangalore)
                  _buildDrawerItem(
                    icon: Icons.notification_important,
                    label: 'Trigger Food Reminder',
                    isSelected: false,
                    iconColor: Colors.deepOrange,
                    onTap: () {
                      Navigator.pop(context);
                      _triggerFoodReminder();
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

  List<Widget> _buildPageNumbers(PaginatedRequestState state) {
    List<Widget> buttons = [];
    for (int i = 1; i <= state.totalPages; i++) {
      if (i == 1 || i == state.totalPages || (i >= state.currentPage - 1 && i <= state.currentPage + 1)) {
        buttons.add(_buildPageNumber(i, i == state.currentPage));
      } else if (i == state.currentPage - 2 || i == state.currentPage + 2) {
        buttons.add(const Text('...', style: TextStyle(color: Colors.grey)));
      }
    }
    return buttons;
  }

  Widget _buildPageNumber(int page, bool isSelected) {
    return GestureDetector(
      onTap: isSelected ? null : () => ref.read(requestProvider.notifier).fetchRequests(page: page),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF334155) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text('$page', style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF334155), fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildPageButton(String label, VoidCallback? onTap) {
    bool isDisabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDisabled ? Colors.grey[100] : const Color(0xFF334155),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(label, style: TextStyle(color: isDisabled ? Colors.grey : Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove, {bool showClose = true}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.bold)),
          if (showClose) ...[
            const SizedBox(width: 4),
            GestureDetector(onTap: onRemove, child: const Icon(Icons.close, size: 14, color: Color(0xFF475569))),
          ],
        ],
      ),
    );
  }

  void _showFilterOptions(BuildContext context, bool isManagement) {
    bool isStatusExpanded = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Consumer(builder: (context, ref, _) {
          final state = ref.watch(requestProvider);
          return StatefulBuilder(builder: (context, setModalState) {
            return Container(
              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 40, top: 80),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, spreadRadius: 5)],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)))),

                    if (!isManagement) ...[
                      _buildFilterDropdownField('Request type', _getDisplayScope(state.scope), ['Request type', 'Sent', 'Received'], (val) {
                        String newScope = 'all';
                        if (val == 'Sent') newScope = 'sent';
                        if (val == 'Received') newScope = 'received';
                        ref.read(requestProvider.notifier).updateFilters(scope: newScope);
                      }),
                      const SizedBox(height: 16),
                    ],

                    _buildFilterDropdownField('Requestor Name', state.selectedName, state.filterNames, (val) {
                      ref.read(requestProvider.notifier).updateFilters(name: val);
                    }),
                    const SizedBox(height: 16),

                    _buildFilterDropdownField('Requestor Department', state.selectedDept, state.filterDepts, (val) {
                      ref.read(requestProvider.notifier).updateFilters(dept: val);
                    }),
                    const SizedBox(height: 16),

                    _buildFilterDropdownField('Assigned Department', state.selectedAssignedDept, state.filterAssignedDepts, (val) {
                      ref.read(requestProvider.notifier).updateFilters(assignedDept: val);
                    }),
                    const SizedBox(height: 16),

                    if (!isManagement) ...[
                      Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                        child: Column(
                          children: [
                            InkWell(
                              onTap: () => setModalState(() => isStatusExpanded = !isStatusExpanded),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(state.selectedStatuses.isEmpty ? 'All Statuses' : 'Statuses (${state.selectedStatuses.length})', style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14)),
                                    Icon(isStatusExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: const Color(0xFFCBD5E1)),
                                  ],
                                ),
                              ),
                            ),
                            if (isStatusExpanded)
                              ...state.filterStatuses.map((s) => CheckboxListTile(
                                title: Text(s, style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B))),
                                value: state.selectedStatuses.contains(s),
                                dense: true, controlAffinity: ListTileControlAffinity.trailing, activeColor: const Color(0xFF5C59E8),
                                onChanged: (val) {
                                  final newList = List<String>.from(state.selectedStatuses);
                                  if (val == true) { if (!newList.contains(s)) newList.add(s); } else { newList.remove(s); }
                                  ref.read(requestProvider.notifier).updateFilters(statuses: newList);
                                },
                              )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    GestureDetector(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                        if (picked != null) {
                          ref.read(requestProvider.notifier).updateFilters(date: DateFormat('yyyy-MM-dd').format(picked));
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(state.selectedDate ?? 'mm / dd / yyyy', style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14)),
                            const Icon(Icons.calendar_today_outlined, color: Color(0xFFCBD5E1), size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5C59E8), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Close Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
                  ],
                ),
              ),
            );
          });
        });
      },
    );
  }

  Widget _buildFilterDropdownField(String label, String? value, List<String> items, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : null,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFCBD5E1)),
          hint: Text(label, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14)),
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(color: Color(0xFF1E293B))))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  final RequestModel request;
  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    // Logic: If ticket is Resolved (HOD closed) and User is requestor and Ticket is unread
    final bool isUserRequestor = user != null && (
        user.userId.toString().trim() == request.userId.toString().trim() ||
            user.empId.toString().trim() == request.empId.toString().trim() ||
            user.name.trim().toLowerCase() == request.userName.trim().toLowerCase()
    );

    final bool showAwaitingText = isUserRequestor &&
        request.overallStatus == RequestStatus.resolved &&
        !request.isRead;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: !request.isRead ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: !request.isRead ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0), width: !request.isRead ? 1.5 : 1.0),
      ),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RequestDetailsScreen(ticketId: request.id))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (!request.isRead) const Padding(padding: EdgeInsets.only(right: 8.0), child: Icon(Icons.circle, size: 8, color: Color(0xFF5C59E8))),
                      Flexible(
                        child: Text(
                          'Sl.No - ${request.slNo}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(DateFormat('dd/MM/yyyy').format(request.date), style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      if (request.unreadChatCount > 0) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFF5C59E8), borderRadius: BorderRadius.circular(10)),
                            child: Text(
                              '${request.unreadChatCount} new chat',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Requestor Status', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      const SizedBox(height: 8),
                      Text(request.department, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                      Text(request.designation, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                      Text(request.location, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                      if (showAwaitingText) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Awaiting for your response',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF5C59E8),
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                StatusBadge(status: request.overallStatus),
              ],
            ),
          ],
        ),
      ),
    );
  }
}