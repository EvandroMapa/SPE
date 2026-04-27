extension StringExt on String {
  String get toCompare => replaceAll(
        ' ',
        '',
      ).toLowerCase().toNonDiacritics();

  String getInitials() {
    if (isEmpty) return '';
    final names = split(' ');
    names.removeWhere((element) => element.isEmpty);
    if (names.length == 1) {
      return names[0].substring(0, 2).toUpperCase();
    }
    return (names[0][0] + names[1][0]).toUpperCase();
  }

  String toNonDiacritics() {
    String diacritics =
        'ÀÁÂÃÄÅàáâãäåÒÓÔÕÕÖØòóôõöøÈÉÊËèéêëðÇçÐÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž';
    String nonDiacritics =
        'AAAAAAaaaaaaOOOOOOOooooooEEEEeeeeeCcDIIIIiiiiUUUUuuuuNnSsYyyZz';
    return splitMapJoin(
      '',
      onNonMatch: (char) => char.isNotEmpty && diacritics.contains(char)
          ? nonDiacritics[diacritics.indexOf(char)]
          : char,
    );
  }

  String toCaptalized() {
    return this[0].toUpperCase() + substring(1);
  }
}
