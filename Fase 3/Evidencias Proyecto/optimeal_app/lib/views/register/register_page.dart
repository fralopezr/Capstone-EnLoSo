// lib/views/register/register_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../scan/widgets/optimeal_logo_title.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  int? _selectedPreference;

  bool _loading = false;
  bool _obscure = true;

  // Mapeo (label y value)
  final List<Map<String, dynamic>> _preferences = [
    {'label': 'Alta en proteínas', 'value': 1},
    {'label': 'Baja en calorías', 'value': 2},
    {'label': 'Alta en calcio', 'value': 3},
    {'label': 'Equilibrada', 'value': 4},
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPreference == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona una preferencia')));
      return;
    }

    setState(() => _loading = true);
    try {
      final authProv = context.read<AuthProvider>();
      final resp = await authProv.register(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        nombreUsuario: _nameCtrl.text.trim(),
        codigoPreferencia: _selectedPreference!,
        codigoRol: 2,
      );

      if (resp['ok'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Registro exitoso')));
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        final err = resp['error'] ?? resp;
        String msg = 'Error al registrar';
        try {
          if (err is Map && err['message'] != null)
            msg = err['message'].toString();
          else if (err is String) msg = err;
        } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(12);

    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const Icon(Icons.person_add_alt_1_outlined, size: 72),
                const SizedBox(height: 12),
                Text(
                  'Regístrate en OptiMeal',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),

                // Nombre
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: const Icon(Icons.person_outline),
                    filled: true,
                    fillColor: cs.surface.withOpacity(0.6),
                    border: OutlineInputBorder(borderRadius: radius),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ingresa tu nombre'
                      : null,
                ),
                const SizedBox(height: 12),

                // Correo
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: const Icon(Icons.alternate_email),
                    filled: true,
                    fillColor: cs.surface.withOpacity(0.6),
                    border: OutlineInputBorder(borderRadius: radius),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Ingresa tu correo';
                    if (!v.contains('@')) return 'Correo no válido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Contraseña
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    filled: true,
                    fillColor: cs.surface.withOpacity(0.6),
                    border: OutlineInputBorder(borderRadius: radius),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Debe tener al menos 6 caracteres'
                      : null,
                ),
                const SizedBox(height: 12),

                // Preferencia nutricional -> ahora con int values
                DropdownButtonFormField<int>(
                  decoration: InputDecoration(
                    labelText: 'Preferencia nutricional',
                    prefixIcon: const Icon(Icons.favorite_outline),
                    filled: true,
                    fillColor: cs.surface.withOpacity(0.6),
                    border: OutlineInputBorder(borderRadius: radius),
                  ),
                  value: _selectedPreference,
                  items: _preferences
                      .map((pref) => DropdownMenuItem(
                            value: pref['value'] as int,
                            child: Text(pref['label'] as String),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedPreference = value),
                  validator: (v) =>
                      (v == null) ? 'Selecciona una preferencia' : null,
                ),
                const SizedBox(height: 24),

                // Botón registrar
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.app_registration),
                    label: Text(_loading ? 'Registrando...' : 'Crear cuenta'),
                    onPressed: _loading ? null : _handleRegister,
                  ),
                ),
                const SizedBox(height: 16),

                TextButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/login'),
                  child: const Text('¿Ya tienes cuenta? Inicia sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
