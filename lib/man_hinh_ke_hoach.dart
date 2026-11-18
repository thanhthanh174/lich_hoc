import 'package:flutter/material.dart';

import 'dich_vu_api.dart';
import 'tien_ich.dart';

const _thuNgan = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

String _hai(int n) => n.toString().padLeft(2, '0');
String _gio(DateTime t) => '${_hai(t.hour)}:${_hai(t.minute)}';
DateTime _chiNgay(DateTime t) => DateTime(t.year, t.month, t.day);

class ManHinhKeHoach extends StatefulWidget {
  const ManHinhKeHoach({super.key});

  @override
  State<ManHinhKeHoach> createState() => _ManHinhKeHoachState();
}

class _ManHinhKeHoachState extends State<ManHinhKeHoach> {
  Map<String, dynamic>? _keHoach;
  List<dynamic> _dsBuoi = [];
  List<dynamic> _khongXepDuoc = [];
  Map<int, String> _tenNhiemVu = {};
  DateTime? _ngayChon;
  bool _dangTai = true;
  bool _dangXuLy = false;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _tai();
  }

  // ---------- Tải dữ liệu ----------
  Future<void> _taiTenNhiemVu() async {
    try {
      final ds = await DichVuApi.layDanhSach('/api/nhiem-vu/');
      final kq = <int, String>{};
      for (final n in ds) {
        final nv = n as Map<String, dynamic>;
        kq[nv['id'] as int] = nv['tieu_de'] as String;
      }
      _tenNhiemVu = kq;
    } catch (_) {}
  }

  void _chonNgayMacDinh() {
    final kh = _keHoach;
    if (kh == null) return;
    final dau = _chiNgay(DateTime.parse(kh['ngay_bat_dau'] as String));
    final cuoi = _chiNgay(DateTime.parse(kh['ngay_ket_thuc'] as String));
    final homNay = _chiNgay(DateTime.now());
    final cu = _ngayChon;
    if (cu != null && !cu.isBefore(dau) && !cu.isAfter(cuoi)) return;
    _ngayChon = (!homNay.isBefore(dau) && !homNay.isAfter(cuoi)) ? homNay : dau;
  }

  Future<void> _tai() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final dsKeHoach = await DichVuApi.layDanhSach('/api/ke-hoach/');
      if (!mounted) return;
      if (dsKeHoach.isEmpty) {
        setState(() {
          _keHoach = null;
          _dsBuoi = [];
        });
        return;
      }
      // Lấy kế hoạch mới nhất (id lớn nhất)
      var moiNhat = dsKeHoach.first as Map<String, dynamic>;
      for (final k in dsKeHoach) {
        final m = k as Map<String, dynamic>;
        if ((m['id'] as int) > (moiNhat['id'] as int)) moiNhat = m;
      }
      final dsBuoi = await DichVuApi.layDanhSach(
          '/api/buoi-hoc/?ke_hoach=${moiNhat['id']}');
      await _taiTenNhiemVu();
      if (!mounted) return;
      setState(() {
        _keHoach = moiNhat;
        _dsBuoi = dsBuoi;
        _chonNgayMacDinh();
      });
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

  /// Gán kết quả của "tạo kế hoạch" hoặc "xếp lại" (cùng dạng JSON).
  Future<void> _ganKetQua(Map<String, dynamic> kq) async {
    final kh = kq['ke_hoach'] as Map<String, dynamic>;
    await _taiTenNhiemVu();
    if (!mounted) return;
    setState(() {
      _keHoach = kh;
      _dsBuoi = (kh['danh_sach_buoi_hoc'] as List<dynamic>?) ?? [];
      _khongXepDuoc = (kq['khong_xep_duoc'] as List<dynamic>?) ?? [];
      _chonNgayMacDinh();
    });
  }

  // ---------- Hành động ----------
  Future<void> _taoKeHoach() async {
    final soNgay = await showDialog<int>(
        context: context, builder: (_) => const _HopThoaiSoNgay());
    if (soNgay == null) return;
    setState(() => _dangXuLy = true);
    try {
      final kq = await DichVuApi.tao('/api/ke-hoach/tao/', {'so_ngay': soNgay});
      await _ganKetQua(kq);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã tạo kế hoạch mới.')));
      }
    } catch (loi) {
      if (mounted) await xuLyLoi(context, loi);
    } finally {
      if (mounted) setState(() => _dangXuLy = false);
    }
  }

  Future<void> _xepLai() async {
    final kh = _keHoach;
    if (kh == null) return;
    setState(() => _dangXuLy = true);
    try {
      final kq =
          await DichVuApi.tao('/api/ke-hoach/${kh['id']}/xep-lai/', {});
      await _ganKetQua(kq);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã xếp lại lịch.')));
      }
    } catch (loi) {
      if (mounted) await xuLyLoi(context, loi);
    } finally {
      if (mounted) setState(() => _dangXuLy = false);
    }
  }

  Future<void> _doiTrangThaiBuoi(Map<String, dynamic> buoi, String moi) async {
    try {
      await DichVuApi.capNhat(
          '/api/buoi-hoc/${buoi['id']}/', {'trang_thai': moi});
      await _tai();
    } catch (loi) {
      if (mounted) await xuLyLoi(context, loi);
    }
  }

  // ---------- Giao diện ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _noiDung(),
    );
  }

  Widget _noiDung() {
    if (_dangTai && _keHoach == null) {
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
    return Column(
      children: [
        _hangNut(),
        if (_dangXuLy) const LinearProgressIndicator(),
        if (_keHoach == null)
          Expanded(
            child: ListView(children: [
              const SizedBox(height: 100),
              trangThaiRong(context, Icons.event_note_outlined,
                  'Chưa có kế hoạch nào.\nBấm "Tạo kế hoạch" để hệ thống xếp lịch học cho bà.'),
            ]),
          )
        else ...[
          _thanhNgay(),
          Expanded(child: _danhSachBuoi()),
        ],
      ],
    );
  }

  Widget _hangNut() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _dangXuLy ? null : _taoKeHoach,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Tạo kế hoạch'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: (_dangXuLy || _keHoach == null) ? null : _xepLai,
              icon: const Icon(Icons.refresh),
              label: const Text('Xếp lại lịch'),
            ),
          ),
        ],
      ),
    );
  }

  List<DateTime> _cacNgay() {
    final kh = _keHoach!;
    final dau = _chiNgay(DateTime.parse(kh['ngay_bat_dau'] as String));
    final cuoi = _chiNgay(DateTime.parse(kh['ngay_ket_thuc'] as String));
    final kq = <DateTime>[];
    for (var d = dau;
        !d.isAfter(cuoi);
        d = DateTime(d.year, d.month, d.day + 1)) {
      kq.add(d);
    }
    return kq;
  }

    Widget _thanhNgay() {
    final cacNgay = _cacNgay();
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: cacNgay.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = cacNgay[i];
          final chon = _ngayChon == d;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _ngayChon = d),
            child: Container(
              width: 62,
              decoration: BoxDecoration(
                color: chon ? const Color(0xFF039BE5) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: chon ? const Color(0xFF039BE5) : Colors.black26),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _thuNgan[d.weekday - 1],
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: chon ? Colors.white : Colors.black87),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${d.day}/${d.month}',
                    style: TextStyle(
                        fontSize: 12,
                        color: chon ? Colors.white : Colors.black54),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _danhSachBuoi() {
    final ngay = _ngayChon;
    final cacBuoi = _dsBuoi
        .map((e) => e as Map<String, dynamic>)
        .where((b) =>
            ngay != null &&
            _chiNgay(DateTime.parse(b['thoi_gian_bat_dau'] as String)
                    .toLocal()) ==
                ngay)
        .toList()
      ..sort((a, b) => (a['thoi_gian_bat_dau'] as String)
          .compareTo(b['thoi_gian_bat_dau'] as String));

    final cacThe = <Widget>[];
    if (cacBuoi.isEmpty) {
      cacThe.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text('Ngày này không có buổi học nào.')),
      ));
    } else {
      cacThe.addAll(cacBuoi.map(_theBuoi));
    }

    if (_khongXepDuoc.isNotEmpty) {
      cacThe.add(const Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
        child: Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Text('Chưa xếp được',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
      ));
      for (final e in _khongXepDuoc) {
        final m = e as Map<String, dynamic>;
        final ten = _tenNhiemVu[m['nhiem_vu_id'] as int] ??
            'Nhiệm vụ #${m['nhiem_vu_id']}';
        cacThe.add(theMuc(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ten, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Còn thiếu ${m['so_phut_thieu']} phút'),
                Text((m['ly_do'] as String?) ?? ''),
              ],
            ),
          ),
        ));
      }
    }

    return RefreshIndicator(
      onRefresh: _tai,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: cacThe,
      ),
    );
  }

  Widget _theBuoi(Map<String, dynamic> b) {
    final bd = DateTime.parse(b['thoi_gian_bat_dau'] as String).toLocal();
    final kt = DateTime.parse(b['thoi_gian_ket_thuc'] as String).toLocal();
    final phut = kt.difference(bd).inMinutes;
    final tt = b['trang_thai'] as String;
    final mau = mauTuHex((b['mau_sac'] as String?) ?? '#9E9E9E');

    Widget phanDuoi;
    if (tt == 'du_kien') {
      phanDuoi = Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
              onPressed: () => _doiTrangThaiBuoi(b, 'bo_lo'),
              child: const Text('Bỏ lỡ')),
          const SizedBox(width: 8),
          FilledButton(
              onPressed: () => _doiTrangThaiBuoi(b, 'hoan_thanh'),
              child: const Text('Hoàn thành')),
        ],
      );
    } else {
      final xong = tt == 'hoan_thanh';
      phanDuoi = Row(children: [
        Icon(xong ? Icons.check_circle : Icons.cancel,
            size: 18, color: xong ? Colors.green : Colors.red),
        const SizedBox(width: 6),
        Text(xong ? 'Đã hoàn thành' : 'Đã bỏ lỡ',
            style: TextStyle(color: xong ? Colors.green : Colors.red)),
      ]);
    }

    return theMuc(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: mau),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((b['tieu_de_nhiem_vu'] as String?) ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
                    Text((b['ten_mon'] as String?) ?? ''),
                    const SizedBox(height: 4),
                    Text('${_gio(bd)} - ${_gio(kt)} ($phut phút)'),
                    const SizedBox(height: 8),
                    phanDuoi,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HopThoaiSoNgay extends StatefulWidget {
  const _HopThoaiSoNgay();

  @override
  State<_HopThoaiSoNgay> createState() => _HopThoaiSoNgayState();
}

class _HopThoaiSoNgayState extends State<_HopThoaiSoNgay> {
  final _khoa = GlobalKey<FormState>();
  final _soNgay = TextEditingController(text: '7');

  @override
  void dispose() {
    _soNgay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tạo kế hoạch'),
      content: Form(
        key: _khoa,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Các buổi học dự kiến hiện tại sẽ được thay bằng kế hoạch mới.'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _soNgay,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Số ngày (1-14)'),
              validator: (v) {
                final so = int.tryParse((v ?? '').trim());
                if (so == null || so < 1 || so > 14) {
                  return 'Nhập số từ 1 đến 14.';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(
          onPressed: () {
            if (!_khoa.currentState!.validate()) return;
            Navigator.pop(context, int.parse(_soNgay.text.trim()));
          },
          child: const Text('Tạo'),
        ),
      ],
    );
  }
}