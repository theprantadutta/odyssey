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
import '../../features/templates/data/models/template_model.dart';
import '../../features/sharing/data/models/trip_share_model.dart';
import '../../features/achievements/data/models/achievement_model.dart';

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

// ─── Template ────────────────────────────────────────────────────

TripTemplateModel templateFromLocal(LocalTemplate row) {
  return TripTemplateModel(
    id: row.id,
    userId: row.userId,
    name: row.name,
    description: row.description,
    structure: TemplateStructure.fromJson(
      jsonDecode(row.structureJson) as Map<String, dynamic>,
    ),
    isPublic: row.isPublic,
    category: row.category != null ? TemplateCategory.fromString(row.category!) : null,
    useCount: row.useCount,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}

LocalTemplatesCompanion templateToLocal(TripTemplateModel model, {bool isDirty = false, bool isLocalOnly = false}) {
  return LocalTemplatesCompanion(
    id: Value(model.id),
    userId: Value(model.userId),
    name: Value(model.name),
    description: Value(model.description),
    structureJson: Value(jsonEncode(model.structure.toJson())),
    isPublic: Value(model.isPublic),
    category: Value(model.category?.apiValue),
    useCount: Value(model.useCount),
    createdAt: Value(model.createdAt),
    updatedAt: Value(model.updatedAt ?? DateTime.now()),
    isDirty: Value(isDirty),
    isLocalOnly: Value(isLocalOnly),
    isDeleted: const Value(false),
  );
}

TripTemplateModel templateFromPublicCache(LocalPublicTemplate row) {
  return TripTemplateModel(
    id: row.id,
    userId: row.userId,
    name: row.name,
    description: row.description,
    structure: TemplateStructure.fromJson(
      jsonDecode(row.structureJson) as Map<String, dynamic>,
    ),
    isPublic: row.isPublic,
    category: row.category != null ? TemplateCategory.fromString(row.category!) : null,
    useCount: row.useCount,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}

LocalPublicTemplatesCompanion templateToPublicCache(TripTemplateModel model) {
  return LocalPublicTemplatesCompanion(
    id: Value(model.id),
    userId: Value(model.userId),
    name: Value(model.name),
    description: Value(model.description),
    structureJson: Value(jsonEncode(model.structure.toJson())),
    isPublic: Value(model.isPublic),
    category: Value(model.category?.apiValue),
    useCount: Value(model.useCount),
    createdAt: Value(model.createdAt),
    updatedAt: Value(model.updatedAt ?? DateTime.now()),
    cachedAt: Value(DateTime.now()),
  );
}

// ─── Sharing ─────────────────────────────────────────────────────

TripShareModel tripShareFromLocal(LocalTripShare row) {
  return TripShareModel(
    id: row.id,
    tripId: row.tripId,
    ownerId: row.ownerId,
    sharedWithEmail: row.sharedWithEmail,
    sharedWithUserId: row.sharedWithUserId,
    permission: SharePermission.fromString(row.permission),
    inviteCode: row.inviteCode,
    inviteExpiresAt: row.inviteExpiresAt != null ? DateTime.parse(row.inviteExpiresAt!) : null,
    status: ShareStatus.fromString(row.status),
    createdAt: row.createdAt,
    acceptedAt: row.acceptedAt != null ? DateTime.parse(row.acceptedAt!) : null,
  );
}

LocalTripSharesCompanion tripShareToLocal(TripShareModel model, {bool isDirty = false, bool isLocalOnly = false}) {
  return LocalTripSharesCompanion(
    id: Value(model.id),
    tripId: Value(model.tripId),
    ownerId: Value(model.ownerId),
    sharedWithEmail: Value(model.sharedWithEmail),
    sharedWithUserId: Value(model.sharedWithUserId),
    permission: Value(model.permission.name),
    inviteCode: Value(model.inviteCode),
    status: Value(model.status.name),
    createdAt: Value(model.createdAt),
    acceptedAt: Value(model.acceptedAt?.toIso8601String()),
    inviteExpiresAt: Value(model.inviteExpiresAt?.toIso8601String()),
    isDirty: Value(isDirty),
    isLocalOnly: Value(isLocalOnly),
    isDeleted: const Value(false),
  );
}

SharedTripInfo sharedTripFromLocal(LocalSharedTrip row) {
  return SharedTripInfo(
    tripId: row.id,
    title: row.title,
    description: row.description,
    coverImageUrl: row.coverImageUrl,
    startDate: DateTime.parse(row.startDate),
    endDate: row.endDate != null ? DateTime.parse(row.endDate!) : null,
    status: row.status,
    ownerEmail: row.ownerEmail,
    permission: SharePermission.fromString(row.permission),
    sharedAt: DateTime.parse(row.sharedAt),
  );
}

LocalSharedTripsCompanion sharedTripToLocal(SharedTripInfo model) {
  return LocalSharedTripsCompanion(
    id: Value(model.tripId),
    title: Value(model.title),
    description: Value(model.description),
    coverImageUrl: Value(model.coverImageUrl),
    startDate: Value(model.startDate.toIso8601String()),
    endDate: Value(model.endDate?.toIso8601String()),
    status: Value(model.status),
    ownerEmail: Value(model.ownerEmail),
    permission: Value(model.permission.name),
    sharedAt: Value(model.sharedAt.toIso8601String()),
    cachedAt: Value(DateTime.now()),
  );
}

// ─── Achievements ────────────────────────────────────────────────

Achievement achievementFromLocal(LocalAchievement row) {
  return Achievement(
    id: row.id,
    type: row.type,
    name: row.name,
    description: row.description,
    icon: row.icon,
    category: row.category,
    threshold: row.threshold,
    tier: row.tier,
    points: row.points,
    isActive: row.isActive,
    sortOrder: row.sortOrder,
  );
}

LocalAchievementsCompanion achievementToLocal(Achievement model) {
  return LocalAchievementsCompanion(
    id: Value(model.id),
    type: Value(model.type),
    name: Value(model.name),
    description: Value(model.description),
    icon: Value(model.icon),
    category: Value(model.category),
    threshold: Value(model.threshold),
    tier: Value(model.tier),
    points: Value(model.points),
    isActive: Value(model.isActive),
    sortOrder: Value(model.sortOrder),
    cachedAt: Value(DateTime.now()),
  );
}

UserAchievement userAchievementFromLocal(LocalUserAchievement row) {
  final achievementData = jsonDecode(row.achievementJson) as Map<String, dynamic>;
  return UserAchievement(
    id: row.id,
    achievementId: row.achievementId,
    progress: row.progress,
    earnedAt: row.earnedAt != null ? DateTime.parse(row.earnedAt!) : null,
    seen: row.seen,
    achievement: Achievement.fromJson(achievementData),
  );
}

LocalUserAchievementsCompanion userAchievementToLocal(UserAchievement model) {
  return LocalUserAchievementsCompanion(
    id: Value(model.id),
    achievementId: Value(model.achievementId),
    progress: Value(model.progress),
    earnedAt: Value(model.earnedAt?.toIso8601String()),
    seen: Value(model.seen),
    achievementJson: Value(jsonEncode(model.achievement.toJson())),
    cachedAt: Value(DateTime.now()),
  );
}
