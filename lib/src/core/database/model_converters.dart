import 'dart:convert';

import 'package:drift/drift.dart';

import 'app_database.dart';
import '../../features/trips/data/models/trip_model.dart';
import '../../features/activities/data/models/activity_model.dart';
import '../../features/expenses/data/models/expense_model.dart';
import '../../features/packing/data/models/packing_model.dart';
import '../../features/documents/data/models/document_model.dart';
import '../../features/documents/data/models/document_file_model.dart';
import '../../features/memories/data/models/memory_model.dart';
import '../../features/memories/data/models/memory_media_model.dart';

// ─── Trip ─────────────────────────────────────────────────────────

TripModel tripFromLocal(LocalTrip row) {
  return TripModel(
    id: row.id,
    userId: row.userId,
    title: row.title,
    description: row.description,
    coverImageUrl: row.coverImageUrl,
    startDate: row.startDate,
    endDate: row.endDate ?? '',
    status: row.status,
    tags: (jsonDecode(row.tags) as List).cast<String>(),
    budget: row.budget,
    displayCurrency: row.displayCurrency,
    createdAt: row.createdAt.toIso8601String(),
    updatedAt: row.updatedAt.toIso8601String(),
  );
}

LocalTripsCompanion tripToLocal(TripModel model, {bool isDirty = false, bool isLocalOnly = false}) {
  return LocalTripsCompanion(
    id: Value(model.id),
    userId: Value(model.userId),
    title: Value(model.title),
    description: Value(model.description),
    coverImageUrl: Value(model.coverImageUrl),
    startDate: Value(model.startDate),
    endDate: Value(model.endDate),
    status: Value(model.status),
    tags: Value(jsonEncode(model.tags ?? [])),
    budget: Value(model.budget),
    displayCurrency: Value(model.displayCurrency),
    createdAt: Value(DateTime.parse(model.createdAt)),
    updatedAt: Value(DateTime.parse(model.updatedAt)),
    isDirty: Value(isDirty),
    isLocalOnly: Value(isLocalOnly),
    isDeleted: const Value(false),
  );
}

// ─── Activity ─────────────────────────────────────────────────────

ActivityModel activityFromLocal(LocalActivity row) {
  return ActivityModel(
    id: row.id,
    tripId: row.tripId,
    title: row.title,
    description: row.description,
    scheduledTime: row.scheduledTime,
    category: row.category,
    sortOrder: row.sortOrder,
    latitude: row.latitude,
    longitude: row.longitude,
    createdAt: row.createdAt.toIso8601String(),
    updatedAt: row.updatedAt.toIso8601String(),
  );
}

LocalActivitiesCompanion activityToLocal(ActivityModel model, {bool isDirty = false, bool isLocalOnly = false}) {
  return LocalActivitiesCompanion(
    id: Value(model.id),
    tripId: Value(model.tripId),
    title: Value(model.title),
    description: Value(model.description),
    scheduledTime: Value(model.scheduledTime),
    category: Value(model.category),
    sortOrder: Value(model.sortOrder),
    latitude: Value(model.latitude),
    longitude: Value(model.longitude),
    createdAt: Value(DateTime.parse(model.createdAt)),
    updatedAt: Value(DateTime.parse(model.updatedAt)),
    isDirty: Value(isDirty),
    isLocalOnly: Value(isLocalOnly),
    isDeleted: const Value(false),
  );
}

// ─── Expense ──────────────────────────────────────────────────────

ExpenseModel expenseFromLocal(LocalExpense row) {
  return ExpenseModel(
    id: row.id,
    tripId: row.tripId,
    title: row.title,
    amount: row.amount,
    currency: row.currency,
    category: row.category,
    date: row.date,
    notes: row.notes,
    convertedAmount: row.convertedAmount,
    convertedCurrency: row.convertedCurrency,
    exchangeRate: row.exchangeRate,
    convertedAt: row.convertedAt,
    createdAt: row.createdAt.toIso8601String(),
    updatedAt: row.updatedAt.toIso8601String(),
  );
}

