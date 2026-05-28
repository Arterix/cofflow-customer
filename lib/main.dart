import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:async';

import 'models.dart';
import 'services/api_services.dart';
import 'core/network/api_client.dart';

final GlobalKey<NavigatorState> rootNavKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // On 401 the interceptor clears the token; bounce the user to login.
  ApiClient.onUnauthorized = () async {
    AppState.stopPolling();
    rootNavKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (r) => false,
    );
  };

  final loggedIn = await AuthService.isLoggedIn();

  runApp(CofflowApp(loggedIn: loggedIn));
}

class CofflowApp extends StatelessWidget {
  const CofflowApp({super.key, required this.loggedIn});

  final bool loggedIn;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavKey,
      title: 'Cofflow.',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F7F5),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: kBrandDark,
          primary: kBrandDark,
          secondary: kBrandAccent,
        ),
      ),
      home: loggedIn ? MainNavigation(key: AppState.navKey) : const SplashScreen(),
    );
  }
}

// --- Brand Colors ---
const kBrandDark = Color(0xFF1C2C22);
const kBrandAccent = Color(0xFFD4AF37);
const kBrandLight = Color(0xFFF7F7F5);
const kBrandMuted = Color(0xFFEEEEEB);

class AppState {
  static final GlobalKey<_MainNavigationState> navKey =
      GlobalKey<_MainNavigationState>();

  static List<CartItem> cart = [];
  static Order? currentOrder;

  static Timer? _pollTimer;

  static void changeTab(int i) => navKey.currentState?.updateIndex(i);
  static void refreshUI() => navKey.currentState?.refresh();

  static void addToCart(CartItem newItem) {
    int index = cart.indexWhere((i) => i.uniqueId == newItem.uniqueId);
    if (index != -1) {
      cart[index].quantity += newItem.quantity;
    } else {
      cart.add(newItem);
    }
    changeTab(2);
  }

  /// Sends the order to the backend. Returns the created [Order] (which holds
  /// payment fields for qris/VA flows). Throws [ApiException] on failure.
  static Future<Order> submitOrder({
    required String paymentMethod,
    String? paymentChannel,
  }) async {
    final order = await OrderService.createOrder(
      cartItems: List.from(cart),
      paymentMethod: paymentMethod,
      paymentChannel: paymentChannel,
    );
    currentOrder = order;
    cart = [];
    return order;
  }

  /// Begins tracking the active order via polling (backend has no realtime).
  static void startPolling(BuildContext context) {
    stopPolling();
    final id = currentOrder?.id;
    if (id == null) return;

    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final fresh = await OrderService.fetchOrder(id);
        currentOrder = currentOrder?.copyWith(
          status: fresh.status,
          paymentStatus: fresh.paymentStatus,
        );
        refreshUI();

        if (fresh.status == 'completed') {
          stopPolling();
          if (context.mounted) _showDoneDialog(context);
        } else if (fresh.status == 'cancelled') {
          stopPolling();
        }
      } catch (_) {
        // transient; next tick retries
      }
    });
  }

  static void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  static void _showDoneDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Sukses!', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Pesanan kamu sudah selesai. Terima kasih!'),
        actions: [
          TextButton(
            onPressed: () {
              currentOrder = null;
              refreshUI();
              Navigator.pop(ctx);
            },
            child: const Text('TUTUP',
                style: TextStyle(color: kBrandDark, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// SPLASH SCREEN
// ─────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _scale = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _controller.forward();

    Timer(const Duration(milliseconds: 2500), () {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBrandDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scale,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: kBrandAccent, borderRadius: BorderRadius.circular(32)),
                child: const Icon(LucideIcons.coffee, color: kBrandDark, size: 48),
              ),
            ),
            const SizedBox(height: 24),
            Text('Cofflow.',
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -2)),
            const SizedBox(height: 8),
            const Text('Pengalaman Kopi Berkelas',
                style: TextStyle(
                    color: kBrandAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// LOGIN SCREEN
// ─────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.signIn(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (mounted) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => MainNavigation(key: AppState.navKey)));
      }
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Positioned(top: -100, right: -100, child: _blob(kBrandAccent.withValues(alpha: 0.05))),
        Positioned(bottom: -100, left: -100, child: _blob(kBrandDark.withValues(alpha: 0.05))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: kBrandDark, borderRadius: BorderRadius.circular(28)),
              child: const Icon(LucideIcons.coffee, color: kBrandAccent, size: 40),
            ),
            const SizedBox(height: 24),
            Text('Cofflow.',
                style: GoogleFonts.plusJakartaSans(
                    color: kBrandDark,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1.5)),
            const SizedBox(height: 48),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDecoration('EMAIL'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: _inputDecoration('KATA SANDI'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _loading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: kBrandDark,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('MASUK KE FLOW',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12)),
            ),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Belum punya akun?',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              TextButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen())),
                child: const Text('DAFTAR',
                    style: TextStyle(
                        color: kBrandDark,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
              ),
            ]),
            const SizedBox(height: 8),
            const Text('DIRACIK SEJAK 2024',
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5)),
          ]),
        ),
      ]),
    );
  }

  Widget _blob(Color color) => Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1.5),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      );
}

