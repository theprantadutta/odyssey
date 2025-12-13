import 'package:odyssey/src/core/network/dio_client.dart';
import 'package:odyssey/src/features/templates/data/models/template_model.dart';

class TemplateRepository {
  final DioClient _dioClient = DioClient();

  /// Get user's templates
  Future<TemplatesResponse> getMyTemplates({
    int page = 1,
    int pageSize = 20,
    TemplateCategory? category,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (category != null) {
      queryParams['category'] = category.apiValue;
    }

    final response = await _dioClient.get(
      '/templates',
      queryParameters: queryParams,
    );
    return TemplatesResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get public templates (gallery)
  Future<TemplatesResponse> getPublicTemplates({
    int page = 1,
    int pageSize = 20,
    TemplateCategory? category,
    String? search,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (category != null) {
      queryParams['category'] = category.apiValue;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final response = await _dioClient.get(
      '/templates/public',
      queryParameters: queryParams,
    );
    return TemplatesResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get template by ID
  Future<TripTemplateModel> getTemplate(String templateId) async {
    final response = await _dioClient.get('/templates/$templateId');
    return TripTemplateModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Create a new template
  Future<TripTemplateModel> createTemplate(TemplateCreateRequest request) async {
    final response = await _dioClient.post(
      '/templates',
      data: request.toJson(),
    );
    return TripTemplateModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Create template from existing trip
  Future<TripTemplateModel> createTemplateFromTrip(
    TemplateFromTripRequest request,
  ) async {
    final response = await _dioClient.post(
      '/templates/from-trip',
      data: request.toJson(),
    );
    return TripTemplateModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Update a template
  Future<TripTemplateModel> updateTemplate(
    String templateId,
    Map<String, dynamic> updates,
  ) async {
    final response = await _dioClient.patch(
      '/templates/$templateId',
      data: updates,
    );
    return TripTemplateModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Delete a template
  Future<void> deleteTemplate(String templateId) async {
    await _dioClient.delete('/templates/$templateId');
  }

  /// Create trip from template
  Future<Map<String, dynamic>> useTemplate(
    String templateId,
    TripFromTemplateRequest request,
  ) async {
    final response = await _dioClient.post(
      '/templates/use/$templateId',
      data: request.toJson(),
    );
    return response.data as Map<String, dynamic>;
  }

  /// Get available categories
  Future<List<CategoryInfo>> getCategories() async {
    final response = await _dioClient.get('/templates/categories');
    return (response.data as List<dynamic>)
        .map((e) => CategoryInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
