import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dich_vu_api.dart';
import 'man_hinh_chinh.dart';
import 'man_hinh_dang_nhap.dart';

// Bảng màu chủ đạo: light blue
const Color mauChinh = Color(0xFF039BE5);
const Color mauNenNhat = Color(0xFFE1F5FE);
const Color mauNen = Color(0xFFF3F9FD);

// Tên font khai báo trong pubspec.yaml
const String fontChinh = 'TimesNewRoman';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UngDung());
}

ThemeData _taoGiaoDien() {
  final bangMau = ColorScheme.fromSeed(seedColor: Colors.lightBlue)
      .copyWith(primary: mauChinh, onPrimary: Colors.white);

  return ThemeData(
    useMaterial3: true,
    fontFamily: fontChinh,
    colorScheme: bangMau,
    scaffoldBackgroundColor: mauNen,
    appBarTheme: const AppBarTheme(
      backgroundColor: mauChinh,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(
        fontFamily: fontChinh,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: mauNenNhat,
      labelTextStyle: WidgetStateProperty.resolveWith((trangThai) {
        final dangChon = trangThai.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: fontChinh,
          fontSize: 13,
          fontWeight: dangChon ? FontWeight.w600 : FontWeight.normal,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((trangThai) {
        final dangChon = trangThai.contains(WidgetState.selected);
        return IconThemeData(color: dangChon ? mauChinh : Colors.grey.shade600);
      }),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: mauChinh,
      foregroundColor: Colors.white,
    ),
  );
}

class UngDung extends StatelessWidget {
  const UngDung({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lịch học thông minh',
      debugShowCheckedModeBanner: false,
      theme: _taoGiaoDien(),
      home: const ManHinhKhoiDong(),
    );
  }
}

/// Kiểm tra đã có token chưa để chọn màn hình đầu tiên.
class ManHinhKhoiDong extends StatelessWidget {
  const ManHinhKhoiDong({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: DichVuApi.daDangNhap(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return snap.data! ? const ManHinhChinh() : const ManHinhDangNhap();
      },
    );
  }
}