// ─────────────────────────────────────────────────────────
// REGISTER SCREEN
// ─────────────────────────────────────────────────────────
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Nama lengkap tidak boleh kosong');
      return;
    }
    if (!_emailCtrl.text.contains('@')) {
      setState(() => _error = 'Format email tidak valid');
      return;
    }
    if (_passwordCtrl.text.length < 8) {
      setState(() => _error = 'Password minimal 8 karakter');
      return;
    }
    if (_passwordCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Password dan konfirmasi tidak cocok');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthService.register(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      if (mounted) {
        // Registration logs the user in immediately (token persisted).
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => MainNavigation(key: AppState.navKey)),
          (r) => false,
        );
      }
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Positioned(
            top: -80,
            right: -80,
            child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                    color: kBrandAccent.withValues(alpha: 0.05), shape: BoxShape.circle))),
        Positioned(
            bottom: -80,
            left: -80,
            child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                    color: kBrandDark.withValues(alpha: 0.05), shape: BoxShape.circle))),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 16),
              IconButton(
                  icon: const Icon(LucideIcons.chevronLeft, color: kBrandDark),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero),
              const SizedBox(height: 24),
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: kBrandDark, borderRadius: BorderRadius.circular(20)),
                  child: const Icon(LucideIcons.coffee, color: kBrandAccent, size: 32)),
              const SizedBox(height: 20),
              Text('Buat Akun Baru',
                  style: GoogleFonts.plusJakartaSans(
                      color: kBrandDark,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1.5)),
              const Text('Bergabung dan nikmati kopi terbaik',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 36),
              _label('NAMA LENGKAP'),
              const SizedBox(height: 8),
              TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      _inputDecoration('Contoh: Aris Setiawan', icon: LucideIcons.user)),
              const SizedBox(height: 20),
              _label('EMAIL'),
              const SizedBox(height: 8),
              TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      _inputDecoration('Contoh: aris@email.com', icon: LucideIcons.mail)),
              const SizedBox(height: 20),
              _label('NOMOR HP (OPSIONAL)'),
              const SizedBox(height: 8),
              TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration:
                      _inputDecoration('Contoh: 08123456789', icon: LucideIcons.phone)),
              const SizedBox(height: 20),
              _label('KATA SANDI'),
              const SizedBox(height: 8),
              TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscure1,
                  decoration: _inputDecoration('Minimal 8 karakter',
                      icon: LucideIcons.lock,
                      suffix: IconButton(
                          icon: Icon(_obscure1 ? LucideIcons.eyeOff : LucideIcons.eye,
                              size: 18, color: Colors.grey),
                          onPressed: () => setState(() => _obscure1 = !_obscure1)))),
              const SizedBox(height: 20),
              _label('KONFIRMASI KATA SANDI'),
              const SizedBox(height: 8),
              TextField(
                  controller: _confirmCtrl,
                  obscureText: _obscure2,
                  decoration: _inputDecoration('Ulangi kata sandi',
                      icon: LucideIcons.lock,
                      suffix: IconButton(
                          icon: Icon(_obscure2 ? LucideIcons.eyeOff : LucideIcons.eye,
                              size: 18, color: Colors.grey),
                          onPressed: () => setState(() => _obscure2 = !_obscure2)))),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade100)),
                    child: Row(children: [
                      Icon(LucideIcons.alertCircle, color: Colors.red.shade400, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_error!,
                              style: TextStyle(color: Colors.red.shade600, fontSize: 12))),
                    ])),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _loading ? null : _register,
                style: ElevatedButton.styleFrom(
                    backgroundColor: kBrandDark,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('BUAT AKUN',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12)),
              ),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('Sudah punya akun?',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('MASUK',
                        style: TextStyle(
                            color: kBrandDark,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1))),
              ]),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.5));

  InputDecoration _inputDecoration(String hint,
          {required IconData icon, Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: Colors.grey),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      );
}

