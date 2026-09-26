/// Отзыв о модели обуви.
class Review {
  final int id;
  final int shoeId;
  final int userId;
  final String userName;
  final int rating;
  final String text;
  final String createdAt;

  const Review({
    required this.id,
    required this.shoeId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.text,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> j) => Review(
    id: j['id'] as int,
    shoeId: j['shoe_id'] as int,
    userId: j['user_id'] as int,
    userName: j['user_name'] as String,
    rating: j['rating'] as int,
    text: (j['text'] ?? '') as String,
    createdAt: (j['created_at'] ?? '') as String,
  );
}
