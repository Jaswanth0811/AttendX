class Holiday {
  final int? id;
  final int date; // start-of-day millis
  final String name;
  final int createdAt;

  Holiday({
    this.id,
    required this.date,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'date': date,
      'name': name,
      'createdAt': createdAt,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory Holiday.fromMap(Map<String, dynamic> map) {
    return Holiday(
      id: map['id'] as int?,
      date: map['date'] as int,
      name: map['name'] as String,
      createdAt: map['createdAt'] as int,
    );
  }

  Holiday copyWith({int? id, int? date, String? name, int? createdAt}) {
    return Holiday(
      id: id ?? this.id,
      date: date ?? this.date,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