// ─────────────────────────────────────────────────────────
// MAIN NAVIGATION
// ─────────────────────────────────────────────────────────
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  void updateIndex(int i) => setState(() => _currentIndex = i);
  void refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final screens = [
      const HomeScreen(),
      const OrdersScreen(),
      const CartScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        height: 90,
        decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFF1F1F1)))),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: updateIndex,
          elevation: 0,
          backgroundColor: Colors.transparent,
          selectedItemColor: kBrandDark,
          unselectedItemColor: Colors.grey.shade400,
          selectedFontSize: 9,
          unselectedFontSize: 9,
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(LucideIcons.home), label: 'HOME'),
            BottomNavigationBarItem(icon: Icon(LucideIcons.shoppingBag), label: 'PESANAN'),
            BottomNavigationBarItem(icon: Icon(LucideIcons.coffee), label: 'KERANJANG'),
            BottomNavigationBarItem(icon: Icon(LucideIcons.user), label: 'PROFIL'),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// STICKY HEADER
// ─────────────────────────────────────────────────────────
class StickyHeader extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final bool hasNotification;
  const StickyHeader(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon,
      this.hasNotification = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10,
          bottom: 20,
          left: 24,
          right: 24),
      decoration: BoxDecoration(
          color: kBrandLight.withValues(alpha: 0.9),
          border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.05)))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: kBrandDark,
                  letterSpacing: -1)),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 1)),
        ]),
        Stack(children: [
          Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFF1F1F1))),
              child: Icon(icon, size: 18, color: kBrandDark)),
          if (hasNotification)
            Positioned(
                top: 10,
                right: 10,
                child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: kBrandAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2)))),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────
// HOME SCREEN — fetch menus from backend
// ─────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _activeCategory = 'Semua';
  List<String> _categories = ['Semua'];
  List<Product> _products = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadProducts();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await ProductService.fetchCategories();
      if (mounted) {
        setState(() => _categories = cats);
      }
    } catch (_) {
      // keep default ['Semua']
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await ProductService.fetchByCategory(_activeCategory);
      if (mounted) {
        setState(() {
          _products = products;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const StickyHeader(
          title: 'Cofflow.',
          subtitle: 'Kopi Terbaik Untukmu',
          icon: LucideIcons.bell,
          hasNotification: true),
      Expanded(
          child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              decoration: InputDecoration(
                  prefixIcon:
                      const Icon(LucideIcons.search, size: 20, color: Colors.grey),
                  hintText: 'Cari kopi favoritmu...',
                  hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(100),
                      borderSide: BorderSide.none)),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 24),
              itemCount: _categories.length,
              itemBuilder: (ctx, i) {
                final cat = _categories[i];
                final isActive = _activeCategory == cat;
                return GestureDetector(
                  onTap: () {
                    setState(() => _activeCategory = cat);
                    _loadProducts();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                        color: isActive ? kBrandDark : Colors.white,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                            color: isActive ? kBrandDark : const Color(0xFFF1F1F1)),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                    color: kBrandDark.withValues(alpha: 0.2),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5))
                              ]
                            : null),
                    alignment: Alignment.center,
                    child: Text(cat,
                        style: TextStyle(
                            color: isActive ? Colors.white : Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Pilihan Populer',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: kBrandDark)),
              TextButton(
                  onPressed: () {},
                  child: const Text('Lihat Semua',
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
            ]),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: kBrandDark)))
          else if (_error != null)
            Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                    child: Column(children: [
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  TextButton(
                      onPressed: _loadProducts,
                      child: const Text('Coba lagi',
                          style: TextStyle(
                              color: kBrandDark, fontWeight: FontWeight.bold))),
                ])))
          else if (_products.isEmpty)
            const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                    child: Text('Belum ada menu di kategori ini',
                        style: TextStyle(color: Colors.grey))))
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  childAspectRatio: 0.8),
              itemCount: _products.length,
              itemBuilder: (ctx, i) => ProductCard(product: _products[i]),
            ),
          const SizedBox(height: 32),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(28),
            width: double.infinity,
            decoration: BoxDecoration(
                color: kBrandDark, borderRadius: BorderRadius.circular(32)),
            child: Stack(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('FLOW REWARDS',
                    style: TextStyle(
                        color: kBrandAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                        letterSpacing: 2)),
                const SizedBox(height: 8),
                const Text('Klaim kopi gratis kamu',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kBrandAccent,
                      foregroundColor: kBrandDark,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shape:
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
                  child: const Text('CEK POIN',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ]),
              const Positioned(
                  right: -30,
                  bottom: -30,
                  child: Opacity(
                      opacity: 0.1,
                      child: Icon(LucideIcons.coffee, size: 140, color: kBrandAccent))),
            ]),
          ),
          const SizedBox(height: 32),
        ]),
      )),
    ]);
  }
}

