/// Supabase project the app talks to. Defaults to the team project; override
/// per build with `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...`.
///
/// The publishable key is safe to ship in the client: row-level
/// security policies in the database enforce per-user access.
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://wlopsesyhmfcuwxoesja.supabase.co',
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_ndv-zBK_q2aI9s1XqY5u-w_Khm2m-zo',
  );
}
