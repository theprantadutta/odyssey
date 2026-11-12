/// Accounts used for testing, demos and store screenshots.
///
/// Signed into release builds on test devices, so their sessions land in
/// production analytics next to real users' - a screenshot session alone once
/// put more events into a day than the rest of the month. They are tagged with
/// the `internal_tester` user property so reports can leave them out (Analytics
/// → a comparison or filter on internal_tester ≠ true).
///
/// Add an account here when it starts being used for testing.
const Set<String> internalTesterEmails = {
  'realjohndoe276@gmail.com',
};

bool isInternalTester(String? email) =>
    email != null && internalTesterEmails.contains(email.trim().toLowerCase());
