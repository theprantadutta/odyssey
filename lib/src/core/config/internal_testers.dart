/// Accounts used for testing, demos and store screenshots.
///
/// Signed into release builds on test devices, so their sessions land in
/// production analytics next to real users' - a screenshot session alone once
/// put more events into a day than the rest of the month. They are tagged with
/// the `internal_tester` user property so reports can leave them out (Analytics
/// → a comparison or filter on internal_tester ≠ true).
///
/// Installs are tagged too, independently of the account: at startup
/// install_source_tagger.dart sets `install_source` to the installer package
/// (`com.android.vending` = Google Play, `com.apple` = App Store,
/// `com.apple.testflight`, `com.android.shell` / `none` = adb sideload, ...)
/// and sets `internal_tester` = 'true' for every non-store install and every
/// debug/profile build. It only ever sets 'true', never clears it. To keep
/// real users only, filter on internal_tester ≠ true, or on
/// install_source = com.android.vending for Play installs. Both are custom
/// user properties, so they must be registered as user-scoped custom
/// dimensions in GA before standard reports can filter on them.
///
/// Add an account here when it starts being used for testing.
const Set<String> internalTesterEmails = {
  'realjohndoe276@gmail.com',
};

bool isInternalTester(String? email) =>
    email != null && internalTesterEmails.contains(email.trim().toLowerCase());
