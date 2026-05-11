import 'package:flutter/material.dart';
import '../../models/request_model.dart';

class StatusBadge extends StatelessWidget {
  final RequestStatus status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    switch (status) {
      case RequestStatus.approved:
        color = const Color(0xFF10B981);
        text = 'Approved';
        break;
      case RequestStatus.rejected:
        color = const Color(0xFFEF4444);
        text = 'Rejected';
        break;
      case RequestStatus.pending:
        color = Colors.grey;
        text = 'Pending';
        break;
      case RequestStatus.checking:
        color = const Color(0xFFF59E0B);
        text = 'Checking';
        break;
      case RequestStatus.open:
        color = const Color(0xFF5C59E8);
        text = 'Open';
        break;
      case RequestStatus.resolved:
        color = const Color(0xFF3B82F6); // Blue for resolved
        text = 'Resolved';
        break;
      case RequestStatus.closed:
        color = const Color(0xFF475569); // Slate Grey for closed
        text = 'Closed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(128)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
