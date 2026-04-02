import '../enums/orientation_type.dart';
import 'slide_model.dart';

class ProjectModel {
  final String projectId;
  final String projectName;
  final OrientationType orientation;
  final int width;
  final int height;
  final List<SlideModel> slides;
  final DateTime updatedAt;

  const ProjectModel({
    required this.projectId,
    required this.projectName,
    required this.orientation,
    required this.width,
    required this.height,
    required this.slides,
    required this.updatedAt,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    final slidesJson = json['slides'] as List<dynamic>? ?? [];

    return ProjectModel(
      projectId: json['projectId'] as String? ?? '',
      projectName: json['projectName'] as String? ?? '',
      orientation: OrientationType.fromString(
        json['orientation'] as String? ?? 'landscape',
      ),
      width: json['width'] as int? ?? 1920,
      height: json['height'] as int? ?? 1080,
      slides: slidesJson
          .map((slide) => SlideModel.fromJson(slide as Map<String, dynamic>))
          .toList(),
      updatedAt: DateTime.now(),
    );
  }
}