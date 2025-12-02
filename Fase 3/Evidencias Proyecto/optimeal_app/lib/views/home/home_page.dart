// lib/views/home/home_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/historial_service.dart';
import '../../config.dart';
import '../scan/scan_form_page.dart';
import '../historial/historial_page.dart';
import '../scan/widgets/optimeal_logo_title.dart'; // 👈 ya lo tenías

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentPageIndex = 1; // Home al centro
  late final HistorialService historialService;

  @override
  void initState() {
    super.initState();
    historialService = HistorialService(baseUrl: API_BASE_LOCAL);
  }

  // Helper SOLO para capitalizar nombre, marca y categoría
  String _toTitleCase(String? input) {
    if (input == null) return '';
    final trimmed = input.trim().toLowerCase();
    if (trimmed.isEmpty) return '';

    return trimmed
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  String _fmtFechaDMYHM(dynamic v) {
    if (v == null) return '-';
    try {
      final dt = v is DateTime ? v : DateTime.parse(v.toString());
      final l = dt.toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      final dd = two(l.day);
      final mm = two(l.month);
      final yyyy = l.year.toString();
      final hh = two(l.hour);
      final min = two(l.minute);
      return '$dd-$mm-$yyyy $hh:$min';
    } catch (_) {
      return v.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProv = context.watch<AuthProvider>();
    final nombreUsuario = authProv.user?['user_metadata']?['name'] ?? 'Usuario';
    final theme = Theme.of(context);
    final userId = authProv.user?['id'];

    final List<Widget> pages = [
      // 0 - Scanner
      const ScanFormPage(),

      // 1 - Home principal con último producto real del historial
      userId == null
          ? const Center(child: Text('No hay usuario autenticado'))
          : FutureBuilder<List<Map<String, dynamic>>>(
              future: historialService.obtenerHistorialPorUsuario(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error al cargar historial'));
                }
                if (snapshot.data == null || snapshot.data!.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          nombreUsuario,
                          style: theme.textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          'Último escaneo',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'Aún no has escaneado productos.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  );
                }

                // Primer item es el más reciente
                final item = snapshot.data!.first;

                final nombre = _toTitleCase(
                  item['nombre']?.toString() ?? 'Nombre desconocido',
                );
                final marca = _toTitleCase(
                  item['marca']?.toString() ?? 'Marca desconocida',
                );
                final categoria = _toTitleCase(
                  item['nombre_categoria']?.toString() ?? '-',
                );

                final kcal = item['energia_kcal']?.toString() ?? '-';
                final proteinas = item['proteinas_g']?.toString() ?? '-';
                final grasas = item['grasa_total_g']?.toString() ?? '-';
                final fechaFmt = _fmtFechaDMYHM(item['fecha_creacion']);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        nombreUsuario,
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Último escaneo',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            margin: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                              vertical: 12,
                            ),
                            child: Container(
                              width: 380,
                              padding: const EdgeInsets.symmetric(
                                vertical: 32,
                                horizontal: 32,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 18),
                                  Text(
                                    nombre,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    marca,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(color: Colors.grey[700]),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Categoría: $categoria',
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 16),
                                  const Divider(),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Column(
                                        children: [
                                          const Text(
                                            'Kcal',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text('$kcal'),
                                        ],
                                      ),
                                      Column(
                                        children: [
                                          const Text(
                                            'Proteínas',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text('$proteinas g'),
                                        ],
                                      ),
                                      Column(
                                        children: [
                                            const Text(
                                              'Grasas',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text('$grasas g'),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    'Escaneado el: $fechaFmt',
                                    style: theme.textTheme.labelSmall
                                        ?.copyWith(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),

      // 2 - Historial
      HistorialPage(idUsuario: userId),

      // 3 - Ranking (placeholder)
      Center(
        child: Text(
          'Ranking de productos',
          style: theme.textTheme.titleLarge,
        ),
      ),
    ];

    return Scaffold(
      appBar: currentPageIndex == 1
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Ajustes',
                onPressed: () {
                  // Navega a ajustes si corresponde
                },
              ),
              title: const OptimealLogoTitle(
                showText: true,
                logoSize: 26,
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.trending_up),
                  tooltip: 'Ranking',
                  onPressed: () {
                    // Navega a ranking si corresponde
                    // Navigator.pushNamed(context, '/ranking');
                  },
                ),
              ],
            )
          : null,
      body: pages[currentPageIndex],
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        selectedIndex: currentPageIndex,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scanner',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.home),
            icon: Icon(Icons.home_outlined),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'Historial',
          ),
        ],
      ),
    );
  }
}
