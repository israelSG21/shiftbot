import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_pantalla.dart';

class AdminPantalla extends StatefulWidget {
  const AdminPantalla({super.key});

  @override
  State<AdminPantalla> createState() => _AdminPantallaState();
}

class _AdminPantallaState extends State<AdminPantalla> {
  final supabase = Supabase.instance.client;

  int _tabIndex = 0; // 0: Peticiones, 1: Ocupados
  bool _mostrarCubiculos = true;
  bool _cargando = false;

  List<Map<String, dynamic>> _reservas = [];

  @override
  void initState() {
    super.initState();
    _cargarReservas();
  }

  // Consulta todas las reservas con la información del espacio asignado
  Future<void> _cargarReservas() async {
    setState(() => _cargando = true);
    try {
      final List<dynamic> data = await supabase
          .from('reservas')
          .select('*, espacios(id, nombre, tipo)')
          .inFilter('estado', ['pendiente', 'activa'])
          .order('fecha_solicitud', ascending: false);

      if (mounted) {
        setState(() {
          _reservas = data.map((e) => Map<String, dynamic>.from(e)).toList();
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al consultar datos: $e')),
        );
      }
    }
  }

  // Aceptar la solicitud de reserva
  Future<void> _confirmarReserva(Map<String, dynamic> item) async {
    try {
      await supabase
          .from('reservas')
          .update({'estado': 'activa'})
          .eq('id', item['id']);

      await _cargarReservas();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Acceso autorizado a matrícula ${item['matricula_usuario']}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al autorizar: $e')),
        );
      }
    }
  }

  // Rechazar solicitud de reserva y liberar espacio
  Future<void> _denegarReserva(Map<String, dynamic> item) async {
    try {
      await supabase
          .from('reservas')
          .update({'estado': 'cancelada'})
          .eq('id', item['id']);

      final espacioId = item['espacios']?['id'] ?? item['espacio_id'];
      if (espacioId != null) {
        await supabase
            .from('espacios')
            .update({'disponible': true})
            .eq('id', espacioId);
      }

      await _cargarReservas();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud denegada y espacio liberado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al denegar: $e')),
        );
      }
    }
  }

  // Finalizar el uso del espacio y liberarlo
  Future<void> _liberarEspacio(Map<String, dynamic> item) async {
    try {
      await supabase
          .from('reservas')
          .update({'estado': 'finalizada'})
          .eq('id', item['id']);

      final espacioId = item['espacios']?['id'] ?? item['espacio_id'];
      if (espacioId != null) {
        await supabase
            .from('espacios')
            .update({'disponible': true})
            .eq('id', espacioId);
      }

      await _cargarReservas();

      if (mounted) {
        final nombreEspacio = item['espacios']?['nombre'] ?? 'Espacio';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$nombreEspacio liberado con éxito')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al liberar espacio: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tipoFiltro = _mostrarCubiculos ? 'cubiculo' : 'sala';
    final estadoFiltro = _tabIndex == 0 ? 'pendiente' : 'activa';

    final lista = _reservas.where((e) {
      final tipoEspacio = e['espacios']?['tipo'];
      final estado = e['estado'];
      return tipoEspacio == tipoFiltro && estado == estadoFiltro;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_tabIndex == 0 ? 'Peticiones pendientes' : 'Espacios en uso'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            tooltip: 'Actualizar',
            onPressed: _cargarReservas,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black54),
            tooltip: 'Cerrar sesión',
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginPantalla()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          // Segmented Switch estilo iOS institucional
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _mostrarCubiculos = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _mostrarCubiculos ? const Color(0xFF004A99) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Cubículos',
                          style: TextStyle(
                            color: _mostrarCubiculos ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _mostrarCubiculos = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: !_mostrarCubiculos ? const Color(0xFF004A99) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Sala',
                          style: TextStyle(
                            color: !_mostrarCubiculos ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : lista.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 54, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text('No hay solicitudes en esta sección', style: TextStyle(color: Colors.black54)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: lista.length,
                        itemBuilder: (context, index) {
                          final item = lista[index];
                          final nombreEspacio = item['espacios']?['nombre'] ?? 'Sin asignar';
                          final matricula = item['matricula_usuario'] ?? 'N/A';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2))
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const CircleAvatar(
                                          radius: 18,
                                          backgroundColor: Color(0xFFE8F1FA),
                                          child: Icon(Icons.person, size: 20, color: Color(0xFF004A99)),
                                        ),
                                        const SizedBox(width: 10),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Matrícula $matricula', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                            Text(
                                              _tabIndex == 0 ? 'Pendiente' : 'Activo ahora',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: _tabIndex == 0 ? Colors.orange.shade700 : Colors.green.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F1FA),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        nombreEspacio,
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004A99), fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                if (_tabIndex == 0)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF004A99),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            elevation: 0,
                                          ),
                                          onPressed: () => _confirmarReserva(item),
                                          child: const Text('Confirmar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Colors.black26),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          onPressed: () => _denegarReserva(item),
                                          child: const Text('Denegar', style: TextStyle(color: Colors.black87)),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Colors.redAccent),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      icon: const Icon(Icons.lock_open, color: Colors.redAccent, size: 18),
                                      label: const Text('Liberar espacio', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                      onPressed: () => _liberarEspacio(item),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        selectedItemColor: const Color(0xFF004A99),
        onTap: (index) => setState(() => _tabIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.hourglass_top_rounded), label: 'Peticiones'),
          BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), label: 'En uso'),
        ],
      ),
    );
  }
}