LocalExpensesCompanion expenseToLocal(ExpenseModel model, {bool isDirty = false, bool isLocalOnly = false}) {
  return LocalExpensesCompanion(
    id: Value(model.id),
    tripId: Value(model.tripId),
    title: Value(model.title),
    amount: Value(model.amount),
    currency: Value(model.currency),
    category: Value(model.category),
    date: Value(model.date),
    notes: Value(model.notes),
    convertedAmount: Value(model.convertedAmount),
    convertedCurrency: Value(model.convertedCurrency),
    exchangeRate: Value(model.exchangeRate),
    convertedAt: Value(model.convertedAt),
    createdAt: Value(DateTime.parse(model.createdAt)),
    updatedAt: Value(DateTime.parse(model.updatedAt)),
    isDirty: Value(isDirty),
    isLocalOnly: Value(isLocalOnly),
    isDeleted: const Value(false),
  );
}

// ─── PackingItem ──────────────────────────────────────────────────

PackingItemModel packingItemFromLocal(LocalPackingItem row) {
  return PackingItemModel(
    id: row.id,
    tripId: row.tripId,
    name: row.name,
    category: row.category,
    isPacked: row.isPacked,
    quantity: row.quantity,
    notes: row.notes,
    sortOrder: row.sortOrder,
    createdAt: row.createdAt.toIso8601String(),
    updatedAt: row.updatedAt.toIso8601String(),
  );
}

LocalPackingItemsCompanion packingItemToLocal(PackingItemModel model, {bool isDirty = false, bool isLocalOnly = false}) {
  return LocalPackingItemsCompanion(
    id: Value(model.id),
    tripId: Value(model.tripId),
    name: Value(model.name),
    category: Value(model.category),
    isPacked: Value(model.isPacked),
    quantity: Value(model.quantity),
    notes: Value(model.notes),
    sortOrder: Value(model.sortOrder),
    createdAt: Value(DateTime.parse(model.createdAt)),
    updatedAt: Value(DateTime.parse(model.updatedAt ?? DateTime.now().toIso8601String())),
    isDirty: Value(isDirty),
    isLocalOnly: Value(isLocalOnly),
    isDeleted: const Value(false),
  );
}

// ─── Document ─────────────────────────────────────────────────────

DocumentModel documentFromLocal(LocalDocument row) {
  final filesJson = jsonDecode(row.files) as List;
  final files = filesJson.map((f) => DocumentFileModel.fromJson(f as Map<String, dynamic>)).toList();

  return DocumentModel(
    id: row.id,
    tripId: row.tripId,
    type: row.type,
    name: row.name,
    files: files,
    fileUrl: row.fileUrl,
    fileType: row.fileType,
    notes: row.notes,
    createdAt: row.createdAt.toIso8601String(),
    updatedAt: row.updatedAt.toIso8601String(),
  );
}

LocalDocumentsCompanion documentToLocal(DocumentModel model, {bool isDirty = false, bool isLocalOnly = false}) {
  return LocalDocumentsCompanion(
    id: Value(model.id),
    tripId: Value(model.tripId),
    type: Value(model.type),
    name: Value(model.name),
    files: Value(jsonEncode(model.files.map((f) => f.toJson()).toList())),
    fileUrl: Value(model.fileUrl),
    fileType: Value(model.fileType),
    notes: Value(model.notes),
    createdAt: Value(DateTime.parse(model.createdAt)),
    updatedAt: Value(DateTime.parse(model.updatedAt ?? model.createdAt)),
    isDirty: Value(isDirty),
    isLocalOnly: Value(isLocalOnly),
    isDeleted: const Value(false),
  );
}

// ─── Memory ───────────────────────────────────────────────────────

MemoryModel memoryFromLocal(LocalMemory row) {
  final mediaJson = jsonDecode(row.mediaItems) as List;
  final mediaItems = mediaJson.map((m) => MemoryMediaModel.fromJson(m as Map<String, dynamic>)).toList();

  return MemoryModel(
    id: row.id,
    tripId: row.tripId,
    mediaItems: mediaItems,
    photoUrl: row.photoUrl,
    location: row.location,
    latitude: row.latitude,
    longitude: row.longitude,
    caption: row.caption,
    takenAt: row.takenAt,
    createdAt: row.createdAt.toIso8601String(),
  );
}
