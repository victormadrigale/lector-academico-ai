class ReaderBookmark {
  final int? id;
  final int documentId;
  final int page;
  final int sentenceIndex;
  final String excerpt;
  final String note;
  final String category;
  final DateTime createdAt;

  const ReaderBookmark({
    this.id,
    required this.documentId,
    required this.page,
    required this.sentenceIndex,
    required this.excerpt,
    required this.note,
    required this.category,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'document_id': documentId,
        'page': page,
        'sentence_index': sentenceIndex,
        'excerpt': excerpt,
        'note': note,
        'category': category,
        'created_at': createdAt.toIso8601String(),
      };

  factory ReaderBookmark.fromMap(Map<String, Object?> map) => ReaderBookmark(
        id: map['id'] as int?,
        documentId: map['document_id'] as int,
        page: map['page'] as int,
        sentenceIndex: map['sentence_index'] as int,
        excerpt: map['excerpt'] as String,
        note: map['note'] as String,
        category: map['category'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
