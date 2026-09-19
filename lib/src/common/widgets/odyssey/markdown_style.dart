import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../theme/app_sizes.dart';
import '../../theme/app_typography.dart';
import '../../theme/odyssey_tokens.dart';

/// The Odyssey type scale, expressed as a Markdown stylesheet.
///
/// The legal documents ship as Markdown, so they have to be rendered as
/// Markdown — showing the source means `#` and `**` on screen. What a renderer
/// must not do is bring its own type scale along, so every slot here maps to a
/// role from [AppTypography].
MarkdownStyleSheet odysseyMarkdownStyle(BuildContext context) {
  final t = context.odyssey;

  return MarkdownStyleSheet(
    h1: AppTypography.statSmall.copyWith(color: t.ink),
    h1Padding: const EdgeInsets.only(top: AppSizes.space18, bottom: 4),
    h2: AppTypography.sectionHeading.copyWith(color: t.ink),
    h2Padding: const EdgeInsets.only(top: AppSizes.space18, bottom: 4),
    h3: AppTypography.rowTitle.copyWith(color: t.ink),
    h3Padding: const EdgeInsets.only(top: AppSizes.space14, bottom: 2),
    h4: AppTypography.rowLabel.copyWith(color: t.ink),
    h5: AppTypography.rowLabel.copyWith(color: t.ink2),
    h6: AppTypography.legend.copyWith(color: t.ink2),
    p: AppTypography.body.copyWith(color: t.ink2),
    pPadding: const EdgeInsets.only(bottom: AppSizes.space8),
    strong: AppTypography.body.copyWith(
      fontWeight: FontWeight.w700,
      color: t.ink,
    ),
    em: AppTypography.body.copyWith(
      fontStyle: FontStyle.italic,
      color: t.ink2,
    ),
    listBullet: AppTypography.body.copyWith(color: t.ink2),
    listIndent: AppSizes.space20,
    blockquote: AppTypography.body.copyWith(color: t.ink3),
    blockquoteDecoration: BoxDecoration(
      border: Border(left: BorderSide(color: t.hairlineStrong, width: 2)),
    ),
    blockquotePadding: const EdgeInsets.only(left: AppSizes.space14),
    code: AppTypography.rowMeta.copyWith(
      fontFamily: AppTypography.mono,
      color: t.ink2,
    ),
    codeblockDecoration: BoxDecoration(
      color: t.cardAlt,
      borderRadius: BorderRadius.circular(AppSizes.radiusChip),
    ),
    codeblockPadding: const EdgeInsets.all(AppSizes.space14),
    a: AppTypography.body.copyWith(
      color: t.limeText,
      decoration: TextDecoration.underline,
      decorationColor: t.limeText,
    ),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: t.hairline)),
    ),
    tableHead: AppTypography.legend.copyWith(color: t.ink),
    tableBody: AppTypography.rowMeta.copyWith(color: t.ink2),
    tableBorder: TableBorder.all(color: t.hairline),
  );
}
