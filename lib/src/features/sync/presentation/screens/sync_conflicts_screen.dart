import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/sync/sync_service.dart';

/// Lets a user settle edits that could not be synced.
///
/// Conflicts were already detected and both versions preserved, but there was
/// nothing anywhere in the app that showed them. The work was kept safe and
/// made permanently invisible, which from the user's side is the same as
/// losing it: an edit they made simply never appeared again.
///
/// Two actions, and each does exactly what it says:
///
/// * **Use the server's version** writes the server's copy over the local
///   record. Recording a conflict deliberately writes nothing, so the local row
///   still holds the user's edit until this runs — there is real work here, not
///   a tidy-up.
/// * **Copy my version** puts the local edit on the clipboard. It does not
///   save, sync, or restore anything, and the wording never suggests it does.
///
/// A conflict stays in the list until the action the user chose has actually
/// succeeded. Dismissing it on a failed write would lose their choice *and* the
/// record of the disagreement.
///
/// It is not a merge tool and does not pretend to be one.
class SyncConflictsScreen extends ConsumerStatefulWidget {
  const SyncConflictsScreen({super.key});

  @override
  ConsumerState<SyncConflictsScreen> createState() =>
      _SyncConflictsScreenState();
}

class _SyncConflictsScreenState extends ConsumerState<SyncConflictsScreen> {
  late Future<List<SyncConflict>> _conflicts = _load();

  Future<List<SyncConflict>> _load() =>
      DatabaseService().database.syncQueueDao.getUnresolvedConflicts();

