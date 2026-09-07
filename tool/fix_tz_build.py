from pathlib import Path

p = Path('lib/tz_build.dart')
s = p.read_text(encoding='utf-8')

# Supabase Flutter 2 uses publishableKey for the client key.
s = s.replace('Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey)', 'Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey)')

# The legacy StockPage was compressed into a malformed final line. Replace the
# entire legacy section with a parser-safe implementation.
marker = 'class StockPage extends StatelessWidget {'
if marker in s:
    s = s[:s.index(marker)] + '''class StockPage extends StatelessWidget {
  const StockPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: db.from('products').select('id,name,price,central_stock').order('name'),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Unable to load stock: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = List<Map<String, dynamic>>.from(snapshot.data!);
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            const Text(
              'Central Stock',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: navy),
            ),
            const SizedBox(height: 10),
            for (final product in rows)
              Card(
                child: ListTile(
                  title: Text(
                    '${product['name'] ?? 'Product'}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text('Selling price: ₦${product['price'] ?? 0}'),
                  trailing: Text(
                    '${product['central_stock'] ?? 0}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
'''

p.write_text(s, encoding='utf-8')
print('TZ build source repaired.')
