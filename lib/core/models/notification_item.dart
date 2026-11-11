/// A recent notification captured by the opt-in listener. Lives in memory
/// only — nothing is persisted or uploaded.
class NotificationItem {
  const NotificationItem({
    required this.key,
    required this.packageName,
    required this.postedAt,
    this.title,
    this.text,
    this.clearable = false,
  });

  final String key;
  final String packageName;
  final int postedAt;
  final String? title;
  final String? text;
  final bool clearable;

  static NotificationItem fromMap(Map<Object?, Object?> map) {
    return NotificationItem(
      key: (map['key'] as String?) ?? '',
      packageName: (map['packageName'] as String?) ?? '',
      title: map['title'] as String?,
      text: map['text'] as String?,
      postedAt: (map['postedAt'] as num?)?.toInt() ?? 0,
      clearable: (map['clearable'] as bool?) ?? false,
    );
  }
}
