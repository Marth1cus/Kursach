import 'package:flutter/material.dart';

import '../styles/app_styles.dart';

/// Заявка клиента на бронирование пары обуви.
class Order {
  final int id;
  final int userId;
  final String userName;
  final int shoeId;
  final String shoeName;
  final String shoeBrand;
  final String shoeImage;
  final int shoePrice;
  final String size;
  final String phone;
  final String comment;
  final String status;
  final String adminComment;
  final bool isNew;
  final String createdAt;
  final String updatedAt;

  const Order({
    required this.id,
    required this.userId,
    required this.userName,
    required this.shoeId,
    required this.shoeName,
    required this.shoeBrand,
    required this.shoeImage,
    required this.shoePrice,
    required this.size,
    required this.phone,
    required this.comment,
    required this.status,
    required this.adminComment,
    required this.isNew,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPending => status == 'pending';

  String get statusLabel =>
      const {'pending': 'На рассмотрении', 'approved': 'Одобрена', 'rejected': 'Отклонена'}[status]!;

  Color get statusColor =>
      const {'pending': AppColors.warning, 'approved': AppColors.success, 'rejected': AppColors.danger}[status]!;

  IconData get statusIcon => const {
    'pending': Icons.hourglass_top_rounded,
    'approved': Icons.check_circle_rounded,
    'rejected': Icons.cancel_rounded,
  }[status]!;

  factory Order.fromJson(Map<String, dynamic> j) => Order(
    id: j['id'] as int,
    userId: j['user_id'] as int,
    userName: j['user_name'] as String,
    shoeId: j['shoe_id'] as int,
    shoeName: j['shoe_name'] as String,
    shoeBrand: j['shoe_brand'] as String,
    shoeImage: (j['shoe_image'] ?? '') as String,
    shoePrice: j['shoe_price'] as int,
    size: j['size'] as String,
    phone: j['phone'] as String,
    comment: (j['comment'] ?? '') as String,
    status: j['status'] as String,
    adminComment: (j['admin_comment'] ?? '') as String,
    isNew: (j['is_new'] ?? false) as bool,
    createdAt: j['created_at'] as String,
    updatedAt: j['updated_at'] as String,
  );
}
