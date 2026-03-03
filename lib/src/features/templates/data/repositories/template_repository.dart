import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_service.dart';
import '../../../../core/database/model_converters.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/sync/sync_queue_service.dart';
import '../models/template_model.dart';

/// Template repository - local-first with background API sync
class TemplateRepository {
  final DioClient _dioClient = DioClient();
  AppDatabase get _db => DatabaseService().database;

  /// Get user's templates - reads from local DB, triggers background API refresh
  Future<TemplatesResponse> getMyTemplates({
    int page = 1,
    int pageSize = 20,
    TemplateCategory? category,
  }) async {
    final localTemplates = await _db.templatesDao.getAll();

    if (localTemplates.isNotEmpty || !ConnectivityService().isOnline) {
      var templates = localTemplates.map(templateFromLocal).toList();

      if (category != null) {
        templates = templates.where((t) => t.category == category).toList();
      }

      final total = templates.length;
      final start = (page - 1) * pageSize;
      final end = (start + pageSize).clamp(0, total);
      final paged = start < total ? templates.sublist(start, end) : <TripTemplateModel>[];

      if (ConnectivityService().isOnline) {
        _refreshMyTemplatesFromApi(category: category);
      }

      return TemplatesResponse(templates: paged, total: total);
    }

    return _fetchMyTemplatesFromApi(page: page, pageSize: pageSize, category: category);
  }

  /// Get public templates - reads from local cache, triggers background refresh
  Future<TemplatesResponse> getPublicTemplates({
    int page = 1,
    int pageSize = 20,
    TemplateCategory? category,
    String? search,
  }) async {
    final localPublic = await _db.templatesDao.getAllPublic();

    if (localPublic.isNotEmpty || !ConnectivityService().isOnline) {
      var templates = localPublic.map(templateFromPublicCache).toList();

      if (category != null) {
        templates = templates.where((t) => t.category == category).toList();
      }
      if (search != null && search.isNotEmpty) {
        final q = search.toLowerCase();
        templates = templates.where((t) => t.name.toLowerCase().contains(q)).toList();
      }

      final total = templates.length;
      final start = (page - 1) * pageSize;
      final end = (start + pageSize).clamp(0, total);
      final paged = start < total ? templates.sublist(start, end) : <TripTemplateModel>[];

      if (ConnectivityService().isOnline) {
        _refreshPublicTemplatesFromApi(category: category, search: search);
      }

      return TemplatesResponse(templates: paged, total: total);
    }

    return _fetchPublicTemplatesFromApi(page: page, pageSize: pageSize, category: category, search: search);
  }

