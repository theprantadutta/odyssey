import '../services/connectivity_service.dart';
import '../session/account_session.dart';

/// Whether repositories should talk to the API right now.
///
/// Being online is not enough. A guest has a connection but no account, and
/// every request they made would go out without a token and come back 401 -
/// and the read paths that fetch when the local table is empty would surface
/// that as an error on a list that is simply, correctly, empty. Without a
/// session the local database is the whole truth.
class ApiAvailability {
  ApiAvailability._();

  static bool get canReachApi =>
      ConnectivityService().isOnline && AccountSession().isSignedIn;
}
