import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../../common/theme/app_typography.dart';

/// Full-screen viewer for legal documents (Privacy Policy, Terms & Conditions).
class LegalDocumentViewer extends StatefulWidget {
  final String title;
  final String assetPath;

  const LegalDocumentViewer({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  State<LegalDocumentViewer> createState() => _LegalDocumentViewerState();
}

class _LegalDocumentViewerState extends State<LegalDocumentViewer> {
  String _content = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    final content = await rootBundle.loadString(widget.assetPath);
    if (mounted) {
      setState(() {
        _content = content;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return OdysseyScaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.screenPadding,
              AppSizes.contentTop,
              AppSizes.screenPadding,
              AppSizes.space18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ScreenHeader(onBack: () => Navigator.of(context).pop()),
                const SizedBox(height: AppSizes.space18),
                Text(
                  widget.title,
                  style: AppTypography.screenTitle.copyWith(color: t.ink),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSizes.screenPadding,
                    ),
                    child: Column(
                      children: [
                        Skeleton(width: double.infinity, height: 14),
                        SizedBox(height: AppSizes.space10),
                        Skeleton(width: double.infinity, height: 14),
                        SizedBox(height: AppSizes.space10),
                        Skeleton(width: double.infinity, height: 14),
                      ],
                    ),
                  )
                : Markdown(
                    data: _content,
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.screenPadding,
                      0,
                      AppSizes.screenPadding,
                      AppSizes.scrollBottom,
                    ),
                    styleSheet: MarkdownStyleSheet(
                      h1: AppTypography.statSmall.copyWith(color: t.ink),
                      h2: AppTypography.sectionHeading.copyWith(color: t.ink),
                      h3: AppTypography.rowTitle.copyWith(color: t.ink),
                      p: AppTypography.body.copyWith(color: t.ink2),
                      listBullet: AppTypography.body.copyWith(color: t.ink2),
                      strong: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: t.ink,
                      ),
                      em: AppTypography.body.copyWith(
                        fontStyle: FontStyle.italic,
                        color: t.ink3,
                      ),
                      horizontalRuleDecoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: t.hairline),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
