import 'package:flutter/material.dart';

import 'dich_vu_api.dart';
import 'tien_ich.dart';

class ManHinhKhungGio extends StatefulWidget {
  const ManHinhKhungGio({super.key});

  @override
  State<ManHinhKhungGio> createState() => _ManHinhKhungGioState();
}

class _ManHinhKhungGioState extends State<ManHinhKhungGio> {
  List<dynamic> _ds = [];
  bool _dangTai = true;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _tai();
  }

  Future<void> _tai() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final ds = await DichVuApi.layDanhSach('/api/khung-gio-ranh/');
      if (!mounted) return;
      setState(() => _ds = ds);
    } catch (loi) {
      if (!mounted) return;
      if (loi is LoiApi && loi.hetPhien) {
        await xuLyLoi(context, loi);
        return;
      }
      setState(() => _loi = loi is LoiApi ? loi.thongBao : 'Đã xảy ra lỗi.');
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  Future<void> _them() async {
    final du = await showDialog<Map<String, dynamic>>(
        context: context, builder: (_) => const _HopThoaiGio());
    if (du == null) return;
    try {
      await DichVuApi.tao('/api/khung-gio-ranh/', du);
      await _tai();
    } catch (loi) {
      if (mounted) await xuLyLoi(context, loi);
    }
  }

  Future<void> _sua(Map<String, dynamic> khung) async {
    final du = await showDialog<Map<String, dynamic>>(
        context: context, builder: (_) => _HopThoaiGio(khung: khung));
    if (du == null) return;
    try {
      await DichVuApi.capNhat('/api/khung-gio-ranh/${khung['id']}/', du);
      await _tai();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã cập nhật khung giờ.')));
      }
    } catch (loi) {
      if (mounted) await xuLyLoi(context, loi);
    }
  }

  Future<void> _xoa(Map<String, dynamic> khung) async {
    final dongY = await xacNhanXoa(
        context, 'Xóa khung giờ này?', 'Khung giờ rảnh sẽ bị xóa khỏi tuần.');
    if (!dongY) return;
    try {
      await DichVuApi.xoa('/api/khung-gio-ranh/${khung['id']}/');
      await _tai();
    } catch (loi) {
      if (mounted) await xuLyLoi(context, loi);
    }
  }

  String _gio(dynamic s) => (s as String).substring(0, 5);

  List<Widget> _dungDanhSach() {
    final mau = Theme.of(context).colorScheme.primary;
    final nhom = <int, List<Map<String, dynamic>>>{};
    for (final muc in _ds) {
      final m = muc as Map<String, dynamic>;
      nhom.putIfAbsent(m['thu_trong_tuan'] as int, () => []).add(m);
    }
    final ketQua = <Widget>[];
    for (var thu = 0; thu < 7; thu++) {
      final cacMuc = nhom[thu];
      if (cacMuc == null) continue;
      ketQua.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 4),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                  color: mau, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Text(tenThu[thu],
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ));
      for (final m in cacMuc) {
        ketQua.add(theMuc(
          child: ListTile(
            onTap: () => _sua(m),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE1F5FE),
              child: Icon(Icons.schedule, color: Color(0xFF039BE5)),
            ),
            title: Text(
              '${_gio(m['gio_bat_dau'])} - ${_gio(m['gio_ket_thuc'])}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: IconButton(
              tooltip: 'Xóa',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _xoa(m),
            ),
          ),
        ));
      }
    }
    return ketQua;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _them,
        icon: const Icon(Icons.add),
        label: const Text('Thêm giờ rảnh'),
      ),
      body: _noiDung(),
    );
  }

  Widget _noiDung() {
    if (_dangTai && _ds.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loi != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_loi!, textAlign: TextAlign.center)),
            OutlinedButton(onPressed: _tai, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _tai,
      child: _ds.isEmpty
          ? ListView(children: [
              const SizedBox(height: 120),
              trangThaiRong(context, Icons.schedule,
                  'Chưa có khung giờ rảnh.\nBấm "Thêm giờ rảnh" để cho app biết lúc nào bà học được.'),
            ])
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: _dungDanhSach(),
            ),
    );
  }
}

/// Hộp thoại dùng chung cho THÊM (khung = null) và SỬA (khung != null).
class _HopThoaiGio extends StatefulWidget {
  final Map<String, dynamic>? khung;
  const _HopThoaiGio({this.khung});

  @override
  State<_HopThoaiGio> createState() => _HopThoaiGioState();
}

class _HopThoaiGioState extends State<_HopThoaiGio> {
  static const _nhanNgan = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  int _thu = 0;
  TimeOfDay _batDau = const TimeOfDay(hour: 19, minute: 0);
  TimeOfDay _ketThuc = const TimeOfDay(hour: 22, minute: 0);
  String? _loi;

  bool get _laSua => widget.khung != null;

  @override
  void initState() {
    super.initState();
    final k = widget.khung;
    if (k != null) {
      final thu = k['thu_trong_tuan'];
      if (thu is int && thu >= 0 && thu <= 6) _thu = thu;
      _batDau = _docGio(k['gio_bat_dau'], _batDau);
      _ketThuc = _docGio(k['gio_ket_thuc'], _ketThuc);
    }
  }

  /// Đọc chuỗi "HH:MM:SS" thành TimeOfDay; lỗi thì dùng giá trị mặc định.
  TimeOfDay _docGio(dynamic s, TimeOfDay macDinh) {
    if (s is! String) return macDinh;
    final phan = s.split(':');
    if (phan.length < 2) return macDinh;
    final h = int.tryParse(phan[0]);
    final p = int.tryParse(phan[1]);
    if (h == null || p == null) return macDinh;
    return TimeOfDay(hour: h, minute: p);
  }

  Future<void> _chonGio(bool laBatDau) async {
    final chon = await showTimePicker(
      context: context,
      initialTime: laBatDau ? _batDau : _ketThuc,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (chon == null || !mounted) return;
    setState(() {
      _loi = null;
      if (laBatDau) {
        _batDau = chon;
      } else {
        _ketThuc = chon;
      }
    });
  }

  void _luu() {
    final bd = _batDau.hour * 60 + _batDau.minute;
    final kt = _ketThuc.hour * 60 + _ketThuc.minute;
    if (kt <= bd) {
      setState(() => _loi = 'Giờ kết thúc phải sau giờ bắt đầu.');
      return;
    }
    Navigator.pop(context, {
      'thu_trong_tuan': _thu,
      'gio_bat_dau': dinhDangGio(_batDau),
      'gio_ket_thuc': dinhDangGio(_ketThuc),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_laSua ? 'Sửa khung giờ rảnh' : 'Thêm khung giờ rảnh'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Thứ trong tuần'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: List.generate(
                7,
                (i) => ChoiceChip(
                  label: Text(_nhanNgan[i]),
                  selected: _thu == i,
                  onSelected: (_) => setState(() => _thu = i),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _chonGio(true),
                    child: Text('Từ ${dinhDangGio(_batDau)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _chonGio(false),
                    child: Text('Đến ${dinhDangGio(_ketThuc)}'),
                  ),
                ),
              ],
            ),
            if (_loi != null) ...[
              const SizedBox(height: 12),
              Text(_loi!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(onPressed: _luu, child: Text(_laSua ? 'Cập nhật' : 'Lưu')),
      ],
    );
  }
}