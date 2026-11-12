import 'entities/jugador.dart';
import 'entities/posicion.dart';
import 'entities/rival.dart';
import 'entities/temporada.dart';
import 'liga.dart';

/// Lo que contesta un rival a una oferta de pase.
class Respuesta {
  const Respuesta({required this.acepta, required this.motivo, this.contraoferta});

  final bool acepta;
  final String motivo;

  /// La mejor carta tuya que sí aceptarían por la que pediste (si existe).
  final Jugador? contraoferta;
}

/// Mercado de pases (GDD: temporada y liga): tu jugador por uno de un rival, uno por uno, hasta
/// la fecha límite. La respuesta del rival es una regla fija, sin azar escondido.
class Mercado {
  Mercado(this.liga);

  final Liga liga;

  static const maxPases = 3;

  /// Fecha límite: el 60 % de la temporada regular.
  int jornadaLimite(Temporada t) {
    if (t.calendario.isEmpty) return 0;
    final ultima = t.calendario.map((p) => p.jornada).reduce((a, b) => a > b ? a : b);
    return (ultima * 0.6).round();
  }

  int? _proximaJornada(Temporada t) => liga.proximoDelUsuario(t)?.jornada;

  int pasesRestantes(Temporada t) => maxPases - t.pases.length;

  bool abierto(Temporada t) {
    final proxima = _proximaJornada(t);
    return t.fase == FaseTemporada.temporadaRegular &&
        proxima != null &&
        proxima <= jornadaLimite(t) &&
        t.pases.length < maxPases;
  }

  /// Por qué está cerrado (null si está abierto).
  String? motivoCierre(Temporada t) {
    if (abierto(t)) return null;
    if (t.fase != FaseTemporada.temporadaRegular || _proximaJornada(t) == null) {
      return 'El mercado solo abre durante la temporada regular.';
    }
    if (t.pases.length >= maxPases) return 'Ya hiciste los $maxPases pases permitidos esta temporada.';
    return 'Pasó la fecha límite (jornada ${jornadaLimite(t)}): el mercado está cerrado hasta la próxima temporada.';
  }

  /// El plantel del rival, puesto por puesto.
  List<(Posicion, Jugador)> pedibles(Temporada t, String rivalId) {
    final plantel = liga.plantelDe(t.rivales[rivalId]!);
    return [
      for (final p in Posicion.values)
        if (plantel.en(p) case final j?) (p, j),
    ];
  }

  int _valor(Temporada t, Jugador j) => j.media + (t.forma[j.id] ?? 0);

  String _apellido(Jugador j) {
    final partes = j.nombre.split(' ').where((p) => !{'Jr.', 'Jr', 'Sr.', 'II', 'III', 'IV'}.contains(p)).toList();
    return partes.isEmpty ? j.nombre : partes.last;
  }

  String _equipo(Temporada t, String rivalId) => liga.franquicias.firstWhere((f) => f.id == rivalId).nombre;

  /// Cuánto tiene que valer tu carta por encima de la de ellos para que digan que sí.
  int margen(Temporada t, String rivalId, Jugador suyo) {
    var m = switch (suyo.tier) {
      Tier.sPlus => 4,
      Tier.b => 1,
      _ => 2,
    };
    // Si es su puesto más flojo, lo quieren mejorar y se conforman con menos (salvo un intocable).
    final roster = pedibles(t, rivalId);
    final peor = roster.map((e) => e.$2.media).reduce((a, b) => a < b ? a : b);
    if (suyo.media == peor && suyo.tier != Tier.sPlus) m = -1;
    return m;
  }

