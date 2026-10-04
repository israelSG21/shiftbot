import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_pantalla.dart';

class EstudiantePantalla extends StatefulWidget {
  final String matricula;
  final String nombre;

  const EstudiantePantalla({
    super.key,
    required this.matricula,
    required this.nombre,
  });

  @override
  State<EstudiantePantalla> createState() => _EstudiantePantallaState();
}

class _EstudiantePantallaState extends State<EstudiantePantalla> {
  final supabase = Supabase.instance.client;

  int _tabIndex = 0; // 0: Reservar, 1: Mi Reserva
  int _vistaActual = 0; // 0: Menú principal, 1: Lista cubículos, 2: Detalle cubículo, 3: Detalle sala
  Map<String, dynamic>? _cubiculoSeleccionado;
  Map<String, dynamic>? _salaEspacio;
  bool _aceptoReglamento = false;
  bool _cargando = false;

  List<Map<String, dynamic>> _cubiculos = [];
  Map<String, dynamic>? _reservaActiva;
  int _asientosDisponiblesSala = 50;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  // Carga cubículos, sala y reserva activa desde Supabase
  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      // 1. Obtener todos los espacios
      final List<dynamic> espaciosData = await supabase
          .from('espacios')
          .select()
          .order('id', ascending: true);

      final cubiculos = espaciosData
          .where((e) => e['tipo'] == 'cubiculo')
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final sala = espaciosData.firstWhere(
        (e) => e['tipo'] == 'sala',
        orElse: () => {'id': 11, 'capacidad': 50, 'nombre': 'Sala de estudio'},
      );

      // Contar cuántas reservas activas/pendientes hay en sala para calcular libres
      final List<dynamic> reservasSala = await supabase
          .from('reservas')
          .select('id')
          .eq('espacio_id', sala['id'])
          .inFilter('estado', ['pendiente', 'activa']);

      final capacidadTotal = (sala['capacidad'] as num?)?.toInt() ?? 50;
      final ocupadosSala = reservasSala.length;
      final disponiblesCalculados = (capacidadTotal - ocupadosSala) > 0 ? (capacidadTotal - ocupadosSala) : 0;

      // 2. Obtener si el usuario logueado tiene reserva activa o pendiente
      final List<dynamic> reservasData = await supabase
          .from('reservas')
          .select('*, espacios(id, nombre, tipo)')
          .eq('matricula_usuario', widget.matricula)
          .inFilter('estado', ['pendiente', 'activa'])
          .order('fecha_solicitud', ascending: false)
          .limit(1);

      Map<String, dynamic>? activa;
      if (reservasData.isNotEmpty) {
        final r = reservasData.first;
        final infoEspacio = r['espacios'] ?? {};
        activa = {
          'id': r['id'],
          'espacio_id': r['espacio_id'],
          'espacio': infoEspacio['nombre'] ?? 'Espacio',
          'tipo': infoEspacio['tipo'] == 'cubiculo' ? 'Cubículo' : 'Sala de estudio',
          'estado': r['estado'],
        };
      }

