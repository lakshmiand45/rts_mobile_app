import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/request_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/role_management_provider.dart';
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
    _searchController.addListener(() {
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(foodProvider.notifier).refreshAll(isSilent: true);
      final role = ref.read(authProvider).user?.role.toLowerCase() ?? '';
      if (role.contains('management')) {
        ref.read(roleManagementProvider.notifier).fetchFilters();
        ref.read(roleManagementProvider.notifier).fetchRequests();
      } else {
        ref.read(requestProvider.notifier).fetchRequests();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query, bool isManagement) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (isManagement) {
        ref.read(roleManagementProvider.notifier).updateFilters(search: query);
      } else {
        ref.read(requestProvider.notifier).updateFilters(search: query);
      }
    });
  }

  void _clearSearch(bool isManagement) {
    _searchController.clear();
    _onSearchChanged('', isManagement);
    setState(() {});
  }

  String _getDisplayScope(String scope) {
    if (scope == 'sent') return 'Sent';
    if (scope == 'received') return 'Received';
    return 'Request type';
  }

  Future<void> _refreshData() async {
    final role = ref.read(authProvider).user?.role.toLowerCase() ?? '';
    if (role.contains('management')) {
      await ref.read(roleManagementProvider.notifier).fetchFilters();
      await ref.read(roleManagementProvider.notifier).fetchRequests(page: 1);
    } else {
      await ref.read(requestProvider.notifier).fetchRequests(page: 1);
    }
    await ref.read(foodProvider.notifier).refreshAll(isSilent: true);
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
    final authState = ref.watch(authProvider);
    final currentUser = authState.user;
    final bool isManagement = currentUser?.role.toLowerCase().contains('management') ?? false;

    final standardState = ref.watch(requestProvider);
    final mgmtState = ref.watch(roleManagementProvider);

    // Common accessors
    final requests = isManagement ? mgmtState.requests : standardState.requests;
    final isLoading = isManagement ? mgmtState.isLoading : standardState.isLoading;
    final totalItems = isManagement ? mgmtState.totalItems : standardState.totalItems;
    final totalPages = isManagement ? mgmtState.totalPages : standardState.totalPages;
    final currentPage = isManagement ? mgmtState.currentPage : standardState.currentPage;
    final hasNext = isManagement ? mgmtState.hasNext : standardState.hasNext;
    final hasPrev = isManagement ? mgmtState.hasPrev : standardState.hasPrev;

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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
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
                          Text(
                              (currentUser?.role ?? '').toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF90EE90)
                              )
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.refresh, color: Color(0xFF5C59E8), size: 22),
                        onPressed: _refreshData,
                        tooltip: 'Refresh Dashboard',
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
                        onChanged: (val) => _onSearchChanged(val, isManagement),
                        decoration: InputDecoration(
                          hintText: 'Search anything....',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Color(0xFF94A3B8)),
                                  onPressed: () => _clearSearch(isManagement),
                                )
                              : null,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          children: isManagement 
                            ? _buildManagementFilterChips(mgmtState)
                            : _buildStandardFilterChips(standardState),
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
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: Row(
                children: [
                  const Text(
                    'Total Requests: ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                  Text(
                    '$totalItems',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF5C59E8),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshData,
                child: Stack(
                  children: [
                    Opacity(
                      opacity: isLoading ? 0.5 : 1.0,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: requests.length,
                        itemBuilder: (context, index) => _RequestCard(request: requests[index]),
                      ),
                    ),
                    if (isLoading)
                      const Center(child: CircularProgressIndicator()),
                    if (!isLoading && requests.isEmpty)
                      Center(
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Container(
                            height: 200,
                            alignment: Alignment.center,
                            child: const Text('No requests found matching filters'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            if (!isLoading && totalPages > 1)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPageButton('Prev', hasPrev ? () {
                      if (isManagement) {
                        ref.read(roleManagementProvider.notifier).fetchRequests(page: currentPage - 1);
                      } else {
                        ref.read(requestProvider.notifier).fetchRequests(page: currentPage - 1);
                      }
                    } : null),
                    const SizedBox(width: 8),
                    ..._buildPageNumbers(currentPage, totalPages, isManagement),
                    const SizedBox(width: 8),
                    _buildPageButton('Next', hasNext ? () {
                      if (isManagement) {
                        ref.read(roleManagementProvider.notifier).fetchRequests(page: currentPage + 1);
                      } else {
                        ref.read(requestProvider.notifier).fetchRequests(page: currentPage + 1);
                      }
                    } : null),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStandardFilterChips(PaginatedRequestState state) {
    return [
      if (state.scope != 'all')
        _buildFilterChip(_getDisplayScope(state.scope), () {
          ref.read(requestProvider.notifier).updateFilters(scope: 'all');
        }),
      if (state.selectedName != null)
        _buildFilterChip(state.selectedName!, () => ref.read(requestProvider.notifier).updateFilters(clearName: true)),
      if (state.selectedDept != null)
        _buildFilterChip(state.selectedDept!, () => ref.read(requestProvider.notifier).updateFilters(clearDept: true)),
      if (state.selectedAssignedDept != null)
        _buildFilterChip(state.selectedAssignedDept!, () => ref.read(requestProvider.notifier).updateFilters(clearAssignedDept: true)),
      if (state.selectedDate != null)
        _buildFilterChip(state.selectedDate!, () => ref.read(requestProvider.notifier).updateFilters(clearDate: true)),
      if (state.startDate != null)
        _buildFilterChip('From: ${state.startDate}', () => ref.read(requestProvider.notifier).updateFilters(clearRange: true)),
      if (state.endDate != null)
        _buildFilterChip('To: ${state.endDate}', () => ref.read(requestProvider.notifier).updateFilters(clearRange: true)),
      ...state.selectedStatuses.map((s) => _buildFilterChip(s, () {
        final newList = List<String>.from(state.selectedStatuses)..remove(s);
        ref.read(requestProvider.notifier).updateFilters(statuses: newList);
      })),
    ];
  }
//For Maanagement Role
  List<Widget> _buildManagementFilterChips(RoleManagementState state) {
    return [
      if (state.selectedName != null)
        _buildFilterChip(state.selectedName!, () => ref.read(roleManagementProvider.notifier).updateFilters(resetName: true)),
      if (state.selectedRequestorDept != null)
        _buildFilterChip(state.selectedRequestorDept!, () => ref.read(roleManagementProvider.notifier).updateFilters(resetRequestorDept: true)),
      if (state.selectedAssignedDept != null)
        _buildFilterChip(state.selectedAssignedDept!, () => ref.read(roleManagementProvider.notifier).updateFilters(resetAssignedDept: true)),
      if (state.selectedHodStatus != null)
        _buildFilterChip('HOD: ${state.selectedHodStatus}', () => ref.read(roleManagementProvider.notifier).updateFilters(resetHodStatus: true)),
      if (state.selectedRmStatus != null)
        _buildFilterChip('RM: ${state.selectedRmStatus}', () => ref.read(roleManagementProvider.notifier).updateFilters(resetRmStatus: true)),
      if (state.startDate != null)
        _buildFilterChip('From: ${state.startDate}', () => ref.read(roleManagementProvider.notifier).updateFilters(clearRange: true)),
      if (state.endDate != null)
        _buildFilterChip('To: ${state.endDate}', () => ref.read(roleManagementProvider.notifier).updateFilters(clearRange: true)),
    ];
  }

  Widget _buildEndDrawer(UserModel? currentUser, bool canAddRequest) {
    final bool canTriggerReminder = currentUser?.role == 'DeptHOD' &&
        (currentUser?.department == 'HR' || currentUser?.department == 'Food Committee');
    final bool isBangalore = currentUser?.location.toLowerCase() == 'bangalore';

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
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                ),
                Text(
                  'Dept: ${currentUser?.department ?? 'N/A'}',
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
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
                      setState(() => _selectedMenuItem == 'Add Request');
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
                      setState(() => _selectedMenuItem == 'Food Request');
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
      selectedTileColor: const Color(0xFF5C59E8).withOpacity(0.1),
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

  List<Widget> _buildPageNumbers(int current, int total, bool isManagement) {
    List<Widget> buttons = [];
    for (int i = 1; i <= total; i++) {
      if (i == 1 || i == total || (i >= current - 1 && i <= current + 1)) {
        buttons.add(_buildPageNumber(i, i == current, isManagement));
      } else if (i == current - 2 || i == current + 2) {
        buttons.add(const Text('...', style: TextStyle(color: Colors.grey)));
      }
    }
    return buttons;
  }

  Widget _buildPageNumber(int page, bool isSelected, bool isManagement) {
    return GestureDetector(
      onTap: isSelected ? null : () {
        if (isManagement) {
          ref.read(roleManagementProvider.notifier).fetchRequests(page: page);
        } else {
          ref.read(requestProvider.notifier).fetchRequests(page: page);
        }
      },
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
    // Explicitly trigger filter fetch when the modal is opened
    if (isManagement) {
      ref.read(roleManagementProvider.notifier).fetchFilters();
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Consumer(builder: (context, ref, _) {
          if (isManagement) {
            final state = ref.watch(roleManagementProvider);
            return _buildManagementFilterSheet(context, ref, state);
          } else {
            final state = ref.watch(requestProvider);
            return _buildStandardFilterSheet(context, ref, state);
          }
        });
      },
    );
  }

  Future<void> _selectDateRange(BuildContext context, bool isManagement) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF5C59E8),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final start = DateFormat('yyyy-MM-dd').format(picked.start);
      final end = DateFormat('yyyy-MM-dd').format(picked.end);
      if (isManagement) {
        ref.read(roleManagementProvider.notifier).updateFilters(startDate: start, endDate: end);
      } else {
        ref.read(requestProvider.notifier).updateFilters(startDate: start, endDate: end);
      }
    }
  }

  Widget _buildStandardFilterSheet(BuildContext context, WidgetRef ref, PaginatedRequestState state) {
    final bool hasAnyFilter = state.selectedName != null || state.selectedDept != null || state.selectedAssignedDept != null || state.selectedStatuses.isNotEmpty || state.selectedDate != null || state.scope != 'all' || state.startDate != null;
    
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 40, top: 80),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)]),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)))),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Filter Options', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                if (hasAnyFilter)
                  TextButton.icon(
                    onPressed: () => ref.read(requestProvider.notifier).updateFilters(clearName: true, clearDept: true, clearAssignedDept: true, clearDate: true, clearRange: true, clearStatus: true, scope: 'all'),
                    icon: const Icon(Icons.refresh, size: 18, color: Colors.red),
                    label: const Text('Clear All', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _buildFilterDropdownField('Request type', _getDisplayScope(state.scope), ['Request type', 'Sent', 'Received'], (val) {
              String newScope = 'all';
              if (val == 'Sent') newScope = 'sent';
              if (val == 'Received') newScope = 'received';
              ref.read(requestProvider.notifier).updateFilters(scope: newScope);
            }, onClear: state.scope != 'all' ? () => ref.read(requestProvider.notifier).updateFilters(scope: 'all') : null),
            const SizedBox(height: 16),
            _buildFilterDropdownField('Requestor Name', state.selectedName, state.filterNames, (val) => ref.read(requestProvider.notifier).updateFilters(name: val), onClear: state.selectedName != null ? () => ref.read(requestProvider.notifier).updateFilters(clearName: true) : null),
            const SizedBox(height: 16),
            _buildFilterDropdownField('Requestor Department', state.selectedDept, state.filterDepts, (val) => ref.read(requestProvider.notifier).updateFilters(dept: val), onClear: state.selectedDept != null ? () => ref.read(requestProvider.notifier).updateFilters(clearDept: true) : null),
            const SizedBox(height: 16),
            _buildFilterDropdownField('Assigned Department', state.selectedAssignedDept, state.filterAssignedDepts, (val) => ref.read(requestProvider.notifier).updateFilters(assignedDept: val), onClear: state.selectedAssignedDept != null ? () => ref.read(requestProvider.notifier).updateFilters(clearAssignedDept: true) : null),
            const SizedBox(height: 16),
            _buildFilterDropdownField('Status', state.selectedStatuses.isNotEmpty ? state.selectedStatuses.first : null, state.filterStatuses, (val) => ref.read(requestProvider.notifier).updateFilters(statuses: val != null ? [val] : []), onClear: state.selectedStatuses.isNotEmpty ? () => ref.read(requestProvider.notifier).updateFilters(clearStatus: true) : null),
            const SizedBox(height: 16),
            _buildDateRangeSelector(context, state.startDate, state.endDate, false),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5C59E8), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Close Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeSelector(BuildContext context, String? start, String? end, bool isManagement) {
    String display = 'Select Date Range';
    if (start != null && end != null) {
      display = '$start to $end';
    }
    
    return InkWell(
      onTap: () => _selectDateRange(context, isManagement),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: start != null ? const Color(0xFF5C59E8) : const Color(0xFF94A3B8)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                display,
                style: TextStyle(
                  color: start != null ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
                  fontSize: 14,
                ),
              ),
            ),
            if (start != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
                onPressed: () {
                  if (isManagement) {
                    ref.read(roleManagementProvider.notifier).updateFilters(clearRange: true);
                  } else {
                    ref.read(requestProvider.notifier).updateFilters(clearRange: true);
                  }
                },
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            const Icon(Icons.keyboard_arrow_down, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementFilterSheet(BuildContext context, WidgetRef ref, RoleManagementState state) {
    final bool hasAnyFilter = state.selectedName != null || state.selectedRequestorDept != null || state.selectedAssignedDept != null || state.selectedHodStatus != null || state.selectedRmStatus != null || state.startDate != null;

    // Type-safe lookup of labels using .where().firstOrNull
    final hodMatch = state.hodStatuses.where((e) => e['value'] == state.selectedHodStatus).firstOrNull;
    final selectedHodLabel = hodMatch != null ? hodMatch['label']?.toString() : state.selectedHodStatus;
        
    final rmMatch = state.rmStatuses.where((e) => e['value'] == state.selectedRmStatus).firstOrNull;
    final selectedRmLabel = rmMatch != null ? rmMatch['label']?.toString() : state.selectedRmStatus;

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 40, top: 80),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)]),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)))),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Management Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                if (hasAnyFilter)
                  TextButton.icon(
                    onPressed: () => ref.read(roleManagementProvider.notifier).updateFilters(clearAll: true),
                    icon: const Icon(Icons.refresh, size: 18, color: Colors.red),
                    label: const Text('Clear All', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _buildFilterDropdownField('Requestor Name', state.selectedName, state.names,
              (val) => ref.read(roleManagementProvider.notifier).updateFilters(name: val),
              onClear: state.selectedName != null ? () => ref.read(roleManagementProvider.notifier).updateFilters(resetName: true) : null,
            ),
            const SizedBox(height: 16),
            _buildFilterDropdownField('Requestor Dept', state.selectedRequestorDept, state.requestorDepts,
              (val) => ref.read(roleManagementProvider.notifier).updateFilters(requestorDept: val),
              onClear: state.selectedRequestorDept != null ? () => ref.read(roleManagementProvider.notifier).updateFilters(resetRequestorDept: true) : null,
            ),
            const SizedBox(height: 16),
            _buildFilterDropdownField('Assigned Dept', state.selectedAssignedDept, state.assignedDepts,
              (val) => ref.read(roleManagementProvider.notifier).updateFilters(assignedDept: val),
              onClear: state.selectedAssignedDept != null ? () => ref.read(roleManagementProvider.notifier).updateFilters(resetAssignedDept: true) : null,
            ),
            const SizedBox(height: 16),
            _buildFilterDropdownField('HOD Status', selectedHodLabel, state.hodStatuses.map((e) => e['label'].toString()).toList(), (val) {
              final match = state.hodStatuses.where((e) => e['label'] == val).firstOrNull;
              final valKey = match != null ? match['value'] : val;
              ref.read(roleManagementProvider.notifier).updateFilters(hodStatus: valKey);
            }, onClear: state.selectedHodStatus != null ? () => ref.read(roleManagementProvider.notifier).updateFilters(resetHodStatus: true) : null),
            const SizedBox(height: 16),
            _buildFilterDropdownField('RM Status', selectedRmLabel, state.rmStatuses.map((e) => e['label'].toString()).toList(), (val) {
              final match = state.rmStatuses.where((e) => e['label'] == val).firstOrNull;
              final valKey = match != null ? match['value'] : val;
              ref.read(roleManagementProvider.notifier).updateFilters(rmStatus: valKey);
            }, onClear: state.selectedRmStatus != null ? () => ref.read(roleManagementProvider.notifier).updateFilters(resetRmStatus: true) : null),
            const SizedBox(height: 16),
            _buildDateRangeSelector(context, state.startDate, state.endDate, true),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5C59E8), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Apply Management Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdownField(String label, String? value, List<String> items, ValueChanged<String?> onChanged, {VoidCallback? onClear}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: (value != null && items.contains(value)) ? value : null,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFCBD5E1)),
                hint: Text(label, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14)),
                items: items.toSet().map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(color: Color(0xFF1E293B))))).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
          if (onClear != null && value != null && value != 'Request type')
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
              onPressed: onClear,
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
        ],
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
    final bool isManagement = user?.role.toLowerCase().contains('management') ?? false;

    final bool isUserRequestor = user != null && (
        user.userId.toString().trim() == request.userId.toString().trim() ||
            user.empId.toString().trim() == request.empId.toString().trim() ||
            user.name.trim().toLowerCase() == request.userName.trim().toLowerCase()
    );

    final bool showAwaitingText = isUserRequestor &&
        request.overallStatus == RequestStatus.resolved;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (!request.isRead && !isManagement) ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: (!request.isRead && !isManagement) ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
            width: (!request.isRead && !isManagement) ? 1.5 : 1.0
        ),
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
                      if (!request.isRead && !isManagement) const Padding(padding: EdgeInsets.only(right: 8.0), child: Icon(Icons.circle, size: 8, color: Color(0xFF5C59E8))),
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
                      Text("Request Title: ${request.title}", style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B))),
                      Text(request.department, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (request.assignedStatus != null) ...[
                      const Text('Requestor Status', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      const SizedBox(height: 4),
                      StatusBadge(status: request.assignedStatus!),
                    ],
                    const SizedBox(height: 12),
                    if (!isManagement)
                      IconButton(
                        icon: Icon(
                          request.isRead ? Icons.visibility : Icons.visibility_off,
                          color: request.isRead ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          size: 24,
                        ),
                        onPressed: () {
                          if (request.isRead) {
                            ref.read(requestProvider.notifier).markAsUnread(request.id);
                          } else {
                            ref.read(requestProvider.notifier).markAsRead(request.id);
                          }
                        },
                        tooltip: request.isRead ? 'Mark as Unread' : 'Mark as Read',
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
