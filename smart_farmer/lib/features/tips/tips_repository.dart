import 'package:cloud_firestore/cloud_firestore.dart';

/// A farming tip document from the `tips` collection.
class Tip {
  final String id;
  final String title;
  final String body;
  final String category;
  final DateTime createdAt;

  const Tip({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.createdAt,
  });

  factory Tip.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Tip(
      id: doc.id,
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      category: d['category'] as String? ?? 'General',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// SQLite / cache serialisation.
  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'body': body,
    'category': category,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Tip.fromMap(Map<String, dynamic> m) => Tip(
    id: m['id'] as String,
    title: m['title'] as String? ?? '',
    body: m['body'] as String? ?? '',
    category: m['category'] as String? ?? 'General',
    createdAt:
        DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}

/// Reads the public `tips` collection.
class TipsRepository {
  final FirebaseFirestore _db;

  TipsRepository({FirebaseFirestore? firestore})
    : _db =
          firestore ??
          FirebaseFirestore.instanceFor(
            app: FirebaseFirestore.instance.app,
            databaseId: 'smart-farmer-kenya',
          );

  CollectionReference<Map<String, dynamic>> get _tips => _db.collection('tips');

  /// Fetch all tips, optionally filtered by [category].
  Future<List<Tip>> fetchTips({String? category}) async {
    Query<Map<String, dynamic>> query = _tips.orderBy(
      'createdAt',
      descending: true,
    );
    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }
    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Tip.fromDoc(doc)).toList();
  }

  /// Fetch distinct categories.
  Future<List<String>> fetchCategories() async {
    final snapshot = await _tips.get();
    final cats = <String>{};
    for (final doc in snapshot.docs) {
      final cat = doc.data()['category'] as String?;
      if (cat != null && cat.isNotEmpty) cats.add(cat);
    }
    return cats.toList()..sort();
  }
}
