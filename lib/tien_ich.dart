import 'package:flutter/material.dart';

import 'dich_vu_api.dart';
import 'man_hinh_dang_nhap.dart';

const List<String> tenThu = [
  'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ nhật',
];

/// Đổi mã màu dạng "#2196F3" thành Color.
Color mauTuHex(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
  } catch (_) {
    return Colors.grey;
  }
}

/// Đổi TimeOfDay thành chuỗi "19:00".
String dinhDangGio(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Hiện lỗi bằng SnackBar; nếu hết phiên đăng nhập thì đưa về màn hình đăng nhập.
Future<void> xuLyLoi(BuildContext context, Object loi) async {
  if (loi is LoiApi && loi.hetPhien) {
    await DichVuApi.dangXuat();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ManHinhDangNhap()),
        (route) => false);
    return;
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(loi is LoiApi ? loi.thongBao : 'Đã xảy ra lỗi.')));
}

/// Hộp thoại xác nhận xóa. Trả về true nếu người dùng đồng ý.
Future<bool> xacNhanXoa(
    BuildContext context, String tieuDe, String noiDung) async {
  final kq = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(tieuDe),
      content: Text(noiDung),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa')),
      ],
    ),
  );
  return kq ?? false;
}

/// Thẻ bo góc dùng chung cho các mục trong danh sách.
Widget theMuc({required Widget child}) {
  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    elevation: 1,
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: child,
  );
}

/// Hiển thị khi danh sách trống: biểu tượng lớn và một dòng hướng dẫn.
Widget trangThaiRong(BuildContext context, IconData bieuTuong, String noiDung) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(bieuTuong, size: 80, color: const Color(0xFF81D4FA)),
        const SizedBox(height: 16),
        Text(noiDung,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}