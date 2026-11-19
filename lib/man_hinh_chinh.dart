import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dich_vu_api.dart';
import 'man_hinh_dang_nhap.dart';
import 'man_hinh_khung_gio.dart';
import 'man_hinh_mon_hoc.dart';
import 'man_hinh_nhiem_vu.dart';
import 'man_hinh_ke_hoach.dart';

String _hai(int n) => n.toString().padLeft(2, '0');
String _ngayGio(DateTime t) =>
    '${_hai(t.day)}/${_hai(t.month)} ${_hai(t.hour)}:${_hai(t.minute)}';
String _gioPhut(DateTime t) => '${_hai(t.hour)}:${_hai(t.minute)}';

const _khoaDaDoc = 'thong_bao_da_doc';

/// Một dòng thông báo trong chuông. "ma" là mã riêng để nhớ đã đọc.
class _ThongBao {
  final String ma;
  final IconData bieuTuong;
  final Color mau;
  final String tieuDe;
  final String noiDung;
  const _ThongBao(this.ma, this.bieuTuong, this.mau, this.tieuDe, this.noiDung);
}

class ManHinhChinh extends StatefulWidget {
  const ManHinhChinh({super.key});

  @override
  State<ManHinhChinh> createState() => _ManHinhChinhState();
}

class _ManHinhChinhState extends State<ManHinhChinh> {
  int _chon = 0;
  String _tenNguoiDung = '';
  List<_ThongBao> _thongBao = [];
  Set<String> _daDoc = {};

  static const _tieuDe = [
    'Kế hoạch học tập',
    'Nhiệm vụ',
    'Môn học',
    'Khung giờ rảnh',
  ];
  static const _bieuTuong = [
    Icons.event_note_outlined,
    Icons.checklist_outlined,
    Icons.menu_book_outlined,
    Icons.schedule,
  ];
  static const _cacManHinh = [
    ManHinhKeHoach(),
    ManHinhNhiemVu(),
    ManHinhMonHoc(),
    ManHinhKhungGio(),
  ];

  @override
  void initState() {
    super.initState();
    _taiTenNguoiDung();
    _khoiTaoThongBao();
  }

  Future<void> _khoiTaoThongBao() async {
    try {
      final kho = await SharedPreferences.getInstance();
      _daDoc = (kho.getStringList(_khoaDaDoc) ?? []).toSet();
    } catch (_) {}
    await _taiThongBao();
  }

  Future<void> _luuDaDoc() async {
    try {
      final kho = await SharedPreferences.getInstance();
      await kho.setStringList(_khoaDaDoc, _daDoc.toList());
    } catch (_) {}
  }

  Future<void> _taiTenNguoiDung() async {
    try {
      final tt = await DichVuApi.layThongTin();
      if (!mounted) return;
      setState(() => _tenNguoiDung = (tt['username'] as String?) ?? '');
    } catch (_) {}
  }

  int get _soChuaDoc => _thongBao.where((t) => !_daDoc.contains(t.ma)).length;

  /// Tính thông báo ngay trong app từ dữ liệu có sẵn (backend không đổi).
  Future<void> _taiThongBao() async {
    final quaHan = <_ThongBao>[];
    final buoiHomNay = <_ThongBao>[];
    final sapHan = <_ThongBao>[];
    try {
      final bayGio = DateTime.now();
      final homNay = DateTime(bayGio.year, bayGio.month, bayGio.day);

      // 1. Nhiệm vụ quá hạn / sắp hết hạn trong 24 giờ
      final dsNv = await DichVuApi.layDanhSach('/api/nhiem-vu/');
      for (final e in dsNv) {
        final nv = e as Map<String, dynamic>;
        if (nv['trang_thai'] == 'da_xong') continue;
        final hanChuoi = nv['han_hoan_thanh'] as String;
        final han = DateTime.parse(hanChuoi).toLocal();
        final ten = (nv['tieu_de'] as String?) ?? '';
        final mon = (nv['ten_mon'] as String?) ?? '';
        if (han.isBefore(bayGio)) {
          quaHan.add(_ThongBao(
              'quahan:${nv['id']}:$hanChuoi',
              Icons.error_outline,
              Colors.red,
              'Nhiệm vụ quá hạn',
              '$ten ($mon) - hạn ${_ngayGio(han)}'));
        } else if (han.difference(bayGio).inHours < 24) {
          sapHan.add(_ThongBao(
              'saphan:${nv['id']}:$hanChuoi',
              Icons.alarm,
              Colors.orange,
              'Sắp đến hạn trong 24 giờ',
              '$ten ($mon) - hạn ${_ngayGio(han)}'));
        }
      }

      // 2. Buổi học hôm nay chưa đánh dấu (lấy từ kế hoạch mới nhất)
      final dsKh = await DichVuApi.layDanhSach('/api/ke-hoach/');
      if (dsKh.isNotEmpty) {
        var moiNhat = dsKh.first as Map<String, dynamic>;
        for (final k in dsKh) {
          final m = k as Map<String, dynamic>;
          if ((m['id'] as int) > (moiNhat['id'] as int)) moiNhat = m;
        }
        final dsBuoi = await DichVuApi.layDanhSach(
            '/api/buoi-hoc/?ke_hoach=${moiNhat['id']}');
        for (final e in dsBuoi) {
          final b = e as Map<String, dynamic>;
          if (b['trang_thai'] != 'du_kien') continue;
          final bd = DateTime.parse(b['thoi_gian_bat_dau'] as String).toLocal();
          final kt = DateTime.parse(b['thoi_gian_ket_thuc'] as String).toLocal();
          final ngayBuoi = DateTime(bd.year, bd.month, bd.day);
          if (ngayBuoi != homNay) continue;
          final ten = (b['tieu_de_nhiem_vu'] as String?) ?? '';
          if (kt.isBefore(bayGio)) {
            buoiHomNay.add(_ThongBao(
                'buoiqua:${b['id']}',
                Icons.help_outline,
                Colors.red,
                'Buổi học đã qua, chưa đánh dấu',
                '$ten (${_gioPhut(bd)} - ${_gioPhut(kt)})'));
          } else {
            buoiHomNay.add(_ThongBao(
                'buoinay:${b['id']}',
                Icons.event_available,
                const Color(0xFF039BE5),
                'Buổi học hôm nay',
                '$ten (${_gioPhut(bd)} - ${_gioPhut(kt)})'));
          }
        }
      }
    } catch (_) {
      return; // lỗi mạng thì giữ nguyên thông báo cũ
    }
    if (!mounted) return;
    setState(() => _thongBao = [...quaHan, ...buoiHomNay, ...sapHan]);
  }