      if (mounted) {
        setState(() {
          _cubiculos = cubiculos;
          _salaEspacio = Map<String, dynamic>.from(sala);
          _asientosDisponiblesSala = disponiblesCalculados;
          _reservaActiva = activa;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al sincronizar datos: $e')),
        );
      }
    }
  }

  // Solicitar reserva de cubículo en Supabase
  Future<void> _apartarCubiculo() async {
    if (_cubiculoSeleccionado == null) return;
    setState(() => _cargando = true);

    try {
      final int espacioId = _cubiculoSeleccionado!['id'];

      // Insertar en reservas
      await supabase.from('reservas').insert({
        'matricula_usuario': widget.matricula,
        'espacio_id': espacioId,
        'estado': 'pendiente',
      });

      // Cambiar disponibilidad del espacio a false
      await supabase
          .from('espacios')
          .update({'disponible': false})
          .eq('id', espacioId);

      await _cargarDatos();

      setState(() {
        _vistaActual = 0;
        _tabIndex = 1; // Llevar a "Mi Reserva"
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cubículo apartado. Preséntate en recepción.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _cargando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al apartar cubículo: $e')),
        );
      }
    }
  }

  // Solicitar lugar en la sala común en Supabase
  Future<void> _apartarLugarSala() async {
    if (_reservaActiva != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya cuentas con una reserva en curso')),
      );
      return;
    }

    if (_asientosDisponiblesSala <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay asientos disponibles en la sala')),
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      final int espacioId = _salaEspacio?['id'] ?? 11;

      // Insertar reserva de sala como pendiente para confirmación de recepción
      await supabase.from('reservas').insert({
        'matricula_usuario': widget.matricula,
        'espacio_id': espacioId,
        'estado': 'pendiente',
      });

      await _cargarDatos();

      setState(() {
        _vistaActual = 0;
        _tabIndex = 1; // Llevar a "Mi Reserva"
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lugar en sala solicitado. Confirma en recepción.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _cargando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al apartar sala: $e')),
        );
      }
    }
  }

  // Cancelar únicamente si está pendiente (el alumno se arrepintió antes de que lo validaran)
  Future<void> _cancelarApartadoPendiente() async {
    if (_reservaActiva == null) return;
    setState(() => _cargando = true);

    try {
      final int reservaId = _reservaActiva!['id'];
      final int espacioId = _reservaActiva!['espacio_id'];

      // Cancelar la reserva
      await supabase
          .from('reservas')
          .update({'estado': 'cancelada'})
          .eq('id', reservaId);

      // Si era un cubículo, volverlo a poner disponible
      if (_reservaActiva!['tipo'] == 'Cubículo') {
        await supabase
            .from('espacios')
            .update({'disponible': true})
            .eq('id', espacioId);
      }

      await _cargarDatos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Apartado cancelado con éxito')),
        );
      }
    } catch (e) {
      setState(() => _cargando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cancelar: $e')),
        );
      }
    }
  }

  // Menú Principal
  Widget _buildMenuPrincipal() {
    final int disponiblesCount = _cubiculos.where((c) => c['disponible'] == true).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Biblioteca FIME'),
            Text(
              'Hola, ${widget.nombre}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            tooltip: 'Actualizar',
            onPressed: _cargarDatos,
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
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selecciona un espacio',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  _cardSeleccion(
                    titulo: 'Cubículos de estudio',
                    subtitulo: 'Espacios cerrados para trabajo en equipo (mínimo 2 personas)',
                    icono: Icons.meeting_room_outlined,
                    badge: '$disponiblesCount Disponibles',
                    onTap: () => setState(() => _vistaActual = 1),
                  ),
                  const SizedBox(height: 16),
                  _cardSeleccion(
                    titulo: 'Sala común',
                    subtitulo: 'Espacios de trabajo y estudio individual libre',
                    icono: Icons.chair_alt_outlined,
                    badge: '$_asientosDisponiblesSala Asientos libres',
                    onTap: () => setState(() => _vistaActual = 3),
                  ),
                ],
              ),
            ),
    );
  }

  // Lista de Cubículos
  Widget _buildListaCubiculos() {
    final cubiculosDisponibles = _cubiculos.where((c) => c['disponible'] == true).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF004A99)),
          onPressed: () => setState(() => _vistaActual = 0),
        ),
        title: const Text('Cubículos disponibles'),
      ),
      body: cubiculosDisponibles.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No hay cubículos disponibles en este momento.'),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cubiculosDisponibles.length,
              itemBuilder: (context, index) {
                final cubiculo = cubiculosDisponibles[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    title: Text(cubiculo['nombre'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    subtitle: const Text('Disponible para apartar', style: TextStyle(color: Colors.green, fontSize: 13)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black26),
                    onTap: () {
                      if (_reservaActiva != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ya cuentas con una reserva en curso')),
                        );
                        return;
                      }
                      setState(() {
                        _cubiculoSeleccionado = cubiculo;
                        _aceptoReglamento = false;
                        _vistaActual = 2;
                      });
                    },
                  ),
                );
              },
            ),
    );
  }

  // Pre-registro Cubículo
  Widget _buildDetalleCubiculo() {
    final String nombreCubiculo = _cubiculoSeleccionado?['nombre'] ?? '';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF004A99)),
          onPressed: () => setState(() => _vistaActual = 1),
        ),
        title: Text('Apartar $nombreCubiculo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tendrás que completar este pre-registro para apartar tu cubículo en biblioteca.',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Preséntate en recepción. Una vez aceptada por el encargado, el estado cambiará a Activo.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(14)),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reglamento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF004A99))),
                  SizedBox(height: 8),
                  Text('1. Mínimo 2 personas con matrícula activa.', style: TextStyle(fontSize: 12)),
                  SizedBox(height: 4),
                  Text('2. Confirmación obligatoria en ventanilla.', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Checkbox(
                  value: _aceptoReglamento,
                  activeColor: const Color(0xFF004A99),
                  onChanged: (val) => setState(() => _aceptoReglamento = val ?? false),
                ),
                const Expanded(child: Text('He leído y acepto el reglamento', style: TextStyle(fontSize: 13))),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _aceptoReglamento ? const Color(0xFF004A99) : Colors.grey.shade400,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  elevation: 0,
                ),
                onPressed: (_aceptoReglamento && !_cargando) ? _apartarCubiculo : null,
                child: _cargando
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Apartar cubículo', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Detalle Sala
  Widget _buildDetalleSala() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF004A99)),
          onPressed: () => setState(() => _vistaActual = 0),
        ),
        title: const Text('Apartar lugar en Sala'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  const Text('Asientos disponibles', style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 6),
                  Text('$_asientosDisponiblesSala', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF004A99))),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004A99),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                onPressed: _cargando ? null : _apartarLugarSala,
                child: _cargando
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Confirmar lugar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Vista Mi Reserva
  Widget _buildVistaMiReserva() {
    final esPendiente = _reservaActiva != null && _reservaActiva!['estado'] == 'pendiente';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF004A99)),
          onPressed: () => setState(() => _tabIndex = 0),
        ),
        title: const Text('Mi Reservación'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            tooltip: 'Actualizar estado',
            onPressed: _cargarDatos,
          )
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: _reservaActiva == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bookmark_border_rounded, size: 72, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            'No tienes reservas activas o apartadas',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black54),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF004A99),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            onPressed: () => setState(() => _tabIndex = 0),
                            child: const Text('Apartar un espacio', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _reservaActiva!['espacio'] ?? '',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF004A99)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8F1FA),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      _reservaActiva!['tipo'] ?? '',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF004A99)),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: esPendiente ? Colors.orange.shade50 : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      esPendiente ? Icons.access_time_filled : Icons.check_circle,
                                      color: esPendiente ? Colors.orange : Colors.green,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            esPendiente ? 'Pendiente de confirmación' : 'Reserva aceptada y activa',
                                            style: TextStyle(
                                              color: esPendiente ? Colors.orange.shade800 : Colors.green.shade800,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            esPendiente
                                                ? 'Ve a recepción para que el encargado autorice tu entrada'
                                                : 'Espacio en uso. Recepción finalizará tu turno al retirarte',
                                            style: TextStyle(
                                              color: esPendiente ? Colors.orange.shade700 : Colors.green.shade700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // El alumno SOLO puede cancelar si está PENDIENTE
                              if (esPendiente)
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.redAccent),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    onPressed: _cargando ? null : _cancelarApartadoPendiente,
                                    child: const Text(
                                      'Cancelar apartado',
                                      style: TextStyle(color: Colors.redAccent),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }

  Widget _cardSeleccion({
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required String badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFE8F1FA), borderRadius: BorderRadius.circular(14)),
              child: Icon(icono, color: const Color(0xFF004A99), size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitulo, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFF1F2F6), borderRadius: BorderRadius.circular(8)),
                    child: Text(badge, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF004A99))),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget cuerpo;
    if (_tabIndex == 1) {
      cuerpo = _buildVistaMiReserva();
    } else {
      switch (_vistaActual) {
        case 1:
          cuerpo = _buildListaCubiculos();
          break;
        case 2:
          cuerpo = _buildDetalleCubiculo();
          break;
        case 3:
          cuerpo = _buildDetalleSala();
          break;
        default:
          cuerpo = _buildMenuPrincipal();
      }
    }

    return Scaffold(
      body: cuerpo,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        selectedItemColor: const Color(0xFF004A99),
        onTap: (index) => setState(() {
          _tabIndex = index;
          _vistaActual = 0;
        }),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), label: 'Reservar'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark_outline), label: 'Mi Reserva'),
        ],
      ),
    );
  }
}