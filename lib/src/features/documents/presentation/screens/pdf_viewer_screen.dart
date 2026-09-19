import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:pdfx/pdfx.dart';

import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../../core/network/authenticated_media_fetch.dart';
import '../../../../core/utils/file_url_helper.dart';

/// A document, full screen.
///
/// Always dark regardless of theme: a PDF page is its own white rectangle, and
/// a paper-coloured surround would leave no edge between the page and the app.
class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({
    super.key,
    required this.url,
    required this.title,
  });

  final String url;
  final String title;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  PdfControllerPinch? _pdfController;
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 0;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _loadPdf() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _downloadProgress = 0.0;
      });

      // Private documents come from our API, which authorizes the request
      // against the trip's current permissions.
      final fileUrl = FileUrlHelper.resolve(widget.url);

      // The authenticated manager, not the default one: it attaches the
      // current token and refreshes it on a 401. A document opened after a
      // while of reading locally cached trip data would otherwise be fetched
      // with an expired token and simply fail to open.
      final stream = AuthenticatedMediaCacheManager.instance.getFileStream(
        fileUrl,
        withProgress: true,
      );

      String? filePath;
      await for (final result in stream) {
        if (result is DownloadProgress) {
          if (mounted) {
            setState(() => _downloadProgress = result.progress ?? 0.0);
          }
        } else if (result is FileInfo) {
          filePath = result.file.path;
          break;
        }
      }

      if (filePath == null) throw Exception('Failed to download PDF');

      final document = await PdfDocument.openFile(filePath);
      _totalPages = document.pagesCount;
      _pdfController = PdfControllerPinch(document: Future.value(document));

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'That document would not open.';
        });
      }
    }
  }

  void _step(int delta) {
    HapticFeedback.selectionClick();
    const duration = Duration(milliseconds: 300);
    if (delta > 0) {
      _pdfController?.nextPage(duration: duration, curve: Curves.easeInOut);
    } else {
      _pdfController?.previousPage(duration: duration, curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: Stack(
        children: [
          Positioned.fill(child: _buildBody()),

          Positioned(
            left: AppSizes.screenPadding,
            right: AppSizes.screenPadding,
            top: topInset + AppSizes.space14,
            child: Row(
              children: [
                CircleButton(
                  glyph: '←',
                  style: CircleStyle.glass,
                  onPressed: () => Navigator.of(context).pop(),
                  semanticLabel: 'Back',
                ),
                const SizedBox(width: AppSizes.space12),
                Expanded(
                  child: Text(
                    widget.title,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.onPhoto,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          if (_totalPages > 1 && _pdfController != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomInset + AppSizes.space20,
              child: Center(
                child: GlassBar(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleButton(
                        glyph: '←',
                        size: AppSizes.circleSm,
                        style: CircleStyle.glass,
                        onPressed: _currentPage > 1 ? () => _step(-1) : null,
                        semanticLabel: 'Previous page',
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.space14,
                        ),
                        child: Text(
                          '$_currentPage / $_totalPages',
                          style: AppTypography.numeral.copyWith(
                            color: AppColors.onPhoto,
                          ),
                        ),
                      ),
                      CircleButton(
                        glyph: '→',
                        size: AppSizes.circleSm,
                        style: CircleStyle.glass,
                        onPressed: _currentPage < _totalPages
                            ? () => _step(1)
                            : null,
                        semanticLabel: 'Next page',
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 120,
              child: ProgressTrack(
                value: _downloadProgress,
                trackColor: const Color(0x1AFFFFFF),
                fillColor: AppColors.accent,
              ),
            ),
            const SizedBox(height: AppSizes.space14),
            Text(
              _downloadProgress > 0 && _downloadProgress < 1
                  ? 'Fetching · ${(_downloadProgress * 100).round()}%'
                  : 'Opening…',
              style: AppTypography.rowMeta.copyWith(color: AppColors.onPhoto2),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppTypography.subtitle.copyWith(
                  color: AppColors.onPhoto,
                ),
              ),
              const SizedBox(height: AppSizes.space18),
              PillButton(
                label: 'Try again',
                style: PillStyle.brand,
                expand: false,
                onPressed: _loadPdf,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.space24,
                  vertical: AppSizes.space14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_pdfController == null) return const SizedBox.shrink();

    return PdfViewPinch(
      controller: _pdfController!,
      onPageChanged: (page) => setState(() => _currentPage = page),
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) => const SizedBox.shrink(),
        pageLoaderBuilder: (_) => const SizedBox.shrink(),
        errorBuilder: (_, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.space24),
            child: Text(
              'That page would not render.',
              textAlign: TextAlign.center,
              style: AppTypography.subtitle.copyWith(
                color: AppColors.onPhoto2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