  Future<void> _moThongBao() async {
    await _taiThongBao();
    if (!mounted) return;
    // Chụp lại danh sách và những mã chưa đọc tại thời điểm mở bảng
    final danhSach = List<_ThongBao>.from(_thongBao);
    final chuaDocLucMo =
        danhSach.where((t) => !_daDoc.contains(t.ma)).map((t) => t.ma).toSet();
    final cao = MediaQuery.of(context).size.height * 0.6;

    // Mở bảng xong là coi như đã đọc: số đỏ biến mất ngay
    setState(() => _daDoc.addAll(danhSach.map((t) => t.ma)));
    _luuDaDoc();

    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: cao),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text('Thông báo',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              if (danhSach.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Text('Hiện không có thông báo nào.'),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: danhSach.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final t = danhSach[i];
                      final moi = chuaDocLucMo.contains(t.ma);
                      return ListTile(
                        leading: Icon(t.bieuTuong, color: t.mau),
                        title: Text(t.tieuDe,
                            style: TextStyle(
                                fontWeight:
                                    moi ? FontWeight.bold : FontWeight.normal)),
                        subtitle: Text(t.noiDung),
                        trailing: moi
                            ? const CircleAvatar(
                                radius: 5,
                                backgroundColor: Color(0xFF039BE5))
                            : null,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _chonTab(int i) {
    setState(() => _chon = i);
    _taiThongBao(); // làm mới chuông mỗi lần đổi tab
  }

  Future<void> _dangXuat() async {
    await DichVuApi.dangXuat();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ManHinhDangNhap()),
        (route) => false);
  }

  Widget _menuBen() {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFF039BE5),
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person,
                        size: 32, color: Color(0xFF039BE5)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _tenNguoiDung.isEmpty ? 'Xin chào!' : _tenNguoiDung,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  const Text('Lịch học thông minh',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            for (var i = 0; i < _tieuDe.length; i++)
              ListTile(
                leading: Icon(_bieuTuong[i]),
                title: Text(_tieuDe[i]),
                selected: _chon == i,
                onTap: () {
                  Navigator.pop(context);
                  _chonTab(i);
                },
              ),
            const Spacer(),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Đăng xuất'),
              onTap: () {
                Navigator.pop(context);
                _dangXuat();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final soChuaDoc = _soChuaDoc;
    return Scaffold(
      drawer: _menuBen(),
      appBar: AppBar(
        title: Text(_tieuDe[_chon]),
        actions: [
          IconButton(
            tooltip: 'Thông báo',
            onPressed: _moThongBao,
            icon: Badge(
              isLabelVisible: soChuaDoc > 0,
              label: Text(soChuaDoc > 9 ? '9+' : '$soChuaDoc'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _chon, children: _cacManHinh),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _chon,
        onDestinationSelected: _chonTab,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.event_note_outlined), label: 'Kế hoạch'),
          NavigationDestination(
              icon: Icon(Icons.checklist_outlined), label: 'Nhiệm vụ'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined), label: 'Môn học'),
          NavigationDestination(icon: Icon(Icons.schedule), label: 'Giờ rảnh'),
        ],
      ),
    );
  }
}