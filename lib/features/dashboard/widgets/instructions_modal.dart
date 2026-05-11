import 'package:flutter/material.dart';

class InstructionsModal extends StatelessWidget {
  const InstructionsModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 800),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'SYSTEM INSTRUCTIONS',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(height: 32),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection('1. Login', [
                      "Enter your Username / Email and Password on the login screen.",
                      "Click Login to access the RTS dashboard.",
                      "Your name and role (Employee / RM / HOD / Admin) will be shown in the top-right corner.",
                      "Click your avatar and select Logout to safely exit the system.",
                    ]),
                    _buildSection('2. Understanding the Table', [
                      "The table is split into two sections: Requestor Department (blue header) and Assigned Department (orange header)",
                      "Blue highlighted rows are unread — they float to the top so you never miss an update.",
                      "Bold text in a row means it has unseen activity (approval, forwarding, or a status change).",
                      "A blue dot (●) next to the request title in the Details column indicates an unread request.",
                      "Right-click any row to mark it as Unread — it will float back to the top of the table.",
                    ]),
                    _buildSection('3. Adding a New Request', [
                      "Click the green + Add Request button in the top right corner.",
                      "Fill in the Request Title — briefly describe what you need (e.g., 'New Mouse').",
                      "Select the Department to whom you want to assign the task from the dropdown.",
                      "Write a detailed description explaining your request.",
                      "Optionally upload an image or any file supporting your request or the issue.",
                      "Click Submit to send the request. Click Close to discard or return back.",
                    ]),
                    _buildSection('4. Viewing Request Details', [
                      "Click the underlined request title (e.g., 'Mouse') in the Details column to open the detailed popup.",
                      "The left panel shows user info, request title (locked 🔒), assigned department, description, and uploaded image or file.",
                      "The right panel shows the full chat and activity history for that request.",
                    ]),
                    _buildSection('5. Approving / Rejecting / Checking / Forwarding', [
                      "Open the request details by clicking the request title.",
                      "RM Status and HOD Status show '--' until the respective role takes action.",
                      "Add an official comment in the text area, then choose an action:",
                      "→ Approve (green): Marks the request as approved at your level.",
                      "→ Checking (amber): Indicates the request is under review.",
                      "→ Reject (red): Declines the request with your comment.",
                      "Use the Assigned Department dropdown to change the department before forwarding in case the given request is handled by different department.",
                      "If you change the Assigned Department dropdown, the Approve button becomes Forward, once you click on Forward button it shifts the responsibility to the newly forwarded Department.",
                      "All actions are logged in the chat history with your name, role, and timestamp.",
                    ]),
                    _buildSection('6. Chat & Communication', [
                      "Anyone with access can chat on a request — Requestor, RM, HOD, or Admin.",
                      "Type your message in the chat box and press Enter or click the Send (➤) button.",
                      "Click the 📎 (attach button) paperclip icon to attach and send a file or image.",
                      "Click the 🎤 microphone icon to record a voice message to give further updates about the request. Click Stop & Send when done.",
                      "Voice messages appear as playable audio bubbles with a play/pause button.",
                      "All messages show the sender's name, role badge, and timestamp.",
                    ]),
                    _buildSection('7. Closing a Ticket', [
                      "Open the request details and scroll down to the Close Ticket button (red).",
                      "A popup will appear — write a resolution note explaining how the issue was resolved.",
                      "Optionally attach a file or image as evidence for completion of request.",
                      "Click Close Ticket to confirm. Click Cancel to go back.",
                      "Once closed, the Request Status column shows the date with '(Closed)' in green.",
                      "Any files attached in ticket close comment will appear in the request details chat history.",
                    ]),
                    _buildSection('8. Marking as Unread', [
                      "Right-click on any row in the table to open a small context menu.",
                      "Select 'Mark as Unread' — the row turns blue and floats back to the top.",
                      "This is useful for flagging requests that need follow-up attention.",
                      "Opening a request detail automatically marks it as read.",
                    ]),
                    _buildSection('9. Filtering & Searching', [
                      "Use the dropdown filters at the top to filter by Requestor Name, Assigned Name, Department, or Status.",
                      "Use the date picker to filter requests by a specific date.",
                      "Use the Search box on the right to quickly find requests by keyword.",
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<String> points) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5C59E8),
            ),
          ),
          const SizedBox(height: 12),
          ...points.map((point) => Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        point,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF475569), // Fixed: Use Hex color instead of Colors.slate
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
