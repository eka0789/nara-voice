/// Normalizes raw transcripts (both Indonesian and English) into a canonical
/// form for pattern matching: lowercase, ASCII punctuation stripped, filler
/// politeness words removed, whitespace collapsed.
class TextNormalizer {
  const TextNormalizer._();

  /// Politeness/filler words removed before intent matching. Content
  /// extraction runs on the *original* text when quoting matters.
  static const _fillers = <String>{
    'tolong', 'coba', 'dong', 'deh', 'ya', 'yah', 'silakan', 'mohon',
    'please', 'kindly', 'just', 'now', 'sekarang', 'saya mau', 'aku mau',
    'i want to', 'i want', 'can you', 'could you', 'bisakah kamu', 'bisakah',
  };

  static String normalize(String raw) {
    var text = raw.toLowerCase().trim();
    text = text
        .replaceAll(RegExp(r'[’‘]'), "'")
        .replaceAll(RegExp(r'[“”]'), '"')
        .replaceAll(RegExp(r'[^a-z0-9\s\.\:\+\-@_/&]'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return _stripFillers(text);
  }

  static String _stripFillers(String text) {
    var result = ' $text ';
    // Multi-word fillers first (longest match), then single tokens.
    final multi = _fillers.where((f) => f.contains(' ')).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final filler in multi) {
      result = result.replaceAll(' $filler ', ' ');
    }
    final single = _fillers.where((f) => !f.contains(' '));
    result = result
        .split(' ')
        .where((token) => !single.contains(token))
        .join(' ')
        .trim();
    return result;
  }

  /// Very lightweight language detection for transcripts.
  static String detectLanguage(String raw) {
    final text = ' ${raw.toLowerCase()} ';
    const idMarkers = <String>{
      ' buka', ' cari', ' kirim', ' tolong', ' yang', ' dan ', ' ke ', ' di ',
      ' layar', ' pesan', ' email', ' jadwal', ' bilang', ' katakan', ' siapa',
      ' apa ', ' gimana', ' bagikan', ' putar', ' nyalakan', ' matikan',
      ' pengaturan', ' notifikasi', ' surat', ' tulis', ' isi ',
    };
    const enMarkers = <String>{
      ' open ', ' find ', ' search ', ' send ', ' the ', ' and ', ' to ',
      ' screen', ' message', ' schedule', ' play ', ' turn on', ' turn off',
      ' settings', ' notifications', ' write ', ' read ', ' what ', ' where',
    };
    var idScore = 0;
    var enScore = 0;
    for (final m in idMarkers) {
      if (text.contains(m)) idScore++;
    }
    for (final m in enMarkers) {
      if (text.contains(m)) enScore++;
    }
    if (idScore > enScore) return 'id';
    if (enScore > idScore) return 'en';
    // Fall back to explicit locale words or default Indonesian market.
    return 'id';
  }

  /// Splits a compound command into segments on coordinators.
  /// "buka youtube dan cari flutter" → ['buka youtube', 'cari flutter']
  static List<String> splitSegments(String normalized) {
    final parts = normalized
        .split(RegExp(r'\s+(?:lalu|kemudian|terus|dan|then|and|also|after that)\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.isEmpty ? <String>[normalized] : parts;
  }
}
