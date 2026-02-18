/// Faculty model - represents academic departments
class Faculty {
  final int id;
  final String name;
  final String slug;
  final String? code;
  final int semestersCount;
  final int semesterDurationMonths;

  Faculty({
    required this.id,
    required this.name,
    required this.slug,
    this.code,
    this.semestersCount = 8,
    this.semesterDurationMonths = 6,
  });

  factory Faculty.fromJson(Map<String, dynamic> json) {
    return Faculty(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
      code: json['code'] as String?,
      semestersCount: json['semestersCount'] as int? ?? 8,
      semesterDurationMonths: json['semesterDurationMonths'] as int? ?? 6,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'code': code,
    'semestersCount': semestersCount,
    'semesterDurationMonths': semesterDurationMonths,
  };
}

/// Student profile model
class StudentProfile {
  final String userId;
  final int facultyId;
  final int currentSemester;
  final DateTime semesterStartDate;
  final DateTime? semesterEndDate;
  final bool autoAdvance;
  final Faculty? faculty;

  StudentProfile({
    required this.userId,
    required this.facultyId,
    required this.currentSemester,
    required this.semesterStartDate,
    this.semesterEndDate,
    this.autoAdvance = true,
    this.faculty,
  });

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      userId: json['userId']?.toString() ?? '',
      facultyId: json['facultyId'] as int? ?? 0,
      currentSemester: json['currentSemester'] as int? ?? 1,
      semesterStartDate: json['semesterStartDate'] != null
          ? DateTime.parse(json['semesterStartDate'] as String)
          : DateTime.now(),
      semesterEndDate: json['semesterEndDate'] != null
          ? DateTime.parse(json['semesterEndDate'] as String)
          : null,
      autoAdvance: json['autoAdvance'] as bool? ?? true,
      faculty: json['faculty'] != null
          ? Faculty.fromJson(json['faculty'] as Map<String, dynamic>)
          : null,
    );
  }
}
