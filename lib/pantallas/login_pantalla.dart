import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'estudiante_pantalla.dart';
import 'admin_pantalla.dart';

class LoginPantalla extends StatefulWidget {
  const LoginPantalla({super.key});

  @override
  State<LoginPantalla> createState() => _LoginPantallaState();
}

class _LoginPantallaState extends State<LoginPantalla> {
  final TextEditingController _matriculaController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _cargando = false;
  String _rolSeleccionado = 'estudiante'; // 'estudiante' o 'empleado'

  final supabase = Supabase.instance.client;

  Future<void> _iniciarSesion() async {
    final matricula = _matriculaController.text.trim();
    final password = _passwordController.text.trim();

    if (matricula.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      // Consulta a la tabla usuarios filtrando por matrícula, contraseña y rol seleccionado
      final respuesta = await supabase
          .from('usuarios')
          .select()
          .eq('matricula', matricula)
          .eq('contrasena', password)
          .eq('rol', _rolSeleccionado)
          .maybeSingle();

      setState(() => _cargando = false);

      if (respuesta == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Datos incorrectos o no registrado como $_rolSeleccionado'),
            backgroundColor: Colors.redAccent,
          ),
        );
      } else {
        final nombre = respuesta['nombre'] ?? 'Usuario';

        if (!mounted) return;

        if (_rolSeleccionado == 'estudiante') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => EstudiantePantalla(
                matricula: matricula,
                nombre: nombre,
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminPantalla()),
          );
        }
      }
    } catch (e) {
      setState(() => _cargando = false);
      // Muestra el detalle exacto en consola para saber si la base de datos respondió
      debugPrint('Error de autenticacion Supabase: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al conectar con Supabase: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF004A99),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF004A99).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.local_library_rounded, size: 54, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text(
                'ShiftBot',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF004A99),
                ),
              ),
              const Text(
                'Sistema de Biblioteca FIME',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 28),

              // Selector de Rol (Estudiante / Empleado)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _rolSeleccionado = 'estudiante'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _rolSeleccionado == 'estudiante' ? const Color(0xFF004A99) : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Estudiante',
                            style: TextStyle(
                              color: _rolSeleccionado == 'estudiante' ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _rolSeleccionado = 'empleado'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _rolSeleccionado == 'empleado' ? const Color(0xFF004A99) : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Empleado',
                            style: TextStyle(
                              color: _rolSeleccionado == 'empleado' ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Tarjeta de Formulario
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _matriculaController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Matrícula',
                        prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF004A99)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF004A99)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF004A99),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: _cargando ? null : _iniciarSesion,
                        child: _cargando
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Iniciar sesión',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}