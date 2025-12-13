import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:odyssey/src/features/templates/data/models/template_model.dart';
import 'package:odyssey/src/features/templates/data/repositories/template_repository.dart';

part 'templates_provider.g.dart';

/// Repository provider
@riverpod
TemplateRepository templateRepository(Ref ref) {
  return TemplateRepository();
}

/// State for my templates
class MyTemplatesState {
  final List<TripTemplateModel> templates;
  final bool isLoading;
  final String? error;
  final int total;
  final TemplateCategory? selectedCategory;

  const MyTemplatesState({
    this.templates = const [],
    this.isLoading = false,
    this.error,
    this.total = 0,
    this.selectedCategory,
  });

  MyTemplatesState copyWith({
    List<TripTemplateModel>? templates,
    bool? isLoading,
    String? error,
    int? total,
    TemplateCategory? selectedCategory,
    bool clearCategory = false,
  }) {
    return MyTemplatesState(
      templates: templates ?? this.templates,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      total: total ?? this.total,
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
    );
  }
}

/// Notifier for user's templates
@riverpod
class MyTemplates extends _$MyTemplates {
  @override
  MyTemplatesState build() {
    // Delay loading until after provider is initialized (Riverpod 3 requirement)
    Future.microtask(() => _loadTemplates());
    return const MyTemplatesState(isLoading: true);
  }

  Future<void> _loadTemplates() async {
    try {
      final repository = ref.read(templateRepositoryProvider);
      final response = await repository.getMyTemplates(
        category: state.selectedCategory,
      );
      state = state.copyWith(
        templates: response.templates,
        total: response.total,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    await _loadTemplates();
  }

  Future<void> filterByCategory(TemplateCategory? category) async {
    state = state.copyWith(
      selectedCategory: category,
      clearCategory: category == null,
      isLoading: true,
    );
    await _loadTemplates();
  }

  Future<TripTemplateModel?> createTemplate(TemplateCreateRequest request) async {
    try {
      final repository = ref.read(templateRepositoryProvider);
      final template = await repository.createTemplate(request);
      state = state.copyWith(
        templates: [template, ...state.templates],
        total: state.total + 1,
      );
      return template;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<TripTemplateModel?> createFromTrip(TemplateFromTripRequest request) async {
    try {
      final repository = ref.read(templateRepositoryProvider);
      final template = await repository.createTemplateFromTrip(request);
      state = state.copyWith(
        templates: [template, ...state.templates],
        total: state.total + 1,
      );
      return template;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<bool> deleteTemplate(String templateId) async {
    try {
      final repository = ref.read(templateRepositoryProvider);
      await repository.deleteTemplate(templateId);
      state = state.copyWith(
        templates: state.templates.where((t) => t.id != templateId).toList(),
        total: state.total - 1,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

/// State for public template gallery
class TemplateGalleryState {
  final List<TripTemplateModel> templates;
  final bool isLoading;
  final String? error;
  final int total;
  final TemplateCategory? selectedCategory;
  final String? searchQuery;

  const TemplateGalleryState({
    this.templates = const [],
    this.isLoading = false,
    this.error,
    this.total = 0,
    this.selectedCategory,
    this.searchQuery,
  });

  TemplateGalleryState copyWith({
    List<TripTemplateModel>? templates,
    bool? isLoading,
    String? error,
    int? total,
    TemplateCategory? selectedCategory,
    String? searchQuery,
    bool clearCategory = false,
    bool clearSearch = false,
  }) {
    return TemplateGalleryState(
      templates: templates ?? this.templates,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      total: total ?? this.total,
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
    );
  }
}

/// Notifier for public template gallery
@riverpod
class TemplateGallery extends _$TemplateGallery {
  @override
  TemplateGalleryState build() {
    // Delay loading until after provider is initialized (Riverpod 3 requirement)
    Future.microtask(() => _loadTemplates());
    return const TemplateGalleryState(isLoading: true);
  }

  Future<void> _loadTemplates() async {
    try {
      final repository = ref.read(templateRepositoryProvider);
      final response = await repository.getPublicTemplates(
        category: state.selectedCategory,
        search: state.searchQuery,
      );
      state = state.copyWith(
        templates: response.templates,
        total: response.total,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    await _loadTemplates();
  }

  Future<void> filterByCategory(TemplateCategory? category) async {
    state = state.copyWith(
      selectedCategory: category,
      clearCategory: category == null,
      isLoading: true,
    );
    await _loadTemplates();
  }

  Future<void> search(String? query) async {
    state = state.copyWith(
      searchQuery: query,
      clearSearch: query == null || query.isEmpty,
      isLoading: true,
    );
    await _loadTemplates();
  }

  Future<Map<String, dynamic>?> useTemplate(TripFromTemplateRequest request) async {
    try {
      final repository = ref.read(templateRepositoryProvider);
      return await repository.useTemplate(request.templateId, request);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }
}

/// Provider for a single template
@riverpod
class TemplateDetail extends _$TemplateDetail {
  @override
  Future<TripTemplateModel?> build(String templateId) async {
    try {
      final repository = ref.read(templateRepositoryProvider);
      return await repository.getTemplate(templateId);
    } catch (e) {
      return null;
    }
  }
}
