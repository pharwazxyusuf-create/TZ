from pathlib import Path

p = Path('lib/tz_build.dart')
s = p.read_text(encoding='utf-8')
s = s.replace(
    'Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey)',
    'Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey)',
    1,
)
p.write_text(s, encoding='utf-8')
print('Finalized Supabase publishable-key initialization only; auth UI is handled by restore_auth_ui.py.')