class ProductCard extends StatelessWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => DetailScreen(product: product))),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFF8F8F8))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _menuImage(product.image))),
          const SizedBox(height: 12),
          Text(product.name,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13, color: kBrandDark)),
          Text(product.category.toUpperCase(),
              style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
                  letterSpacing: 1)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Rp${product.price ~/ 1000}K',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14, color: kBrandDark)),
            Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: kBrandDark, borderRadius: BorderRadius.circular(10)),
                child: const Icon(LucideIcons.plus, color: Colors.white, size: 16)),
          ]),
        ]),
      ),
    );
  }
}

/// Network image with a graceful placeholder for empty/broken urls.
Widget _menuImage(String url, {double? width, double? height}) {
  Widget placeholder = Container(
    width: width ?? double.infinity,
    height: height,
    color: kBrandMuted,
    alignment: Alignment.center,
    child: const Icon(LucideIcons.coffee, color: Colors.grey, size: 32),
  );
  if (url.isEmpty) return placeholder;
  return Image.network(
    url,
    width: width ?? double.infinity,
    height: height,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => placeholder,
  );
}

// DetailScreen — addToCart unchanged (milk/sweetness → order note)
class DetailScreen extends StatefulWidget {
  final Product product;
  const DetailScreen({super.key, required this.product});
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  String _milkType = 'Oat';
  String _sweetness = 'Normal';
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        Expanded(
            child: SingleChildScrollView(
                child: Column(children: [
          Stack(children: [
            _menuImage(widget.product.image, height: 400),
            Positioned(
                top: 50,
                left: 24,
                child: CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    child: IconButton(
                        icon: const Icon(LucideIcons.chevronLeft, color: Colors.white),
                        onPressed: () => Navigator.pop(context)))),
            Positioned(
                bottom: 30,
                left: 24,
                right: 24,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.product.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -1)),
                  const SizedBox(height: 8),
                  Text(widget.product.description,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
                ])),
          ]),
          Padding(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Jenis Susu', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                    children: ['Normal', 'Oat', 'Almond']
                        .map((m) => Expanded(
                            child: GestureDetector(
                                onTap: () => setState(() => _milkType = m),
                                child: Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    height: 44,
                                    decoration: BoxDecoration(
                                        color: _milkType == m ? kBrandDark : Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border:
                                            Border.all(color: const Color(0xFFF1F1F1))),
                                    alignment: Alignment.center,
                                    child: Text(m,
                                        style: TextStyle(
                                            color: _milkType == m
                                                ? Colors.white
                                                : Colors.grey,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12))))))
                        .toList()),
                const SizedBox(height: 32),
                const Text('Kemanisan', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                    children: ['Less', 'Normal', 'Extra']
                        .map((l) => Expanded(
                            child: GestureDetector(
                                onTap: () => setState(() => _sweetness = l),
                                child: Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    height: 44,
                                    decoration: BoxDecoration(
                                        color:
                                            _sweetness == l ? kBrandDark : Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border:
                                            Border.all(color: const Color(0xFFF1F1F1))),
                                    alignment: Alignment.center,
                                    child: Text(l,
                                        style: TextStyle(
                                            color: _sweetness == l
                                                ? Colors.white
                                                : Colors.grey,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12))))))
                        .toList()),
              ])),
        ]))),
        Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF1F1F1)))),
            child: Row(children: [
              Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      color: kBrandMuted, borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    IconButton(
                        icon: const Icon(LucideIcons.minus, size: 18),
                        onPressed: () =>
                            setState(() => _quantity = (_quantity - 1).clamp(1, 99))),
                    Text('$_quantity',
                        style:
                            const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    IconButton(
                        icon: const Icon(LucideIcons.plus, size: 18),
                        onPressed: () => setState(() => _quantity++)),
                  ])),
              const SizedBox(width: 16),
              Expanded(
                  child: ElevatedButton(
                      onPressed: () {
                        AppState.addToCart(CartItem(
                          product: widget.product,
                          milkType: _milkType,
                          sweetness: _sweetness,
                          quantity: _quantity,
                        ));
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: kBrandDark,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20))),
                      child: Text(
                          'TAMBAH • Rp${(widget.product.price * _quantity) ~/ 1000}K',
                          style: const TextStyle(fontWeight: FontWeight.bold)))),
            ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────
