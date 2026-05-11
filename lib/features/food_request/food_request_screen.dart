import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/food_provider.dart';
import 'food_subscription_screen.dart';

class FoodRequestScreen extends ConsumerWidget {
  const FoodRequestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foodState = ref.watch(foodProvider);
    final bool isSubscribed = foodState.status?.subscribed ?? false;
    final bool isActionLoading = foodState.isActionLoading;

    // Diagnostic Print
    print('DEBUG: FoodRequestScreen build. isSubscribed: $isSubscribed, isLoading: ${foodState.isLoading}');

    // Listen for state changes to navigate automatically if they subscribe
    ref.listen<FoodState>(foodProvider, (previous, next) {
      if (next.status?.subscribed == true) {
        print('DEBUG: Subscription detected via listener. Redirecting...');
        // Note: RoleBaseWrapper in main.dart handles the primary routing, 
        // but pushReplacement ensures a smooth transition if this was pushed.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const FoodSubscriptionScreen()),
        );
      }
    });

    // If already subscribed on entry, redirect immediately
    if (isSubscribed) {
      print('DEBUG: User already subscribed. Triggering immediate redirect.');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const FoodSubscriptionScreen()),
        );
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: const BoxDecoration(
                    color: Color(0xFF5C59E8),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.restaurant, color: Colors.white, size: 32),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Food Request Program',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Daily Meal Subscription',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        'Would you like to opt into the company food request program?',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[700], fontSize: 15, height: 1.5),
                      ),
                      const SizedBox(height: 24),

                      // Details Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow('Cost per working day', '₹30 / day', isPrimary: true),
                            const Divider(height: 24),
                            _buildDetailRow('Working days', 'Mon – Fri (excl. holidays)'),
                            const Divider(height: 24),
                            _buildDetailRow('Cancellation', 'Saturday before 6 PM (next week)'),
                            const Divider(height: 24),
                            _buildDetailRow('Valid until', 'Until account deactivation'),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      Text(
                        'Once opted in, this applies every working day automatically.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                      const SizedBox(height: 32),

                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isActionLoading ? null : () async {
                                print('DEBUG: User clicked Not Now. Marking onboarding as seen.');
                                await ref.read(foodProvider.notifier).completeOnboarding();
                                // RoleBaseWrapper in main.dart will automatically rebuild and navigate away
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Not Now', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: (isSubscribed || isActionLoading) 
                                ? null 
                                : () async {
                                    print('DEBUG: User clicked Yes, Opt In. Starting subscription process...');
                                    final success = await ref.read(foodProvider.notifier).subscribe();
                                    print('DEBUG: Subscription call finished. Success: $success');
                                  },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF5C59E8),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                disabledBackgroundColor: isSubscribed ? Colors.grey[200] : const Color(0xFF5C59E8).withOpacity(0.5),
                                disabledForegroundColor: isSubscribed ? Colors.grey[500] : Colors.white70,
                              ),
                              child: isActionLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(
                                    isSubscribed ? 'Already Opted In' : 'Yes, Opt In',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isPrimary = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: isPrimary ? const Color(0xFF5C59E8) : const Color(0xFF1E293B),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
