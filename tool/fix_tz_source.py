from pathlib import Path

p = Path('lib/tz_production.dart')
s = p.read_text(encoding='utf-8')
# Fix the Login widget's constructor message reference inside _LoginState.build.
s = s.replace("if(message!=null)", "if(widget.message!=null)")
s = s.replace("Text(message!,textAlign", "Text(widget.message!,textAlign")
# Use Supabase's current publishable-key initializer name.
s = s.replace("Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey)", "Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey)")
p.write_text(s, encoding='utf-8')
print('TZ source fixes applied.')
