import 'package:flutter/material.dart';
import 'services/busqueda_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(title: 'local_med', home: ConsultaScreen()));
}

enum _Paso { sintoma, intensidad, duracion, resultados }

class ConsultaScreen extends StatefulWidget {
  const ConsultaScreen({super.key});
  @override
  State<ConsultaScreen> createState() => _ConsultaScreenState();
}

class _ConsultaScreenState extends State<ConsultaScreen> {
  _Paso _paso = _Paso.sintoma;
  final _controller = TextEditingController();
  String _sintoma = '';
  String? _intensidadLabel;
  String? _intensidadQuery;
  String? _duracionLabel;
  bool _buscando = false;
  List<TarjetaResultado> _resultados = [];
  BusquedaService? _servicio;
  String? _error;

  static const _opcionesIntensidad = [
    ('Leve', 'síntomas leves'),
    ('Moderado', 'síntomas moderados'),
    ('Severo', 'síntomas severos'),
  ];

  static const _opcionesDuracion = [
    ('Pocas horas', 'inicio reciente'),
    ('1-2 días', 'hace 1-2 días'),
    ('Más de 3 días', 'hace varios días'),
  ];

  Future<void> _seleccionarIntensidad(String label, String query) async {
    setState(() {
      _intensidadLabel = label;
      _intensidadQuery = query;
      _paso = _Paso.duracion;
    });
  }

  Future<void> _seleccionarDuracion(String label, String query) async {
    setState(() {
      _duracionLabel = label;
      _buscando = true;
      _error = null;
    });
    try {
      _servicio ??= await BusquedaService.crear();
      final q = '$_sintoma, $_intensidadQuery, $query';
      final resultados = await _servicio!.buscar(q, topK: 3);
      setState(() {
        _resultados = resultados;
        _paso = _Paso.resultados;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _buscando = false);
    }
  }

  void _reiniciar() {
    setState(() {
      _paso = _Paso.sintoma;
      _sintoma = '';
      _intensidadLabel = null;
      _intensidadQuery = null;
      _duracionLabel = null;
      _resultados = [];
      _error = null;
      _controller.clear();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('local_med')),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _buscando ? _buildCargando() : _buildPaso(),
      ),
    );
  }

  Widget _buildCargando() {
    return const Center(
      key: ValueKey('loading'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Buscando...'),
        ],
      ),
    );
  }

  Widget _buildPaso() {
    return switch (_paso) {
      _Paso.sintoma => _buildSintoma(),
      _Paso.intensidad => _buildOpciones(
          key: const ValueKey('intensidad'),
          pasoNum: 2,
          pregunta: '¿Qué tan intensos son tus síntomas?',
          opciones: _opcionesIntensidad,
          seleccionado: _intensidadLabel,
          onTap: _seleccionarIntensidad,
        ),
      _Paso.duracion => _buildOpciones(
          key: const ValueKey('duracion'),
          pasoNum: 3,
          pregunta: '¿Hace cuánto comenzaron?',
          opciones: _opcionesDuracion,
          seleccionado: _duracionLabel,
          onTap: _seleccionarDuracion,
        ),
      _Paso.resultados => _buildResultados(),
    };
  }

  Widget _buildSintoma() {
    return Padding(
      key: const ValueKey('sintoma'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Indicador(pasoActual: 1, total: 3),
          const SizedBox(height: 32),
          const Text(
            '¿Qué siente?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Ej: tengo fiebre y dolor de garganta...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _controller.text.trim().isEmpty
                ? null
                : () => setState(() {
                      _sintoma = _controller.text.trim();
                      _paso = _Paso.intensidad;
                    }),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  Widget _buildOpciones({
    required Key key,
    required int pasoNum,
    required String pregunta,
    required List<(String, String)> opciones,
    required String? seleccionado,
    required void Function(String, String) onTap,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Indicador(pasoActual: pasoNum, total: 3),
          const SizedBox(height: 32),
          Text(
            pregunta,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          for (final op in opciones)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton(
                onPressed: () => onTap(op.$1, op.$2),
                style: seleccionado == op.$1
                    ? OutlinedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                      )
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(op.$1, style: const TextStyle(fontSize: 16)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultados() {
    if (_error != null) {
      return Center(
        key: const ValueKey('error'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $_error',
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                  onPressed: _reiniciar,
                  child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    return ListView(
      key: const ValueKey('resultados'),
      padding: const EdgeInsets.all(16),
      children: [
        _ResumenConsulta(
          sintoma: _sintoma,
          intensidad: _intensidadLabel!,
          duracion: _duracionLabel!,
        ),
        const SizedBox(height: 8),
        for (final r in _resultados) _TarjetaWidget(resultado: r),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _reiniciar,
          child: const Text('Nueva consulta'),
        ),
      ],
    );
  }
}

class _Indicador extends StatelessWidget {
  final int pasoActual;
  final int total;
  const _Indicador({required this.pasoActual, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < total; i++)
          Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: i < pasoActual
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );
  }
}

class _ResumenConsulta extends StatelessWidget {
  final String sintoma;
  final String intensidad;
  final String duracion;
  const _ResumenConsulta({
    required this.sintoma,
    required this.intensidad,
    required this.duracion,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sintoma,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              '$intensidad · $duracion',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaWidget extends StatelessWidget {
  final TarjetaResultado resultado;
  const _TarjetaWidget({required this.resultado});

  @override
  Widget build(BuildContext context) {
    final e = resultado.enriquecimiento;
    final enriq = e['enriquecimiento'] as Map<String, dynamic>?;
    final accion = enriq?['accion'] as String? ?? '';
    final queHacer =
        (enriq?['que_hacer_ahora'] as List?)?.cast<String>() ?? [];
    final padecimientos =
        (enriq?['posibles_padecimientos'] as List?) ?? [];

    final accionColor = switch (accion) {
      'autocuidado' => Colors.green,
      'medico_general' => Colors.orange,
      _ => Colors.red,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    e['area'] as String? ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                _Badge(text: accion, color: accionColor),
              ],
            ),
            if (padecimientos.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                (padecimientos.first as Map)['nombre'] as String? ?? '',
                style:
                    TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ],
            if (queHacer.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Qué hacer:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              for (final paso in queHacer.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ',
                          style: TextStyle(fontSize: 13)),
                      Expanded(
                          child: Text(paso,
                              style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Text(
              'Relevancia: ${(resultado.score * 100).toStringAsFixed(0)}%',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
