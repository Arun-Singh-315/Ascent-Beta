import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:flutter/material.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/database/app_database.dart';
import 'thought_wall_screen.dart';

Future<void> showThoughtDetail(BuildContext context, AppDatabase db, int id) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppPalette.transparent,
      builder: (context) => AppCard(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        nightDecoration: BoxDecoration(
          color: context.glass.bg,
          borderRadius: const BorderRadius.vertical(top: AppGeometry.radiusr24),
        ),
        padding: const EdgeInsets.all(AppSpace.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Close note',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: StreamBuilder<Thought?>(
                  stream: (db.select(
                    db.thoughtTable,
                  )..where((t) => t.id.equals(id))).watchSingleOrNull(),
                  builder: (context, snapshot) =>
                      snapshot.connectionState == ConnectionState.waiting
                      ? const Padding(
                          padding: EdgeInsets.all(AppSpace.s24),
                          child: CircularProgressIndicator(),
                        )
                      : snapshot.data == null
                      ? const Padding(
                          padding: EdgeInsets.all(AppSpace.s24),
                          child: Text('This note is no longer available.'),
                        )
                      : ThoughtCardBubble(thought: snapshot.data!, index: 0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
