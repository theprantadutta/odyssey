import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/sync/sync_service.dart';

/// Lets a user settle edits that could not be synced.
///
/// Conflicts were already detected and both versions preserved, but there was
/// nothing anywhere in the app that showed them. The work was kept safe and made
/// permanently invisible, which from the user's side is the same as losing it:
/// an edit they made simply never appeared again.
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
  late Future<List<SyncConflict>> _conflicts;

  @override
  void initState() {
    super.initState();
    _conflicts = _load();
  }

  Future<List<SyncConflict>> _load() =>
      DatabaseService().database.syncQueueDao.getUnresolvedConflicts();

  void _reload() {
    if (!mounted) return;
    setState(() => _conflicts = _load());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Unsynced changes')),
      body: FutureBuilder<List<SyncConflict>>(
        future: _conflicts,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final conflicts = snapshot.data ?? const <SyncConflict>[];

          if (conflicts.isEmpty) {
            return _EmptyState(theme: theme);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSizes.space16),
            itemCount: conflicts.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: AppSizes.space12),
            itemBuilder: (context, index) {
              if (index == 0) return _Explanation(theme: theme);

              return _ConflictCard(
                conflict: conflicts[index - 1],
                onResolved: _reload,
              );
            },
          );
        },
      ),
    );
  }
}

/// Says plainly what is being asked and what each choice costs.
class _Explanation extends StatelessWidget {
  const _Explanation({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.space12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Text(
        'These changes were edited here and somewhere else at the same time, so '
        'they were kept aside instead of being overwritten.\n\n'
        'Using the server\'s version replaces what is on this device. Copying '
        'your version puts it on the clipboard so you can paste it back in '
        'yourself — copying does not save or sync anything on its own.',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 56, color: theme.hintColor),
            const SizedBox(height: AppSizes.space16),
            Text('Everything is in sync', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSizes.space8),
            Text(
              'Changes that could not be synced automatically would appear here.',
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final conflict = widget.conflict;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sync_problem_rounded,
                    size: 20, color: AppColors.sunnyYellow),
                const SizedBox(width: AppSizes.space8),
                Expanded(
                  child: Text(
                    _titleFor(conflict.entityType),
                    style: AppTypography.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.space12),

            _VersionBlock(
              label: 'Your version (on this device)',
              payload: conflict.localPayload,
            ),
            const SizedBox(height: AppSizes.space8),
            _VersionBlock(
              label: 'The server\'s version',
              payload: conflict.serverPayload,
            ),

            const SizedBox(height: AppSizes.space12),

            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.space8),
                child: LinearProgressIndicator(),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyMine,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      // Named for what it does. Calling this "Keep mine" implied
                      // the edit was being saved, when nothing was written at
                      // all.
                      label: const Text('Copy my version'),
                    ),
                  ),
                  const SizedBox(width: AppSizes.space8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _useServerVersion,
                      child: const Text('Use server version'),
                    ),
                  ),
                ],
              ),
              if (_copied) ...[
                const SizedBox(height: AppSizes.space8),
                Text(
                  'Copied. Open the ${_titleFor(conflict.entityType).toLowerCase()} '
                  'and paste what you want to keep, then come back and dismiss '
                  'this.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor),
                ),
                const SizedBox(height: AppSizes.space8),
                TextButton(
                  onPressed: _dismiss,
                  child: const Text('I\'ve pasted it — dismiss'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// Puts the local edit on the clipboard. Nothing else.
  ///
  /// The conflict is deliberately **not** resolved here: a clipboard copy is not
  /// a save, and the disagreement is still outstanding until the user has done
  /// something with what they copied. If the copy itself fails, nothing changes
  /// at all.
  Future<void> _copyMine() async {
    final messenger = ScaffoldMessenger.of(context);
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

      messenger.showSnackBar(const SnackBar(
        content: Text('Your version is on the clipboard. It has not been saved.'),
      ));
    } catch (e) {
      AppLogger.error('Could not copy a conflict payload: $e');

      if (!mounted) return;
      setState(() => _busy = false);

      messenger.showSnackBar(const SnackBar(
        content: Text('Could not copy that. Nothing has been changed.'),
      ));
    }
  }

  /// Writes the server's copy over the local record, then clears the conflict.
  Future<void> _useServerVersion() async {
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Use the server\'s version?'),
            content: const Text(
              'Your version on this device will be replaced. Copy it first if '
              'you want to keep any of it.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Replace'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    setState(() => _busy = true);

    // The conflict is cleared inside this call, and only when the write
    // succeeded - so a failure leaves the disagreement, and the local edit,
    // exactly where they were.
    final applied =
        await SyncService().resolveConflictWithServerVersion(widget.conflict);

    if (!mounted) return;
    setState(() => _busy = false);

    if (applied) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Updated to the server\'s version.'),
      ));
      widget.onResolved();
      return;
    }

    messenger.showSnackBar(const SnackBar(
      content: Text(
        'Could not apply the server\'s version. Nothing was changed, and this '
        'is still here.',
      ),
    ));
  }

  /// Clears a conflict whose local version the user has already exported.
  ///
  /// The record keeps whatever it currently holds. This only retires the
  /// outstanding disagreement, and only once the user says they are done.
  Future<void> _dismiss() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);

    final dismissed = await SyncService().dismissConflict(widget.conflict.id);

    if (!mounted) return;
    setState(() => _busy = false);

    if (dismissed) {
      widget.onResolved();
      return;
    }

    messenger.showSnackBar(const SnackBar(
      content: Text('Could not dismiss that just now. Please try again.'),
    ));
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
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.space12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSizes.space4),
          Text(_summarise(payload), style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  /// Shows the fields a person can recognise, not the raw JSON.
  ///
  /// Falls back to the payload itself when it cannot be read: something
  /// unreadable is still better than an empty box, because the user can at least
  /// copy it.
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
