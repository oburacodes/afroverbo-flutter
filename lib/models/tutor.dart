class TutorProfile {
  final int id;
  final Map<String, dynamic> user;
  final String bio;
  final double hourlyRate;
  final double? platformFee;
  final double? tutorEarnings;
  final String specialization;
  final bool available;
  final String? profilePicture;
  final String? qualifications;
  final String? level;
  final String? experience;
  final String? availableTimes;
  // Structured availability slots — list of {dayOfWeek, startTime, endTime, active}
  final List<dynamic>? availabilitySlots;

  TutorProfile({
    required this.id,
    required this.user,
    required this.bio,
    required this.hourlyRate,
    this.platformFee,
    this.tutorEarnings,
    required this.specialization,
    required this.available,
    this.profilePicture,
    this.qualifications,
    this.level,
    this.experience,
    this.availableTimes,
    this.availabilitySlots,
  });

  factory TutorProfile.fromJson(Map<String, dynamic> json) {
    return TutorProfile(
      id: json['id'] as int,
      user: Map<String, dynamic>.from(json['user'] as Map),
      bio: json['bio'] as String? ?? '',
      hourlyRate: (json['hourlyRate'] as num?)?.toDouble() ?? 0.0,
      platformFee: (json['platformFee'] as num?)?.toDouble(),
      tutorEarnings: (json['tutorEarnings'] as num?)?.toDouble(),
      specialization: json['specialization'] as String? ?? '',
      available: json['available'] as bool? ?? false,
      profilePicture: json['profilePicture'] as String?,
      qualifications: json['qualifications'] as String?,
      level: json['level'] as String?,
      experience: json['experience'] as String?,
      availableTimes: json['availableTimes'] as String?,
      availabilitySlots: json['availabilitySlots'] as List<dynamic>?,
    );
  }
}
