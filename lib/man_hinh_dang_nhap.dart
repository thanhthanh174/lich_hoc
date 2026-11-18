import 'package:flutter/material.dart';

import 'dich_vu_api.dart';
import 'man_hinh_chinh.dart';
import 'man_hinh_dang_ky.dart';

class ManHinhDangNhap extends StatefulWidget {
  const ManHinhDangNhap({super.key});

  @override
  State<ManHinhDangNhap> createState() => _ManHinhDangNhapState();
}

class _ManHinhDangNhapState extends State<ManHinhDangNhap> {
  final _khoaForm = GlobalKey<FormState>();
  final _tenDangNhap = TextEditingController();
  final _matKhau = TextEditingController();
  bool _dangTai = false;
  bool _anMatKhau = true;
  String? _thongBaoLoi;

  @override
  void dispose() {
    _tenDangNhap.dispose();
    _matKhau.dispose();
    super.dispose();
  }

  Future<void> _dangNhap() async {
    if (!_khoaForm.currentState!.validate()) return;
    setState(() {
      _dangTai = true;
      _thongBaoLoi = null;
    });
    try {
      await DichVuApi.dangNhap(_tenDangNhap.text.trim(), _matKhau.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ManHinhChinh()));
    } on LoiApi catch (loi) {
      if (!mounted) return;
      setState(() => _thongBaoLoi = loi.thongBao);
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mau = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0288D1), Color(0xFF81D4FA)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 44,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.calendar_month,
                        size: 48, color: Color(0xFF039BE5)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Lịch học thông minh',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Kế hoạch học tập dành riêng cho bạn',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 28),
                  Card(
                    elevation: 4,
                    color: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _khoaForm,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _tenDangNhap,
                              decoration: const InputDecoration(
                                labelText: 'Tên đăng nhập',
                                prefixIcon: Icon(Icons.person_outline),
                                border: OutlineInputBorder(),
                              ),
                              textInputAction: TextInputAction.next,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Vui lòng nhập tên đăng nhập.'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _matKhau,
                              obscureText: _anMatKhau,
                              decoration: InputDecoration(
                                labelText: 'Mật khẩu',
                                prefixIcon: const Icon(Icons.lock_outline),
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(_anMatKhau
                                      ? Icons.visibility_off
                                      : Icons.visibility),
                                  onPressed: () =>
                                      setState(() => _anMatKhau = !_anMatKhau),
                                ),
                              ),
                              onFieldSubmitted: (_) => _dangNhap(),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Vui lòng nhập mật khẩu.'
                                  : null,
                            ),
                            if (_thongBaoLoi != null) ...[
                              const SizedBox(height: 16),
                              Text(_thongBaoLoi!,
                                  style: TextStyle(color: mau.error)),
                            ],
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: _dangTai ? null : _dangNhap,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: _dangTai
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Text('Đăng nhập'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _dangTai
                                  ? null
                                  : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const ManHinhDangKy())),
                              child: const Text('Chưa có tài khoản? Đăng ký'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}