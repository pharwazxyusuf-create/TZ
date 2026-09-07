from pathlib import Path

p = Path('lib/tz_build.dart')
s = p.read_text(encoding='utf-8')
s = s.replace(
    'UserAttributes(password: next.text, currentPassword: current.text)',
    'UserAttributes(password: next.text)',
)
p.write_text(s, encoding='utf-8')
print('Applied auth compatibility fix for the current Supabase Flutter SDK.')
