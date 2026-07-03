class Semester {
  final int? id;
  final String name;
  final int startDate; // Epoch millis
  final int endDate; // Epoch millis
  final bool isActive;

  Semester({
    this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'startDate': startDate,
      'endDate': endDate,
      'isActive': isActive ? 1 : 0,
    };
  }

  factory Semester.fromMap(Map<String, dynamic> map) {
    return Semester(
      id: map['id'] as int?,
      name: map['name'] as String,
      startDate: map['startDate'] as int,
      endDate: map['endDate'] as int,
      isActive: (map['isActive'] as int) == 1,
    );
  }
}
