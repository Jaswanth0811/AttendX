class Subject {
  final int? id;
  final String name;
  final String code;
  final String facultyName;
  final String colorHex;
  final int createdAt;

  Subject({
    this.id,
    required this.name,
    required this.code,
    required this.facultyName,
    required this.colorHex,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'facultyName': facultyName,
      'colorHex': colorHex,
      'createdAt': createdAt,
    };
  }

  factory Subject.fromMap(Map<String, dynamic> map) {
    return Subject(
      id: map['id'] as int?,
      name: map['name'] as String,
      code: map['code'] as String,
      facultyName: map['facultyName'] as String,
      colorHex: map['colorHex'] as String,
      createdAt: map['createdAt'] as int,
    );
  }
}
