import 'package:flutter/material.dart';

import 'dich_vu_api.dart';
import 'tien_ich.dart';

String _hai(int n) => n.toString().padLeft(2, '0');

String _dinhDangNgayGio(DateTime t) =>
    '${_hai(t.day)}/${_hai(t.month)}/${t.year} ${_hai(t.hour)}:${_hai(t.minute)}';

String _dinhDangThuNgayGio(DateTime t) =>
    '${tenThu[t.weekday - 1]}, ${_dinhDangNgayGio(t)}';

class ManHinhNhiemVu extends StatefulWidget {
  const ManHinhNhiemVu({super.key});

  @override
  State<ManHinhNhiemVu> createState() => _ManHinhNhiemVuState();
}

class _ManHinhNhiemVuState extends State<ManHinhNhiemVu> {
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
      final ds = await DichVuApi.layDanhSach('/api/nhiem-vu/');
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
    List<dynamic> dsMon;
    try {
      dsMon = await DichVuApi.layDanhSach('/api/mon-hoc/');
    } catch (loi) {
      if (mounted) await xuLyLoi(context, loi);
      return;
    }
    if (!mounted) return;
    if (dsMon.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Hãy thêm môn học trước khi thêm nhiệm vụ.')));
      return;
    }
    final du = await showDialog<Map<String, dynamic>>(
        context: context, builder: (_) => _HopThoaiThemNhiemVu(dsMon: dsMon));
    if (du == null) return;
    try {
      await DichVuApi.tao('/api/nhiem-vu/', du);
      await _tai();
    } catch (loi) {
      if (mounted) await xuLyLoi(context, loi);
    }
  }

  Future<void> _doiTrangThai(Map<String, dynamic> nv) async {
    final moi = nv['trang_thai'] == 'da_xong' ? 'chua_lam' : 'da_xong';
    try {
      await DichVuApi.capNhat(
          '/api/nhiem-vu/${nv['id']}/', {'trang_thai': moi});
      await _tai();
    } catch (loi) {
      if (mounted) await xuLyLoi(context, loi);
    }
  }

  Future<void> _xoa(Map<String, dynamic> nv) async {
    final dongY = await xacNhanXoa(context, 'Xóa nhiệm vụ "${nv['tieu_de']}"?',
        'Các buổi học đã xếp cho nhiệm vụ này cũng sẽ bị xóa.');
    if (!dongY) return;
    try {
      await DichVuApi.xoa('/api/nhiem-vu/${nv['id']}/');
      await _tai();
    } catch (loi) {
      if (mounted) await xuLyLoi(context, loi);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _them,
        icon: const Icon(Icons.add),
        label: const Text('Thêm nhiệm vụ'),
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
              trangThaiRong(context, Icons.checklist_outlined,
                  'Chưa có nhiệm vụ nào.\nBấm "Thêm nhiệm vụ" để tạo nhiệm vụ đầu tiên.'),
            ])
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 88),
              itemCount: _ds.length,
              itemBuilder: (context, i) =>
                  _theNhiemVu(_ds[i] as Map<String, dynamic>),
            ),
    );
  }

  Widget _theNhiemVu(Map<String, dynamic> nv) {
    final daXong = nv['trang_thai'] == 'da_xong';
    final han = DateTime.parse(nv['han_hoan_thanh'] as String).toLocal();
    final quaHan = !daXong && han.isBefore(DateTime.now());
    final quanTrong = (nv['do_quan_trong'] as int?) ?? 1;
    final tenQuanTrong = ['Thấp', 'Vừa', 'Cao'][(quanTrong - 1).clamp(0, 2)];
    final mau = mauTuHex((nv['mau_sac'] as String?) ?? '#9E9E9E');

    return theMuc(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        leading: Checkbox(
          value: daXong,
          onChanged: (_) => _doiTrangThai(nv),
        ),
        title: Text(
          nv['tieu_de'] as String,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: daXong ? TextDecoration.lineThrough : null,
            color: daXong ? Colors.grey : null,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(radius: 5, backgroundColor: mau),
                const SizedBox(width: 6),
                Expanded(child: Text((nv['ten_mon'] as String?) ?? '')),
              ]),
              Text(
                'Hạn: ${_dinhDangThuNgayGio(han)}${quaHan ? '  (Quá hạn)' : ''}',
                style: TextStyle(color: quaHan ? Colors.red : null),
              ),
              Text(
                  '${nv['thoi_luong_du_kien']} phút · Độ quan trọng: $tenQuanTrong'),
            ],
          ),
        ),
        trailing: IconButton(
          tooltip: 'Xóa',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _xoa(nv),
        ),
      ),
    );
  }
}