// CART SCREEN — checkout with payment picker
// ─────────────────────────────────────────────────────────
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _placing = false;

  Future<void> _checkout() async {
    final choice = await showModalBottomSheet<_PaymentChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const PaymentMethodSheet(),
    );
    if (choice == null || !mounted) return;

    setState(() => _placing = true);
    try {
      final order = await AppState.submitOrder(
        paymentMethod: choice.method,
        paymentChannel: choice.channel,
      );
      if (!mounted) return;
      setState(() => _placing = false);

      if (order.paymentMethod == 'cash') {
        AppState.changeTab(1);
        AppState.startPolling(context);
      } else {
        // QRIS / VA: show payment instructions, then poll.
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => PaymentScreen(order: order)));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _placing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat pesanan: ${e.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    int subtotal = AppState.cart.fold(0, (s, i) => s + i.product.price * i.quantity);

    return Column(children: [
      StickyHeader(
          title: 'keranjangku.',
          subtitle: '${AppState.cart.length} Produk',
          icon: LucideIcons.shoppingBag),
      Expanded(
          child: AppState.cart.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(LucideIcons.shoppingBag, size: 64, color: Colors.grey.shade200),
                  const SizedBox(height: 16),
                  const Text('Keranjangmu kosong',
                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  itemCount: AppState.cart.length,
                  itemBuilder: (ctx, i) {
                    final item = AppState.cart[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: const Color(0xFFF1F1F1))),
                      child: Row(children: [
                        ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: _menuImage(item.product.image,
                                width: 70, height: 70)),
                        const SizedBox(width: 16),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(item.product.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, color: kBrandDark)),
                              Text('${item.milkType} | ${item.sweetness}',
                                  style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text('Rp${(item.product.price * item.quantity) ~/ 1000}K',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 13)),
                            ])),
                        Column(children: [
                          IconButton(
                              icon: const Icon(LucideIcons.plus, size: 16),
                              onPressed: () => setState(() => item.quantity++)),
                          Text('${item.quantity}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                              icon: const Icon(LucideIcons.minus, size: 16),
                              onPressed: () => setState(() =>
                                  item.quantity = (item.quantity - 1).clamp(1, 99))),
                        ]),
                        IconButton(
                            icon: const Icon(LucideIcons.trash2,
                                color: Colors.red, size: 18),
                            onPressed: () =>
                                setState(() => AppState.cart.removeAt(i))),
                      ]),
                    );
                  },
                )),
      if (AppState.cart.isNotEmpty)
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
              color: kBrandMuted,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
          child: Column(children: [
            _summaryRow('SUBTOTAL', 'Rp${subtotal ~/ 1000}K'),
            const SizedBox(height: 4),
            const Text('Pajak & total final dihitung oleh server',
                style: TextStyle(fontSize: 9, color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _placing ? null : _checkout,
              style: ElevatedButton.styleFrom(
                  backgroundColor: kBrandDark,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              child: _placing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('PILIH PEMBAYARAN',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ),
          ]),
        ),
    ]);
  }

  Widget _summaryRow(String label, String value) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ]);
}

