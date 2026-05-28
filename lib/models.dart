import 'core/utils/json_parse.dart';

/// A menu item from the backend (`/menus`).
class Product {
  final int id;
  final String name;
  final String image;
  final int price;
  final String category; // category display name, e.g. "Coffee"
  final String description;

  Product({
    required this.id,
    required this.name,
    required this.image,
    required this.price,
    required this.category,
    required this.description,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final cat = json['category'];
    return Product(
      id: parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      image: json['image_url']?.toString() ?? '',
      price: parseDouble(json['price']).round(),
      category: cat is Map ? (cat['name']?.toString() ?? '') : '',
      description: json['description']?.toString() ?? '',
    );
  }
}

class CartItem {
  final Product product;
  final String milkType;
  final String sweetness;
  int quantity;

  CartItem({
    required this.product,
    required this.milkType,
    required this.sweetness,
    this.quantity = 1,
  });

  String get uniqueId => '${product.id}_${milkType}_$sweetness';

  /// Customizations the backend stores as a free-text note (the customer
  /// app does not yet map them onto real condiment options).
  String get note => 'Susu: $milkType, Kemanisan: $sweetness';
}

/// Maps backend status enum → Indonesian display label.
const Map<String, String> kStatusLabels = {
  'pending': 'Pesanan Diterima',
  'processing': 'Sedang Dibuat',
  'ready': 'Siap Diambil',
  'completed': 'Selesai',
  'cancelled': 'Dibatalkan',
};

/// Ordered status steps used by the tracking timeline.
const List<String> kStatusFlow = ['pending', 'processing', 'ready', 'completed'];

class Order {
  final int id;
  final List<CartItem> items;
  final int total;
  final DateTime timestamp;
  final String status; // backend enum value
  final int queueNumber;
  final String paymentMethod;
  final String paymentStatus;
  final String? qrCodeUrl;
  final String? vaNumber;
  final String? paymentChannel;

  Order({
    required this.id,
    required this.items,
    required this.total,
    required this.timestamp,
    required this.status,
    required this.queueNumber,
    required this.paymentMethod,
    required this.paymentStatus,
    this.qrCodeUrl,
    this.vaNumber,
    this.paymentChannel,
  });

  String get statusLabel => kStatusLabels[status] ?? status;

  String get estimatedTime {
    switch (status) {
      case 'completed':
        return 'Selesai';
      case 'ready':
        return 'Siap';
      case 'cancelled':
        return '-';
      default:
        return '5-7 Menit';
    }
  }

  bool get isActive => status == 'pending' || status == 'processing' || status == 'ready';

  /// Builds an order from a backend payload. [items] is supplied separately
  /// because polling responses are only used to refresh status fields.
  factory Order.fromJson(Map<String, dynamic> json, {List<CartItem> items = const []}) {
    return Order(
      id: parseInt(json['id']),
      items: items,
      total: parseDouble(json['total']).round(),
      timestamp: parseDateTime(json['created_at']) ?? DateTime.now(),
      status: json['status']?.toString() ?? 'pending',
      queueNumber: parseInt(json['queue_number']),
      paymentMethod: json['payment_method']?.toString() ?? 'cash',
      paymentStatus: json['payment_status']?.toString() ?? 'unpaid',
      qrCodeUrl: json['qr_code_url']?.toString(),
      vaNumber: json['va_number']?.toString(),
      paymentChannel: json['payment_channel']?.toString(),
    );
  }

  Order copyWith({String? status, String? paymentStatus}) => Order(
        id: id,
        items: items,
        total: total,
        timestamp: timestamp,
        status: status ?? this.status,
        queueNumber: queueNumber,
        paymentMethod: paymentMethod,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        qrCodeUrl: qrCodeUrl,
        vaNumber: vaNumber,
        paymentChannel: paymentChannel,
      );
}

/// Customer profile, sourced from `/auth/me`.
class UserProfile {
  final int id;
  final String fullName;
  final String email;
  final String? phone;
  final String role;
  final DateTime? memberSince;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.role,
    this.memberSince,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: parseInt(json['id']),
      fullName: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      role: json['role']?.toString() ?? 'customer',
      memberSince: parseDateTime(json['created_at']),
    );
  }
}
