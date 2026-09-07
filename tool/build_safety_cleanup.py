from pathlib import Path

p = Path('lib/tz_build.dart')
s = p.read_text(encoding='utf-8')
s = s.replace("import 'package:flutter/services.dart';\n", '')
s = s.replace("      TextInput.finishAutofillContext(shouldSave: true);\n", '')
s = s.replace("TextInput.finishAutofillContext(shouldSave: true);\n", '')
p.write_text(s, encoding='utf-8')
print('Removed optional TextInput calls; autofillHints remain enabled.')
