extension IterableExtension<T> on Iterable<T> {

  O? mapFirstNotNull<O extends Object>(O? Function(T) mapper) {
    for (final e in this) {
      final mapped = mapper(e);
      if (mapped != null) {
        return mapped;
      }
    }
    return null;
  }
}