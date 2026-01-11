import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../core/utils/file_url_helper.dart';

/// Screen for viewing PDF documents
class PdfViewerScreen extends StatefulWidget {
  final String url;
  final String title;

  const PdfViewerScreen({
    super.key,
    required this.url,
    required this.title,
  });

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

      // Download PDF to temporary file
      final tempDir = await getTemporaryDirectory();
      final fileName = 'pdf_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${tempDir.path}/$fileName';

      // Use authenticated URL for FileRunner files
      final authenticatedUrl = FileUrlHelper.getAuthenticatedUrl(widget.url);

      final dio = Dio();
      await dio.download(
        authenticatedUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      // Load PDF document
      final document = await PdfDocument.openFile(filePath);
      _totalPages = document.pagesCount;

      _pdfController = PdfControllerPinch(
        document: Future.value(document),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load PDF: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoal,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.charcoal,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
        },
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: const Icon(
            Icons.close_rounded,
            size: 20,
            color: Colors.white,
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            widget.title,
            style: AppTypography.labelLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (_totalPages > 0)
            Text(
              'Page $_currentPage of $_totalPages',
              style: AppTypography.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
      centerTitle: true,
      actions: [
        if (_pdfController != null) ...[
          IconButton(
            onPressed: _currentPage > 1
                ? () {
                    HapticFeedback.selectionClick();
                    _pdfController?.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
            icon: Icon(
              Icons.chevron_left_rounded,
              color: _currentPage > 1
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.3),
            ),
          ),
          IconButton(
            onPressed: _currentPage < _totalPages
                ? () {
                    HapticFeedback.selectionClick();
                    _pdfController?.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: _currentPage < _totalPages
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_downloadProgress > 0 && _downloadProgress < 1) ...[
              SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  child: LinearProgressIndicator(
                    value: _downloadProgress,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.lavenderDream),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.space16),
              Text(
                'Downloading... ${(_downloadProgress * 100).toInt()}%',
                style: AppTypography.bodyMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ] else ...[
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.lavenderDream),
              ),
              const SizedBox(height: AppSizes.space16),
              Text(
                'Loading PDF...',
                style: AppTypography.bodyMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.space20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.space16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: AppSizes.space16),
              Text(
                'Unable to load PDF',
                style: AppTypography.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSizes.space8),
              Text(
                _error!,
                style: AppTypography.bodyMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.space20),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _loadPdf();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.space20,
                    vertical: AppSizes.space12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.lavenderDream,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: Text(
                    'Try Again',
                    style: AppTypography.labelLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_pdfController == null) {
      return const SizedBox.shrink();
    }

    return PdfViewPinch(
      controller: _pdfController!,
      onPageChanged: (page) {
        setState(() {
          _currentPage = page;
        });
      },
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.lavenderDream),
          ),
        ),
        pageLoaderBuilder: (_) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.lavenderDream),
          ),
        ),
        errorBuilder: (_, error) => Center(
          child: Text(
            error.toString(),
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.error,
            ),
          ),
        ),
      ),
    );
  }
}