class _HopThoaiThemNhiemVu extends StatefulWidget {
  final List<dynamic> dsMon;
  const _HopThoaiThemNhiemVu({required this.dsMon});

  @override
  State<_HopThoaiThemNhiemVu> createState() => _HopThoaiThemNhiemVuState();
}

class _HopThoaiThemNhiemVuState extends State<_HopThoaiThemNhiemVu> {
  final _khoa = GlobalKey<FormState>();
  final _tieuDe = TextEditingController();
  final _moTa = TextEditingController();
  final _thoiLuong = TextEditingController(text: '60');
  int? _monId;
  int _quanTrong = 2;
  DateTime? _han;
  String? _loiHan;

  @override
  void initState() {
    super.initState();
    _monId = (widget.dsMon.first as Map<String, dynamic>)['id'] as int;
  }

  @override
  void dispose() {
    _tieuDe.dispose();
    _moTa.dispose();
    _thoiLuong.dispose();
    super.dispose();
  }

  Future<void> _chonHan() async {
    final bayGio = DateTime.now();
    final ngay = await showDatePicker(
      context: context,
      initialDate: _han ?? bayGio,
      firstDate: bayGio.subtract(const Duration(days: 1)),
      lastDate: bayGio.add(const Duration(days: 365)),
    );
    if (ngay == null || !mounted) return;
    final gio = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 23, minute: 59),
    );
    if (gio == null) return;
    setState(() {
      _han = DateTime(ngay.year, ngay.month, ngay.day, gio.hour, gio.minute);
      _loiHan = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm nhiệm vụ'),
      content: Form(
        key: _khoa,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _tieuDe,
                decoration: const InputDecoration(labelText: 'Tiêu đề'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập tiêu đề.'
                    : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _monId,
                decoration: const InputDecoration(labelText: 'Môn học'),
                items: widget.dsMon.map((m) {
                  final mon = m as Map<String, dynamic>;
                  return DropdownMenuItem<int>(
                    value: mon['id'] as int,
                    child: Text(mon['ten_mon'] as String),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _monId = v),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _moTa,
                decoration:
                    const InputDecoration(labelText: 'Mô tả (không bắt buộc)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _thoiLuong,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Thời lượng dự kiến (phút)'),
                validator: (v) {
                  final so = int.tryParse((v ?? '').trim());
                  if (so == null || so <= 0) return 'Nhập số phút lớn hơn 0.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text('Độ quan trọng'),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('Thấp')),
                  ButtonSegment(value: 2, label: Text('Vừa')),
                  ButtonSegment(value: 3, label: Text('Cao')),
                ],
                selected: {_quanTrong},
                onSelectionChanged: (s) =>
                    setState(() => _quanTrong = s.first),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _chonHan,
                icon: const Icon(Icons.event),
                label: Text(_han == null
                    ? 'Chọn hạn hoàn thành'
                    : 'Hạn: ${_dinhDangThuNgayGio(_han!)}'),
              ),
              if (_loiHan != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_loiHan!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(
          onPressed: () {
            final hopLe = _khoa.currentState!.validate();
            if (_han == null) {
              setState(() => _loiHan = 'Vui lòng chọn hạn hoàn thành.');
              return;
            }
            if (!hopLe) return;
            Navigator.pop(context, {
              'mon_hoc': _monId,
              'tieu_de': _tieuDe.text.trim(),
              'mo_ta': _moTa.text.trim(),
              'han_hoan_thanh': _han!.toUtc().toIso8601String(),
              'thoi_luong_du_kien': int.parse(_thoiLuong.text.trim()),
              'do_quan_trong': _quanTrong,
            });
          },
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}