  Respuesta evaluar(Temporada t, Jugador mio, String rivalId, Jugador suyo) {
    final equipo = _equipo(t, rivalId);
    final miPuesto = t.plantel.puestoDe(mio.id);
    final roster = pedibles(t, rivalId);
    final suPuesto = roster.where((e) => e.$2.id == suyo.id).map((e) => e.$1).firstOrNull;
    if (miPuesto == null) return const Respuesta(acepta: false, motivo: 'Esa carta no está en tu plantel.');
    if (suPuesto == null) return Respuesta(acepta: false, motivo: '${suyo.nombre} no juega en los $equipo.');
    if (!abierto(t)) return Respuesta(acepta: false, motivo: motivoCierre(t)!);
    if ((t.lesiones[mio.id] ?? 0) > 0) {
      return Respuesta(
        acepta: false,
        motivo: 'Los $equipo no reciben lesionados: ${_apellido(mio)} está en la enfermería.',
      );
    }
    if ((t.lesiones[suyo.id] ?? 0) > 0) {
      return Respuesta(acepta: false, motivo: '${_apellido(suyo)} está lesionado: no se puede pasar.');
    }
    if (!mio.puedeJugarEn(suPuesto)) {
      return Respuesta(
        acepta: false,
        motivo: 'A los $equipo no les sirve: ${_apellido(mio)} no juega de ${suPuesto.etiqueta}.',
      );
    }
    if (!suyo.puedeJugarEn(miPuesto)) {
      return Respuesta(acepta: false, motivo: '${_apellido(suyo)} no puede ocupar tu puesto de ${miPuesto.etiqueta}.');
    }
    final necesario = _valor(t, suyo) + margen(t, rivalId, suyo);
    if (_valor(t, mio) >= necesario) {
      return Respuesta(
        acepta: true,
        motivo: '¡Trato hecho! Los $equipo aceptan: ${_apellido(mio)} por ${_apellido(suyo)}.',
      );
    }
    final contra = _contraoferta(t, suyo, suPuesto, necesario);
    final motivo = suyo.tier == Tier.sPlus
        ? 'Los $equipo dicen que no: ${_apellido(suyo)} es intocable.'
        : 'Los $equipo dicen que no: ${_apellido(mio)} no alcanza para ${_apellido(suyo)}.';
    return Respuesta(acepta: false, motivo: motivo, contraoferta: contra);
  }

  /// La carta tuya de menos valor que igual aceptarían (para no regalar de más).
  Jugador? _contraoferta(Temporada t, Jugador suyo, Posicion suPuesto, int necesario) {
    final candidatos = [
      for (final p in Posicion.values)
        if (t.plantel.en(p) case final j?)
          if ((t.lesiones[j.id] ?? 0) == 0 &&
              j.puedeJugarEn(suPuesto) &&
              suyo.puedeJugarEn(p) &&
              _valor(t, j) >= necesario)
            j,
    ]..sort((a, b) => _valor(t, a).compareTo(_valor(t, b)));
    return candidatos.firstOrNull;
  }

  /// Hace el pase (vuelve a chequear la respuesta): las cartas cambian de plantel y queda anotado.
  Temporada ejecutar(Temporada t, Jugador mio, String rivalId, Jugador suyo) {
    final respuesta = evaluar(t, mio, rivalId, suyo);
    if (!respuesta.acepta) throw StateError(respuesta.motivo);
    final miPuesto = t.plantel.puestoDe(mio.id)!;
    final suPuesto = pedibles(t, rivalId).firstWhere((e) => e.$2.id == suyo.id).$1;
    final plantel = t.plantel.quitar(miPuesto).asignar(suyo, miPuesto);
    final r = t.rivales[rivalId]!;
    final rival = Rival(
      franquiciaId: r.franquiciaId,
      tipo: r.tipo,
      epoca: r.epoca,
      identidadId: r.identidadId,
      cartaIds: {...r.cartaIds, suPuesto: mio.id},
      tactica: r.tactica,
    );
    return t.copyWith(
      plantel: plantel,
      rivales: {...t.rivales, rivalId: rival},
      pases: [
        ...t.pases,
        Pase(jornada: _proximaJornada(t) ?? 0, franquiciaId: rivalId, dioId: mio.id, recibioId: suyo.id),
      ],
    );
  }
}
