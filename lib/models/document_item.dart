class DocumentItem {
  final int? id;
  final String title;
  final String localPath;
  final String extension;
  final int totalPages;
  final int currentPage;
  final int currentSentence;
  final int currentCharOffset;
  final double progress;
  final double speechRate;
  final bool preparedOffline;
  final DateTime updatedAt;

  const DocumentItem({
    this.id,
    required this.title,
    required this.localPath,
    required this.extension,
    required this.totalPages,
    this.currentPage = 1,
    this.currentSentence = 0,
    this.currentCharOffset = 0,
    this.progress = 0,
    this.speechRate = 1.0,
    this.preparedOffline = false,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'local_path': localPath,
        'extension': extension,
        'total_pages': totalPages,
        'current_page': currentPage,
        'current_sentence': currentSentence,
        'current_char_offset': currentCharOffset,
        'progress': progress,
        'speech_rate': speechRate,
        'prepared_offline': preparedOffline ? 1 : 0,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory DocumentItem.fromMap(Map<String, Object?> map) => DocumentItem(
        id: map['id'] as int?,
        title: map['title'] as String,
        localPath: map['local_path'] as String,
        extension: map['extension'] as String,
        totalPages: map['total_pages'] as int,
        currentPage: map['current_page'] as int,
        currentSentence: map['current_sentence'] as int,
        currentCharOffset: map['current_char_offset'] as int,
        progress: (map['progress'] as num).toDouble(),
        speechRate: (map['speech_rate'] as num).toDouble(),
        preparedOffline: (map['prepared_offline'] as int) == 1,
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  DocumentItem copyWith({
    int? id,
    int? currentPage,
    int? currentSentence,
    int? currentCharOffset,
    double? progress,
    double? speechRate,
    bool? preparedOffline,
    DateTime? updatedAt,
  }) =>
      DocumentItem(
        id: id ?? this.id,
        title: title,
        localPath: localPath,
        extension: extension,
        totalPages: totalPages,
        currentPage: currentPage ?? this.currentPage,
        currentSentence: currentSentence ?? this.currentSentence,
        currentCharOffset: currentCharOffset ?? this.currentCharOffset,
        progress: progress ?? this.progress,
        speechRate: speechRate ?? this.speechRate,
        preparedOffline: preparedOffline ?? this.preparedOffline,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