// ─────────────────────────────────────────────────────────
// PAYMENT METHOD PICKER (bottom sheet)
// ─────────────────────────────────────────────────────────
class _PaymentChoice {
  const _PaymentChoice(this.method, {this.channel});
  final String method; // cash | qris | virtual_account
  final String? channel; // bca | bni | bri | mandiri
}

class PaymentMethodSheet extends StatefulWidget {
  const PaymentMethodSheet({super.key});
  @override
  State<PaymentMethodSheet> createState() => _PaymentMethodSheetState();
}

class _PaymentMethodSheetState extends State<PaymentMethodSheet> {
  String _method = 'cash';
  String _channel = 'bca';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        const Align(
            alignment: Alignment.centerLeft,
            child: Text('Metode Pembayaran',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
        const SizedBox(height: 20),
        _option('cash', 'Tunai (Cash)', LucideIcons.banknote),
        _option('qris', 'QRIS', LucideIcons.qrCode),
        _option('virtual_account', 'Virtual Account', LucideIcons.creditCard),
        if (_method == 'virtual_account') ...[
          const SizedBox(height: 12),
          Align(
              alignment: Alignment.centerLeft,
              child: Text('PILIH BANK',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                      letterSpacing: 1))),
          const SizedBox(height: 8),
          Wrap(
              spacing: 8,
              children: ['bca', 'bni', 'bri', 'mandiri'].map((b) {
                final active = _channel == b;
                return ChoiceChip(
                  label: Text(b.toUpperCase()),
                  selected: active,
                  onSelected: (_) => setState(() => _channel = b),
                  selectedColor: kBrandDark,
                  labelStyle: TextStyle(
                      color: active ? Colors.white : kBrandDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 11),
                  backgroundColor: kBrandMuted,
                );
              }).toList()),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Navigator.pop(
              context,
              _PaymentChoice(_method,
                  channel: _method == 'virtual_account' ? _channel : null)),
          style: ElevatedButton.styleFrom(
              backgroundColor: kBrandDark,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: const Text('PESAN SEKARANG',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _option(String value, String label, IconData icon) {
    final active = _method == value;
    return GestureDetector(
      onTap: () => setState(() => _method = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: active ? kBrandDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: active ? kBrandDark : const Color(0xFFF1F1F1))),
        child: Row(children: [
          Icon(icon, color: active ? kBrandAccent : kBrandDark, size: 20),
          const SizedBox(width: 16),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: active ? Colors.white : kBrandDark,
                      fontWeight: FontWeight.bold))),
          if (active) const Icon(LucideIcons.check, color: kBrandAccent, size: 18),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// PAYMENT SCREEN (QRIS / Virtual Account)
// ─────────────────────────────────────────────────────────
class PaymentScreen extends StatefulWidget {
  final Order order;
  const PaymentScreen({super.key, required this.order});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  Timer? _timer;
  String _paymentStatus = 'unpaid';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _paymentStatus = widget.order.paymentStatus;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_checking) return;
    _checking = true;
    try {
      final fresh = await OrderService.fetchOrder(widget.order.id);
      if (!mounted) return;
      setState(() => _paymentStatus = fresh.paymentStatus);
      AppState.currentOrder =
          AppState.currentOrder?.copyWith(paymentStatus: fresh.paymentStatus, status: fresh.status);
      if (fresh.paymentStatus == 'paid') {
        _timer?.cancel();
        _onPaid();
      }
    } catch (_) {
      // retry next tick
    } finally {
      _checking = false;
    }
  }

  void _onPaid() {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    AppState.changeTab(1);
    AppState.startPolling(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Pembayaran diterima. Pesanan diproses!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isQris = order.paymentMethod == 'qris';
    final paid = _paymentStatus == 'paid';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBrandLight,
        elevation: 0,
        foregroundColor: kBrandDark,
        title: Text(isQris ? 'Pembayaran QRIS' : 'Virtual Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF1F1F1))),
            child: Column(children: [
              Text('Antrean #${order.queueNumber}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: kBrandDark)),
              const SizedBox(height: 4),
              Text('Total: Rp${order.total ~/ 1000}K',
                  style: const TextStyle(color: Colors.grey)),
            ]),
          ),
          const SizedBox(height: 24),
          if (isQris)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFF1F1F1))),
              child: Column(children: [
                const Text('Pindai kode QRIS',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (order.qrCodeUrl != null && order.qrCodeUrl!.isNotEmpty)
                  Image.network(order.qrCodeUrl!,
                      width: 220,
                      height: 220,
                      errorBuilder: (_, _, _) => const Icon(LucideIcons.qrCode,
                          size: 180, color: kBrandDark))
                else
                  const Icon(LucideIcons.qrCode, size: 180, color: kBrandDark),
              ]),
            )
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFF1F1F1))),
              child: Column(children: [
                Text('${(order.paymentChannel ?? '').toUpperCase()} Virtual Account',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SelectableText(order.vaNumber ?? '-',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: kBrandDark)),
                const SizedBox(height: 8),
                const Text('Transfer ke nomor VA di atas',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ]),
            ),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(paid ? LucideIcons.checkCircle2 : LucideIcons.clock,
                color: paid ? Colors.green : kBrandAccent, size: 18),
            const SizedBox(width: 8),
            Text(paid ? 'Pembayaran diterima' : 'Menunggu pembayaran...',
                style: TextStyle(
                    color: paid ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _checking ? null : _poll,
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                side: const BorderSide(color: kBrandDark),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: const Text('CEK STATUS PEMBAYARAN',
                style: TextStyle(
                    color: kBrandDark, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// ORDERS SCREEN — status from polling
// ─────────────────────────────────────────────────────────
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (AppState.currentOrder == null) {
      return Column(children: [
        const StickyHeader(
            title: 'status.', subtitle: 'Lacak Pesananmu', icon: LucideIcons.timer),
        Expanded(
            child: Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(LucideIcons.coffee, size: 64, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          const Text('Belum ada pesanan aktif',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ]))),
      ]);
    }

    final order = AppState.currentOrder!;
    final currentIdx = kStatusFlow.indexOf(order.status);
    final cancelled = order.status == 'cancelled';

    return Column(children: [
      StickyHeader(
          title: 'status pesanan.',
          subtitle: 'Antrean #${order.queueNumber}',
          icon: LucideIcons.coffee),
      Expanded(
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Row(children: [
            Expanded(child: _infoCard('ESTIMASI', order.estimatedTime, dark: false)),
            const SizedBox(width: 16),
            Expanded(child: _infoCard('ANTREAN', '${order.queueNumber}', dark: true)),
          ]),
          const SizedBox(height: 40),
          if (cancelled)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20)),
              child: const Row(children: [
                Icon(LucideIcons.xCircle, color: Colors.red),
                SizedBox(width: 12),
                Text('Pesanan dibatalkan',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold)),
              ]),
            )
          else
            ...List.generate(
                kStatusFlow.length,
                (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Row(children: [
                        Icon(
                            currentIdx >= i
                                ? LucideIcons.checkCircle2
                                : LucideIcons.circle,
                            color: currentIdx >= i
                                ? kBrandAccent
                                : Colors.grey.shade300,
                            size: 24),
                        const SizedBox(width: 24),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(kStatusLabels[kStatusFlow[i]] ?? kStatusFlow[i],
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: currentIdx >= i
                                          ? kBrandDark
                                          : Colors.grey)),
                              Text(
                                  currentIdx == i
                                      ? 'Sedang diproses...'
                                      : i < currentIdx
                                          ? 'Selesai'
                                          : 'Belum diproses',
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.grey)),
                            ]),
                      ]),
                    )),
        ]),
      )),
    ]);
  }

  Widget _infoCard(String label, String value, {required bool dark}) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: dark ? kBrandDark : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: dark ? null : Border.all(color: const Color(0xFFF1F1F1))),
        child: Column(children: [
          Text(label,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: dark ? Colors.white54 : Colors.grey)),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: dark ? Colors.white : kBrandDark)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────
