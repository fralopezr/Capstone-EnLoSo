// lib/views/login_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'scan/widgets/optimeal_logo_title.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final authProv = context.read<AuthProvider>();
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text;

      final resp = await authProv.login(email: email, password: password);
      if (resp['ok'] == true) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
        return;
      } else {
        final err = resp['error'] ?? resp;
        String msg = 'Credenciales inválidas';
        try {
          if (err is Map && err['message'] != null) {
            msg = err['message'].toString();
          } else if (err is String) {
            msg = err;
          }
        } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e, st) {
      debugPrint('Exception en login flow: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error inesperado: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(12);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 120,
                    child: Center(
                      child: OptimealLogoTitle(
                        showText: false, // solo ícono grande
                        logoSize: 80,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ingresa a OptiMeal',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Correo',
                            hintText: 'tucorreo@dominio.com',
                            prefixIcon: const Icon(Icons.alternate_email),
                            filled: true,
                            fillColor: cs.surface.withOpacity(0.6),
                            border: OutlineInputBorder(borderRadius: radius),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: radius,
                              borderSide: BorderSide(color: cs.outlineVariant),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Ingresa tu correo';
                            }
                            if (!v.contains('@')) return 'Correo no válido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                            ),
                            filled: true,
                            fillColor: cs.surface.withOpacity(0.6),
                            border: OutlineInputBorder(borderRadius: radius),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: radius,
                              borderSide: BorderSide(color: cs.outlineVariant),
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Ingresa tu contraseña'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            icon: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: Text(
                              _loading ? 'Ingresando...' : 'Ingresar',
                            ),
                            onPressed: _loading ? null : _handleLogin,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('¿No tienes cuenta? Regístrate'),
                          onPressed: () =>
                              Navigator.pushNamed(context, '/register'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
