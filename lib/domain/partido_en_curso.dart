/// Enganches para saber que hay un partido en vivo abierto. La app los conecta a la base (main.dart):
/// al empezar se anota la partida; al terminar se borra la marca. Si la app se cierra a mitad de
/// partido, la marca queda y al volver a abrir esa partida el partido se resuelve (simulado), así no
/// se puede repetir gratis.
class PartidoEnCurso {
  PartidoEnCurso._();

  static void Function()? alEmpezar;
  static void Function()? alTerminar;
}
