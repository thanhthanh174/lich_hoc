import 'package:flutter/material.dart';

import 'dich_vu_api.dart';
import 'man_hinh_dang_nhap.dart';
import 'man_hinh_khung_gio.dart';
import 'man_hinh_mon_hoc.dart';
import 'tien_ich.dart';

class ManHinhChinh extends StatefulWidget {
  const ManHinhChinh({super.key});

  @override
  State<ManHinhChinh> createState() => _ManHinhChinhState();
}

class _ManHinhChinhState extends State<ManHinhChinh> {
  int _chon = 0;

  static const _tieuDe = ['Lịch học thông minh', 'Môn học', 'Khung giờ rảnh'];
  static const _cacManHinh = [
    ManHinhTongQuan(),
    ManHinhMonHoc(),
    ManHinhKhungGio(),
  ];

  Future<void> _dangXuat() async {
    await DichVuApi.dangXuat();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ManHinhDangNhap()),
        (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tieuDe[_chon]),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: _dangXuat,
          ),
        ],
      ),
      body: IndexedStack(index: _chon, children: _cacManHinh),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _chon,
        onDestinationSelected: (i) => setState(() => _chon = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), label: 'Tổng quan'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined), label: 'Môn học'),
          NavigationDestination(icon: Icon(Icons.schedule), label: 'Giờ rảnh'),
        ],
      ),
    );
  }
}

/// Màn hình tạm: sẽ thay bằng danh sách nhiệm vụ và kế hoạch ở bước sau.
class ManHinhTongQuan extends StatefulWidget {
  const ManHinhTongQuan({super.key});

  @override
  State<ManHinhTongQuan> createState() => _ManHinhTongQuanState();
}

class _ManHinhTongQuanState extends State<ManHinhTongQuan> {
  late Future<Map<String, dynamic>> _thongTin;

  @override
  void initState() {
    super.initState();
    _thongTin = _tai();
  }

  Future<Map<String, dynamic>> _tai() async {
    try {
      return await DichVuApi.layThongTin();
    } catch (loi) {
      if (mounted) await xuLyLoi(context, loi);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FutureBuilder<Map<String, dynamic>>(
        future: _thongTin,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const CircularProgressIndicator();
          }
          if (snap.hasError) {
            final loi = snap.error;
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text(loi is LoiApi ? loi.thongBao : 'Đã xảy ra lỗi.',
                  textAlign: TextAlign.center),
            );
          }
          final du = snap.data!;
          return Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Xin chào, ${du['username']}!',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text(
                      'Số giờ học tối đa mỗi ngày: ${du['so_gio_hoc_toi_da_moi_ngay']} giờ'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}