import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:odyssey/src/features/sharing/data/models/trip_share_model.dart';
import 'package:odyssey/src/features/sharing/data/repositories/sharing_repository.dart';

part 'sharing_provider.g.dart';

/// Repository provider
@riverpod
SharingRepository sharingRepository(Ref ref) {
  return SharingRepository();
}

/// State for trip shares
class TripSharesState {
  final List<TripShareModel> shares;
  final bool isLoading;
  final String? error;
  final int total;

  const TripSharesState({
    this.shares = const [],
    this.isLoading = false,
    this.error,
    this.total = 0,
  });

  TripSharesState copyWith({
    List<TripShareModel>? shares,
    bool? isLoading,
    String? error,
    int? total,
  }) {
    return TripSharesState(
      shares: shares ?? this.shares,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      total: total ?? this.total,
    );
  }

  List<TripShareModel> get pendingShares =>
      shares.where((s) => s.status == ShareStatus.pending).toList();

  List<TripShareModel> get acceptedShares =>
      shares.where((s) => s.status == ShareStatus.accepted).toList();

  List<TripShareModel> get declinedShares =>
      shares.where((s) => s.status == ShareStatus.declined).toList();
}

/// Notifier for trip shares
@riverpod
class TripShares extends _$TripShares {
  @override
  TripSharesState build(String tripId) {
    _loadShares();
    return const TripSharesState(isLoading: true);
  }

  Future<void> _loadShares() async {
    try {
      final repository = ref.read(sharingRepositoryProvider);
      final response = await repository.getTripShares(tripId);
      state = state.copyWith(
        shares: response.shares,
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
    await _loadShares();
  }

  Future<TripShareModel?> shareTrip(TripShareRequest request) async {
    try {
      final repository = ref.read(sharingRepositoryProvider);
      final share = await repository.shareTrip(tripId, request);
      state = state.copyWith(
        shares: [...state.shares, share],
        total: state.total + 1,
      );
      return share;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<bool> updatePermission(
    String shareId,
    SharePermission permission,
  ) async {
    try {
      final repository = ref.read(sharingRepositoryProvider);
      final updatedShare = await repository.updateSharePermission(
        tripId,
        shareId,
        permission,
      );
      state = state.copyWith(
        shares: state.shares.map((s) {
          if (s.id == shareId) return updatedShare;
          return s;
        }).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> revokeShare(String shareId) async {
    try {
      final repository = ref.read(sharingRepositoryProvider);
      await repository.revokeShare(tripId, shareId);
      state = state.copyWith(
        shares: state.shares.where((s) => s.id != shareId).toList(),
        total: state.total - 1,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

/// State for shared trips (trips shared with current user)
class SharedTripsState {
  final List<SharedTripInfo> trips;
  final bool isLoading;
  final String? error;
  final int total;

  const SharedTripsState({
    this.trips = const [],
    this.isLoading = false,
    this.error,
    this.total = 0,
  });

  SharedTripsState copyWith({
    List<SharedTripInfo>? trips,
    bool? isLoading,
    String? error,
    int? total,
  }) {
    return SharedTripsState(
      trips: trips ?? this.trips,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      total: total ?? this.total,
    );
  }
}

/// Notifier for trips shared with current user
@riverpod
class SharedTrips extends _$SharedTrips {
  @override
  SharedTripsState build() {
    _loadSharedTrips();
    return const SharedTripsState(isLoading: true);
  }

  Future<void> _loadSharedTrips() async {
    try {
      final repository = ref.read(sharingRepositoryProvider);
      final response = await repository.getSharedTrips();
      state = state.copyWith(
        trips: response.trips,
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
    await _loadSharedTrips();
  }
}

/// State for invite details
class InviteState {
  final InviteDetailsModel? invite;
  final bool isLoading;
  final String? error;
  final bool isAccepting;
  final bool isDeclining;

  const InviteState({
    this.invite,
    this.isLoading = false,
    this.error,
    this.isAccepting = false,
    this.isDeclining = false,
  });

  InviteState copyWith({
    InviteDetailsModel? invite,
    bool? isLoading,
    String? error,
    bool? isAccepting,
    bool? isDeclining,
  }) {
    return InviteState(
      invite: invite ?? this.invite,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAccepting: isAccepting ?? this.isAccepting,
      isDeclining: isDeclining ?? this.isDeclining,
    );
  }
}

/// Notifier for invite operations
@riverpod
class Invite extends _$Invite {
  @override
  InviteState build(String inviteCode) {
    _loadInvite();
    return const InviteState(isLoading: true);
  }

  Future<void> _loadInvite() async {
    try {
      final repository = ref.read(sharingRepositoryProvider);
      final invite = await repository.getInviteDetails(inviteCode);
      state = state.copyWith(
        invite: invite,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<AcceptInviteResponse?> acceptInvite() async {
    state = state.copyWith(isAccepting: true, error: null);
    try {
      final repository = ref.read(sharingRepositoryProvider);
      final response = await repository.acceptInvite(inviteCode);
      state = state.copyWith(isAccepting: false);
      // Refresh shared trips list
      ref.invalidate(sharedTripsProvider);
      return response;
    } catch (e) {
      state = state.copyWith(
        isAccepting: false,
        error: e.toString(),
      );
      return null;
    }
  }

  Future<bool> declineInvite() async {
    state = state.copyWith(isDeclining: true, error: null);
    try {
      final repository = ref.read(sharingRepositoryProvider);
      await repository.declineInvite(inviteCode);
      state = state.copyWith(isDeclining: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isDeclining: false,
        error: e.toString(),
      );
      return false;
    }
  }
}