// PROFILE SCREEN — data from /auth/me + order history
// ─────────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _showHistory = false;
  UserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await ProfileService.fetchProfile();
      if (mounted) {
        setState(() {
          _profile = UserProfile.fromJson(data);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showHistory) return _historyView();

    return Column(children: [
      const StickyHeader(
          title: 'profilku.', subtitle: 'Informasi Akun', icon: LucideIcons.user),
      Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kBrandDark))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    const CircleAvatar(
                        radius: 50,
                        backgroundColor: kBrandMuted,
                        child: Icon(LucideIcons.user, size: 44, color: kBrandDark)),
                    const SizedBox(height: 16),
                    Text(_profile?.fullName ?? '—',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(
                        'MEMBER ${(_profile?.role ?? '').toUpperCase()} '
                        'SEJAK ${_profile?.memberSince?.year ?? ''}',
                        style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 1)),
                    const SizedBox(height: 32),
                    Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                            color: kBrandDark,
                            borderRadius: BorderRadius.circular(32)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('KONTAK',
                                  style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1)),
                              const SizedBox(height: 12),
                              _contactRow(LucideIcons.mail, _profile?.email ?? '—'),
                              const SizedBox(height: 8),
                              _contactRow(LucideIcons.phone,
                                  (_profile?.phone?.isNotEmpty ?? false)
                                      ? _profile!.phone!
                                      : 'Belum diisi'),
                            ])),
                    const SizedBox(height: 32),
                    _menuItem('Riwayat Pesanan', LucideIcons.history,
                        () => setState(() => _showHistory = true)),
                    _menuItem('Pengaturan', LucideIcons.settings, () {}),
                    _menuItem('Bantuan', LucideIcons.helpCircle, () {}),
                    _menuItem('Keluar', LucideIcons.logOut, () async {
                      AppState.stopPolling();
                      await AuthService.signOut();
                      if (mounted) {
                        Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (r) => false);
                      }
                    }, color: Colors.red),
                  ]),
                )),
    ]);
  }

  Widget _contactRow(IconData icon, String text) => Row(children: [
        Icon(icon, color: kBrandAccent, size: 16),
        const SizedBox(width: 12),
        Expanded(
            child: Text(text,
                style: const TextStyle(color: Colors.white, fontSize: 13))),
      ]);

  Widget _historyView() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: OrderService.fetchHistory(),
      builder: (ctx, snap) {
        return Column(children: [
          Container(
              padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 10,
                  bottom: 20,
                  left: 20,
                  right: 24),
              decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                      bottom:
                          BorderSide(color: Colors.black.withValues(alpha: 0.05)))),
              child: Row(children: [
                IconButton(
                    icon: const Icon(LucideIcons.chevronLeft),
                    onPressed: () => setState(() => _showHistory = false)),
                const SizedBox(width: 8),
                const Text('riwayat.',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ])),
          Expanded(
              child: snap.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator(color: kBrandDark))
                  : (snap.data?.isEmpty ?? true)
                      ? const Center(child: Text('Belum ada riwayat'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(24),
                          itemCount: snap.data!.length,
                          itemBuilder: (ctx, i) {
                            final order = snap.data![i];
                            final status = order['status']?.toString() ?? '';
                            final created =
                                order['created_at']?.toString() ?? '';
                            final total =
                                (double.tryParse(order['total']?.toString() ?? '0') ??
                                        0)
                                    .round();
                            return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                    color: kBrandMuted,
                                    borderRadius: BorderRadius.circular(24)),
                                child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('Antrean #${order['queue_number'] ?? '-'}',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold)),
                                            Text(
                                                created.isNotEmpty
                                                    ? created.split('T')[0]
                                                    : '',
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey)),
                                          ]),
                                      Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text('Rp${total ~/ 1000}K',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold)),
                                            Text(kStatusLabels[status] ?? status,
                                                style: const TextStyle(
                                                    color: kBrandAccent,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold)),
                                          ]),
                                    ]));
                          })),
        ]);
      },
    );
  }

  Widget _menuItem(String title, IconData icon, VoidCallback onTap, {Color? color}) =>
      GestureDetector(
          onTap: onTap,
          child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF8F8F8))),
              child: Row(children: [
                Icon(icon, size: 20, color: color ?? kBrandDark),
                const SizedBox(width: 16),
                Expanded(
                    child: Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: color ?? kBrandDark))),
                const Icon(LucideIcons.chevronRight, color: Colors.grey, size: 18),
              ])));
}