  /// Get template by ID - reads from local DB first
  Future<TripTemplateModel> getTemplate(String templateId) async {
    final local = await _db.templatesDao.getById(templateId);
    if (local != null && !local.isDeleted) {
      if (ConnectivityService().isOnline) {
        _refreshTemplateFromApi(templateId);
      }
      return templateFromLocal(local);
    }

    // Check public cache
    final publicLocal = await _db.templatesDao.getPublicById(templateId);
    if (publicLocal != null) {
      if (ConnectivityService().isOnline) {
        _refreshTemplateFromApi(templateId);
      }
      return templateFromPublicCache(publicLocal);
    }

    // Fallback to API
    try {
      final response = await _dioClient.get(ApiConfig.templateDetail(templateId));
      final template = TripTemplateModel.fromJson(response.data as Map<String, dynamic>);
      await _db.templatesDao.upsert(templateToLocal(template));
      return template;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Create template - writes to local DB immediately, syncs in background
  Future<TripTemplateModel> createTemplate(TemplateCreateRequest request) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc();

    final template = TripTemplateModel(
      id: id,
      userId: '',
      name: request.name,
      description: request.description,
      structure: request.structure,
      isPublic: request.isPublic,
      category: request.category,
      useCount: 0,
      createdAt: now,
      updatedAt: now,
    );

    await _db.templatesDao.upsert(templateToLocal(template, isDirty: true, isLocalOnly: true));

    await SyncQueueService().enqueue(
      entityType: 'template',
      entityId: id,
      operation: 'create',
      payload: request.toJson(),
    );

    if (ConnectivityService().isOnline) {
      try {
        final response = await _dioClient.post(ApiConfig.templates, data: request.toJson());
        final serverTemplate = TripTemplateModel.fromJson(response.data as Map<String, dynamic>);
        await _db.templatesDao.upsert(templateToLocal(serverTemplate));
        await _db.syncQueueDao.removeForEntity('template', id);
        return serverTemplate;
      } catch (e) {
        AppLogger.warning('Failed to sync template create, will retry: $e');
      }
    }

    return template;
  }

  /// Update template - writes to local DB immediately, syncs in background
  Future<TripTemplateModel> updateTemplate(
    String templateId,
    Map<String, dynamic> updates,
  ) async {
    final existing = await _db.templatesDao.getById(templateId);
    if (existing != null) {
      final updatedCompanion = LocalTemplatesCompanion(
        id: Value(templateId),
        name: updates.containsKey('name') ? Value(updates['name'] as String) : const Value.absent(),
        description: updates.containsKey('description') ? Value(updates['description'] as String?) : const Value.absent(),
        structureJson: updates.containsKey('structure_json')
            ? Value(updates['structure_json'] is String
                ? updates['structure_json'] as String
                : updates['structure_json'].toString())
            : const Value.absent(),
        isPublic: updates.containsKey('is_public') ? Value(updates['is_public'] as bool) : const Value.absent(),
        category: updates.containsKey('category') ? Value(updates['category'] as String?) : const Value.absent(),
        updatedAt: Value(DateTime.now().toUtc()),
        isDirty: const Value(true),
      );
      await ((_db.update(_db.localTemplates))..where((t) => t.id.equals(templateId))).write(updatedCompanion);
    }

    await SyncQueueService().enqueue(
      entityType: 'template',
      entityId: templateId,
      operation: 'update',
      payload: {...updates, '_base_version': existing?.updatedAt.toIso8601String()},
    );

    if (ConnectivityService().isOnline) {
      try {
        final response = await _dioClient.patch(ApiConfig.templateDetail(templateId), data: updates);
        final serverTemplate = TripTemplateModel.fromJson(response.data as Map<String, dynamic>);
        await _db.templatesDao.upsert(templateToLocal(serverTemplate));
        await _db.syncQueueDao.removeForEntity('template', templateId);
        return serverTemplate;
      } catch (e) {
        AppLogger.warning('Failed to sync template update, will retry: $e');
      }
    }

    final updated = await _db.templatesDao.getById(templateId);
    return updated != null ? templateFromLocal(updated) : throw 'Template not found';
  }

  /// Delete template - soft deletes locally, syncs in background
  Future<void> deleteTemplate(String templateId) async {
    await _db.templatesDao.softDelete(templateId);

    await SyncQueueService().enqueue(
      entityType: 'template',
      entityId: templateId,
      operation: 'delete',
      payload: {},
    );

    if (ConnectivityService().isOnline) {
      try {
        await _dioClient.delete(ApiConfig.templateDetail(templateId));
        await _db.templatesDao.hardDelete(templateId);
        await _db.syncQueueDao.removeForEntity('template', templateId);
      } catch (e) {
        AppLogger.warning('Failed to sync template delete, will retry: $e');
      }
    }
  }

  /// Create template from existing trip - API-only
  Future<TripTemplateModel> createTemplateFromTrip(
    TemplateFromTripRequest request,
  ) async {
    if (!ConnectivityService().isOnline) {
      throw 'Creating templates from trips requires an internet connection';
    }
    try {
      final response = await _dioClient.post(ApiConfig.templateFromTrip, data: request.toJson());
      final template = TripTemplateModel.fromJson(response.data as Map<String, dynamic>);
      await _db.templatesDao.upsert(templateToLocal(template));
      return template;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Fork a template - API-only
  Future<TripTemplateModel> forkTemplate(String templateId) async {
    if (!ConnectivityService().isOnline) {
      throw 'Forking templates requires an internet connection';
    }
    try {
      final response = await _dioClient.post('${ApiConfig.templateDetail(templateId)}/fork');
      final template = TripTemplateModel.fromJson(response.data as Map<String, dynamic>);
      await _db.templatesDao.upsert(templateToLocal(template));
      return template;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Create trip from template - API-only
  Future<Map<String, dynamic>> useTemplate(
    String templateId,
    TripFromTemplateRequest request,
  ) async {
    if (!ConnectivityService().isOnline) {
      throw 'Using templates requires an internet connection';
    }
    try {
      final response = await _dioClient.post(ApiConfig.useTemplate(templateId), data: request.toJson());
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get available categories
  Future<List<CategoryInfo>> getCategories() async {
    try {
      final response = await _dioClient.get('${ApiConfig.templates}/categories');
      return (response.data as List<dynamic>)
          .map((e) => CategoryInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // --- Private Methods ---

  Future<TemplatesResponse> _fetchMyTemplatesFromApi({
    int page = 1,
    int pageSize = 20,
    TemplateCategory? category,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page, 'page_size': pageSize};
      if (category != null) queryParams['category'] = category.apiValue;

      final response = await _dioClient.get(ApiConfig.templates, queryParameters: queryParams);
      final templatesResponse = TemplatesResponse.fromJson(response.data as Map<String, dynamic>);

      for (final template in templatesResponse.templates) {
        await _db.templatesDao.upsert(templateToLocal(template));
      }

      return templatesResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  void _refreshMyTemplatesFromApi({TemplateCategory? category}) async {
    try {
      final queryParams = <String, dynamic>{'page': 1, 'page_size': 100};
      if (category != null) queryParams['category'] = category.apiValue;
      final response = await _dioClient.get(ApiConfig.templates, queryParameters: queryParams);
      final templatesResponse = TemplatesResponse.fromJson(response.data as Map<String, dynamic>);
      for (final template in templatesResponse.templates) {
        final existing = await _db.templatesDao.getById(template.id);
        if (existing == null || !existing.isDirty) {
          await _db.templatesDao.upsert(templateToLocal(template));
        }
      }
    } catch (e) {
      AppLogger.warning('Background template refresh failed: $e');
    }
  }

  Future<TemplatesResponse> _fetchPublicTemplatesFromApi({
    int page = 1,
    int pageSize = 20,
    TemplateCategory? category,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page, 'page_size': pageSize};
      if (category != null) queryParams['category'] = category.apiValue;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _dioClient.get(ApiConfig.publicTemplates, queryParameters: queryParams);
      final templatesResponse = TemplatesResponse.fromJson(response.data as Map<String, dynamic>);

      for (final template in templatesResponse.templates) {
        await _db.templatesDao.upsertPublic(templateToPublicCache(template));
      }

      return templatesResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  void _refreshPublicTemplatesFromApi({TemplateCategory? category, String? search}) async {
    try {
      final queryParams = <String, dynamic>{'page': 1, 'page_size': 100};
      if (category != null) queryParams['category'] = category.apiValue;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      final response = await _dioClient.get(ApiConfig.publicTemplates, queryParameters: queryParams);
      final templatesResponse = TemplatesResponse.fromJson(response.data as Map<String, dynamic>);
      for (final template in templatesResponse.templates) {
        await _db.templatesDao.upsertPublic(templateToPublicCache(template));
      }
    } catch (e) {
      AppLogger.warning('Background public template refresh failed: $e');
    }
  }

  void _refreshTemplateFromApi(String id) async {
    try {
      final response = await _dioClient.get(ApiConfig.templateDetail(id));
      final template = TripTemplateModel.fromJson(response.data as Map<String, dynamic>);
      final existing = await _db.templatesDao.getById(id);
      if (existing == null || !existing.isDirty) {
        await _db.templatesDao.upsert(templateToLocal(template));
      }
    } catch (e) {
      AppLogger.warning('Background template detail refresh failed: $e');
    }
  }

  String _handleError(DioException error) {
    if (error.response?.data != null && error.response!.data is Map) {
      final data = error.response!.data as Map<String, dynamic>;
      if (data.containsKey('detail')) return data['detail'].toString();
    }
    return error.error?.toString() ?? 'Operation failed';
  }
}
