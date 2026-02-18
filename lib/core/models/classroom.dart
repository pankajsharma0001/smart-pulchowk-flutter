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

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'facultyId': facultyId,
    'currentSemester': currentSemester,
    'semesterStartDate': semesterStartDate.toIso8601String(),
    'semesterEndDate': semesterEndDate?.toIso8601String(),
    'autoAdvance': autoAdvance,
    'faculty': faculty?.toJson(),
  };
}

/// Subject model - represents a course in a semester
class Subject {
  final int id;
  final int facultyId;
  final int semesterNumber;
  final String? code;
  final String title;
  final bool isElective;
  final String? electiveGroup;
  final List<Assignment>? assignments;

  Subject({
    required this.id,
    required this.facultyId,
    required this.semesterNumber,
    this.code,
    required this.title,
    this.isElective = false,
    this.electiveGroup,
    this.assignments,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] as int,
      facultyId: json['facultyId'] as int,
      semesterNumber: json['semesterNumber'] as int,
      code: json['code'] as String?,
      title: json['title'] as String,
      isElective: json['isElective'] as bool? ?? false,
      electiveGroup: json['electiveGroup'] as String?,
      assignments: json['assignments'] != null
          ? (json['assignments'] as List)
                .map((e) => Assignment.fromJson(e as Map<String, dynamic>))
                .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'facultyId': facultyId,
    'semesterNumber': semesterNumber,
    'code': code,
    'title': title,
    'isElective': isElective,
    'electiveGroup': electiveGroup,
  };
}

/// Assignment model - representing a task for a subject
class Assignment {
  final int id;
  final int subjectId;
  final String teacherId;
  final String title;
  final String? description;
  final String type; // 'classwork' or 'homework'
  final DateTime? dueAt;
  final DateTime createdAt;
  final Submission? submission;
  String? subjectTitle;

  Assignment({
    required this.id,
    required this.subjectId,
    required this.teacherId,
    required this.title,
    this.description,
    required this.type,
    this.dueAt,
    required this.createdAt,
    this.submission,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: json['id'] as int,
      subjectId: json['subjectId'] as int,
      teacherId: json['teacherId']?.toString() ?? '',
      title: json['title'] as String,
      description: json['description'] as String?,
      type: json['type'] as String? ?? 'classwork',
      dueAt: json['dueAt'] != null
          ? DateTime.parse(json['dueAt'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      submission: json['submission'] != null
          ? Submission.fromJson(json['submission'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get isDueSoon {
    if (dueAt == null) return false;
    final now = DateTime.now();
    final diff = dueAt!.difference(now);
    return diff.inDays >= 0 && diff.inDays <= 2;
  }

  bool get isOverdue {
    if (dueAt == null) return false;
    return DateTime.now().isAfter(dueAt!) && submission == null;
  }
}

/// Submission model - student's work for an assignment
class Submission {
  final int id;
  final int assignmentId;
  final String studentId;
  final String? comment;
  final String fileUrl;
  final String status; // 'submitted', 'graded', 'returned'
  final DateTime submittedAt;
  final String? fileName;
  final int? fileSize;

  Submission({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    this.comment,
    required this.fileUrl,
    required this.status,
    required this.submittedAt,
    this.fileName,
    this.fileSize,
  });

  factory Submission.fromJson(Map<String, dynamic> json) {
    return Submission(
      id: json['id'] as int,
      assignmentId: json['assignmentId'] as int,
      studentId: json['studentId']?.toString() ?? '',
      comment: json['comment'] as String?,
      fileUrl: json['fileUrl'] as String,
      status: json['status'] as String? ?? 'submitted',
      submittedAt: json['submittedAt'] != null
          ? DateTime.parse(json['submittedAt'] as String)
          : DateTime.now(),
      fileName: json['fileName'] as String?,
      fileSize: json['fileSize'] as int?,
    );
  }
}