  void _reload() {
    if (!mounted) return;
    setState(() => _conflicts = _load());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return OdysseyScaffold(
      body: FutureBuilder<List<SyncConflict>>(
        future: _conflicts,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState != ConnectionState.done;
          final conflicts = snapshot.data ?? const <SyncConflict>[];

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.screenPadding,
              AppSizes.contentTop,
              AppSizes.screenPadding,
              AppSizes.scrollBottom,
            ),
            children: [
              ScreenHeader(onBack: () => context.pop()),
              const SizedBox(height: AppSizes.space20),
              Text(
                'Unsynced\nchanges',
                style: AppTypography.screenTitle.copyWith(color: t.ink),
              ),
              const SizedBox(height: AppSizes.space20),

              if (loading)
                const Column(
                  children: [
                    Skeleton.row(),
                    SizedBox(height: AppSizes.space10),
                    Skeleton.row(),
                  ],
                )
              else if (conflicts.isEmpty)
                const OdysseyEmptyState(
                  icon: Icons.cloud_done_outlined,
                  message: 'Everything is in sync. Changes that could not be '
                      'saved automatically would appear here.',
                )
              else ...[
                OdysseyCard(
                  radius: AppSizes.radiusTile,
                  padding: const EdgeInsets.all(AppSizes.space18),
                  child: Text(
                    'These were edited here and somewhere else at the same '
                    'time, so they were kept aside instead of being '
                    'overwritten.\n\n'
                    'Using the server\'s version replaces what is on this '
                    'device. Copying your version puts it on the clipboard so '
                    'you can paste it back in yourself — copying does not save '
                    'or sync anything on its own.',
                    style: AppTypography.subtitle.copyWith(color: t.ink2),
                  ),
                ),
                const SizedBox(height: AppSizes.space12),
                for (final conflict in conflicts) ...[
                  _ConflictCard(conflict: conflict, onResolved: _reload),
                  const SizedBox(height: AppSizes.space12),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ConflictCard extends StatefulWidget {
  const _ConflictCard({required this.conflict, required this.onResolved});

  final SyncConflict conflict;
  final VoidCallback onResolved;

  @override
  State<_ConflictCard> createState() => _ConflictCardState();
}

class _ConflictCardState extends State<_ConflictCard> {
  bool _busy = false;

  /// True once the local version has been copied in this session.
  ///
  /// The "done with this" action only appears afterwards, so a conflict cannot
  /// be dismissed on the strength of a copy that never happened.
  bool _copied = false;

  Future<void> _copyMine() async {
    setState(() => _busy = true);

    try {
      await Clipboard.setData(
        ClipboardData(text: _pretty(widget.conflict.localPayload)),
      );

      if (!mounted) return;
      setState(() {
        _busy = false;
        _copied = true;
      });

      showOdysseyMessage(
        context,
        'Your version is on the clipboard. It has not been saved.',
      );
    } catch (e) {
      AppLogger.error('Could not copy a conflict payload: $e');
      if (!mounted) return;
      setState(() => _busy = false);
      showOdysseyMessage(
        context,
        'Could not copy that. Nothing has been changed.',
      );
    }
  }

  /// Writes the server's copy over the local record, then clears the conflict.
  Future<void> _useServerVersion() async {
    final confirmed = await showOdysseyConfirm(
      context: context,
      title: 'Use the server\'s version?',
      body: const [
        'Your version on this device will be replaced. Copy it first if you '
            'want to keep any of it.',
      ],
      confirmLabel: 'Replace mine',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);

    // The conflict is cleared inside this call, and only when the write
    // succeeded — so a failure leaves the disagreement, and the local edit,
    // exactly where they were.
    final applied = await SyncService().resolveConflictWithServerVersion(
      widget.conflict,
    );

    if (!mounted) return;
    setState(() => _busy = false);

    if (applied) {
      showOdysseyMessage(context, 'Updated to the server\'s version.');
      widget.onResolved();
      return;
    }

    showOdysseyMessage(
      context,
      'Could not apply the server\'s version. Nothing was changed, and this '
      'is still here.',
    );
  }

  /// Clears a conflict whose local version the user has already exported.
  ///
  /// The record keeps whatever it currently holds. This only retires the
  /// outstanding disagreement, and only once the user says they are done.
  Future<void> _dismiss() async {
    setState(() => _busy = true);
    final dismissed = await SyncService().dismissConflict(widget.conflict.id);

    if (!mounted) return;
    setState(() => _busy = false);

    if (dismissed) {
      widget.onResolved();
      return;
    }

    showOdysseyMessage(context, 'Could not dismiss that. It is still here.');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final conflict = widget.conflict;

    return OdysseyCard(
      radius: AppSizes.radiusTile,
      padding: const EdgeInsets.all(AppSizes.space18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          EyebrowLabel(_titleFor(conflict.entityType)),
          const SizedBox(height: AppSizes.space14),

          _VersionBlock(
            label: 'Yours, on this device',
            payload: conflict.localPayload,
          ),
          const SizedBox(height: AppSizes.space8),
          _VersionBlock(
            label: 'The server\'s',
            payload: conflict.serverPayload,
          ),
          const SizedBox(height: AppSizes.space14),

          if (_busy)
            const ProgressTrack(value: 1)
          else ...[
            Row(
              children: [
                Expanded(
                  child: PillButton(
                    // Named for what it does. Calling this "Keep mine"
                    // implied the edit was being saved, when nothing was
                    // written at all.
                    label: 'Copy mine',
                    style: PillStyle.outline,
                    onPressed: _copyMine,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSizes.space14,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.space10),
                Expanded(
                  child: PillButton(
                    label: 'Use the server\'s',
                    onPressed: _useServerVersion,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSizes.space14,
                    ),
                  ),
                ),
              ],
            ),
            if (_copied) ...[
              const SizedBox(height: AppSizes.space12),
              Text(
                'Copied. Open the '
                '${_titleFor(conflict.entityType).toLowerCase()} and paste '
                'what you want to keep, then come back and dismiss this.',
                style: AppTypography.rowMeta.copyWith(color: t.ink3),
              ),
              const SizedBox(height: AppSizes.space10),
              PillButton(
                label: 'I have pasted it — dismiss',
                style: PillStyle.outline,
                onPressed: _dismiss,
                padding: const EdgeInsets.symmetric(
                  vertical: AppSizes.space14,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  static String _titleFor(String entityType) {
    final spaced = entityType.replaceAll('_', ' ');
    if (spaced.isEmpty) return 'Change';
    return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
  }

  static String _pretty(String payload) {
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(payload));
    } catch (_) {
      return payload;
    }
  }
}

/// One side of a conflict, rendered as readable fields.
class _VersionBlock extends StatelessWidget {
  const _VersionBlock({required this.label, required this.payload});

  final String label;
  final String payload;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.space14),
      decoration: BoxDecoration(
        color: t.cardAlt,
        borderRadius: BorderRadius.circular(AppSizes.radiusChip),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EyebrowLabel(label, tight: true),
          const SizedBox(height: AppSizes.space8),
          Text(
            _summarise(payload),
            style: AppTypography.rowMeta.copyWith(color: t.ink2),
          ),
        ],
      ),
    );
  }

  /// Shows the fields a person can recognise, not the raw JSON.
  ///
  /// Falls back to the payload itself when it cannot be read: something
  /// unreadable is still better than an empty box, because the user can at
  /// least copy it.
  static String _summarise(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return payload;
      if (decoded.isEmpty) return 'No details recorded.';

      const interesting = [
        'title', 'name', 'description', 'notes', 'status',
        'amount', 'currency', 'startDate', 'endDate', 'updatedAt',
      ];

      final lines = <String>[];
      for (final key in interesting) {
        final value = decoded[key];
        if (value == null || '$value'.isEmpty) continue;
        lines.add('$key: $value');
      }

      return lines.isEmpty ? payload : lines.join('\n');
    } catch (_) {
      return payload;
    }
  }
}
