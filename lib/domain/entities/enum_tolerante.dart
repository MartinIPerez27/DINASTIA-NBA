/// Lectura tolerante de enums desde JSON.
///
/// `values.byName` revienta con un valor desconocido (un guardado de una versión futura, un enum
/// renombrado). Estas lecturas no: devuelven null o un valor por defecto y el que llama decide si
/// descarta la entrada o sigue con el valor de reemplazo.
extension EnumTolerante<T extends Enum> on Iterable<T> {
  /// El valor con ese nombre, o null si no existe (o si no es un texto).
  T? porNombre(Object? nombre) => nombre is String ? asNameMap()[nombre] : null;

  /// El valor con ese nombre, o [defecto] (por defecto, el primero) si no existe.
  T porNombreO(Object? nombre, [T? defecto]) => porNombre(nombre) ?? defecto ?? first;
}
