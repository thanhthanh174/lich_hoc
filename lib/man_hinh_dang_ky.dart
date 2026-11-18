import 'package:flutter/material.dart';

import 'dich_vu_api.dart';
import 'man_hinh_chinh.dart';

class ManHinhDangKy extends StatefulWidget {
  const ManHinhDangKy({super.key});

  @override
  State<ManHinhDangKy> createState() => _ManHinhDangKyState();
}

class _ManHinhDangKyState extends State<ManHinhDangKy> {
  final _khoaForm = GlobalKey<FormState>();
  final _tenDangNhap = TextEditingController();
  final _email = TextEditingController();
  final _matKhau = TextEditingController();
  final _nhapLai = TextEditingController();
  bool _dangTai = false;
  String? _thongBaoLoi;

  @override
  void dispose() {
    _tenDangNhap.dispose();
    _email.dispose();
    _matKhau.dispose();
    _nhapLai.dispose();
    super.dispose();
  }

  Future<void> _dangKy() async {
    if (!_khoaForm.currentState!.validate()) return;
    setState(() {
      _dangTai = true;
      _thongBaoLoi = null;
    });
    try {
      await DichVuApi.dangKy(
          _tenDangNhap.text.trim(), _email.text.trim(), _matKhau.text);
      // Đăng ký xong thì đăng nhập luôn cho tiện
      await DichVuApi.dangNhap(_tenDangNhap.text.trim(), _matKhau.text);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ManHinhChinh()),
          (route) => false);
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
      appBar: AppBar(title: const Text('Đăng ký tài khoản')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _khoaForm,
            child: Column(
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
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email (không bắt buộc)',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _matKhau,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu (ít nhất 6 ký tự)',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Mật khẩu phải có ít nhất 6 ký tự.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nhapLai,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nhập lại mật khẩu',
                    prefixIcon: Icon(Icons.lock_reset),
                    border: OutlineInputBorder(),
                  ),
                  onFieldSubmitted: (_) => _dangKy(),
                  validator: (v) =>
                      v != _matKhau.text ? 'Mật khẩu nhập lại không khớp.' : null,
                ),
                if (_thongBaoLoi != null) ...[
                  const SizedBox(height: 16),
                  Text(_thongBaoLoi!, style: TextStyle(color: mau.error)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _dangTai ? null : _dangKy,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _dangTai
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Đăng ký'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}