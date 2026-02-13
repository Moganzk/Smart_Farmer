/// Data model for a crop-scan diagnosis record.
///
/// Persisted locally (sqflite) and optionally synced to Firestore.

class ScanRecord {
  final String id;
  final String uid;
  final DateTime createdAt;
  final String imagePath;
  final String? thumbnailPath;
  final String cropType;
  final String diagnosisName;
  final double confidence;
  final String severity; // low | medium | high
  final List<String> recommendations;
  final String syncStatus; // local_only | pending | synced | failed
  final String? remoteId;
  final String? debugReason; // dev-only: why diagnosis failed

  const ScanRecord({
    required this.id,
    required this.uid,
    required this.createdAt,
    required this.imagePath,
    this.thumbnailPath,
    this.cropType = 'Unknown',
    required this.diagnosisName,
    required this.confidence,
    required this.severity,
    required this.recommendations,
    this.syncStatus = 'local_only',
    this.remoteId,
    this.debugReason,
  });

  ScanRecord copyWith({
    String? id,
    String? uid,
    DateTime? createdAt,
    String? imagePath,
    String? thumbnailPath,
    String? cropType,
    String? diagnosisName,
    double? confidence,
    String? severity,
    List<String>? recommendations,
    String? syncStatus,
    String? remoteId,
    String? debugReason,
  }) {
    return ScanRecord(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      createdAt: createdAt ?? this.createdAt,
      imagePath: imagePath ?? this.imagePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      cropType: cropType ?? this.cropType,
      diagnosisName: diagnosisName ?? this.diagnosisName,
      confidence: confidence ?? this.confidence,
      severity: severity ?? this.severity,
      recommendations: recommendations ?? this.recommendations,
      syncStatus: syncStatus ?? this.syncStatus,
      remoteId: remoteId ?? this.remoteId,
      debugReason: debugReason ?? this.debugReason,
    );
  }

  // ── SQLite serialisation ──

  Map<String, dynamic> toMap() => {
    'id': id,
    'uid': uid,
    'createdAt': createdAt.toIso8601String(),
    'imagePath': imagePath,
    'thumbnailPath': thumbnailPath,
    'cropType': cropType,
    'diagnosisName': diagnosisName,
    'confidence': confidence,
    'severity': severity,
    'recommendations': recommendations.join('||'),
    'syncStatus': syncStatus,
    'remoteId': remoteId,
  };

  factory ScanRecord.fromMap(Map<String, dynamic> m) {
    final recsRaw = m['recommendations'] as String? ?? '';
    return ScanRecord(
      id: m['id'] as String,
      uid: m['uid'] as String,
      createdAt: DateTime.parse(m['createdAt'] as String),
      imagePath: m['imagePath'] as String,
      thumbnailPath: m['thumbnailPath'] as String?,
      cropType: m['cropType'] as String? ?? 'Unknown',
      diagnosisName: m['diagnosisName'] as String,
      confidence: (m['confidence'] as num).toDouble(),
      severity: m['severity'] as String? ?? 'medium',
      recommendations: recsRaw.isEmpty ? [] : recsRaw.split('||'),
      syncStatus: m['syncStatus'] as String? ?? 'local_only',
      remoteId: m['remoteId'] as String?,
    );
  }

  // ── Firestore serialisation ──

  Map<String, dynamic> toFirestore() => {
    'uid': uid,
    'createdAt': createdAt.toIso8601String(),
    'cropType': cropType,
    'diagnosisName': diagnosisName,
    'confidence': confidence,
    'severity': severity,
    'recommendations': recommendations,
    'imagePath': imagePath,
  };

  /// Severity colour helper (returns hex int).
  int get severityColorHex {
    switch (severity) {
      case 'low':
        return 0xFF39FF14; // neonGreen
      case 'medium':
        return 0xFFFFD600; // warning
      case 'high':
        return 0xFFFF5252; // error
      default:
        return 0xFF9E9E9E;
    }
  }
}
