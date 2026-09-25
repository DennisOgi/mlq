import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_constants.dart';
import '../models/library_watch_limit.dart';

Future<void> showLibraryWatchLimitDialog(
  BuildContext context,
  LibraryWatchStatus status,
) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.hourglass_top_rounded, color: AppColors.primary, size: 22),
          const SizedBox(width: 8),
          Text(
            'Daily limit reached',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
        ],
      ),
      content: Text(
        'You can watch up to $kLibraryDailyVideoLimit library videos per day. '
        'You have used ${status.count} of ${status.limit} today. '
        'Come back tomorrow to watch more.',
        style: GoogleFonts.nunito(color: Colors.white70, height: 1.45),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('OK', style: TextStyle(color: AppColors.primary)),
        ),
      ],
    ),
  );
}
