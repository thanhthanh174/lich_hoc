import 'package:flutter/material.dart';

import 'dich_vu_api.dart';
import 'tien_ich.dart';

const _cacMau = [
  '#03A9F4', '#E91E63', '#4CAF50', '#FF9800',
  '#9C27B0', '#009688', '#F44336', '#795548',
];

class ManHinhMonHoc extends StatefulWidget {
  const ManHinhMonHoc({super.key});

  @override
  State<ManHinhMonHoc> createState() => _ManHinhMonHocState();
}

class _ManHinhMonHocState extends State<ManHinhMonHoc> {
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
      final ds = await DichVuApi.layDanhSach('/api/mon-hoc/');
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
        context: context, builder: (_) => const _HopThoaiThemMon());
    if (du == null) return;
    try {
      await DichVuApi.tao('/api/mon-hoc/', du);
      await _tai();
    } catch (loi) {
      if (mounted) await xuLyLoi(context, loi);
    }
  }

  Future<void> _xoa(Map<String, dynamic> mon) async {
    final dongY = await xacNhanXoa(context, 'Xóa môn "${mon['ten_mon']}"?',
        'Các nhiệm vụ thuộc môn học này cũng sẽ bị xóa.');
    if (!dongY) return;
    try {
      await DichVuApi.xoa('/api/mon-hoc/${mon['id']}/');
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
        label: const Text('Thêm môn'),
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
              trangThaiRong(context, Icons.menu_book_outlined,
                  'Chưa có môn học nào.\nBấm "Thêm môn" để tạo môn đầu tiên.'),
            ])
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 88),
              itemCount: _ds.length,
              itemBuilder: (context, i) {
                final mon = _ds[i] as Map<String, dynamic>;
                final ten = mon['ten_mon'] as String;
                final hocKy = (mon['hoc_ky'] as String?) ?? '';
                return theMuc(
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: mauTuHex(mon['mau_sac'] as String),
                      child: Text(
                        ten.isEmpty ? '?' : ten[0].toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(ten,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: hocKy.isEmpty ? null : Text('Học kỳ: $hocKy'),
                    trailing: IconButton(
                      tooltip: 'Xóa',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _xoa(mon),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _HopThoaiThemMon extends StatefulWidget {
  const _HopThoaiThemMon();

  @override
  State<_HopThoaiThemMon> createState() => _HopThoaiThemMonState();
}

class _HopThoaiThemMonState extends State<_HopThoaiThemMon> {
  final _khoa = GlobalKey<FormState>();
  final _ten = TextEditingController();
  final _hocKy = TextEditingController();
  String _mau = _cacMau.first;

  @override
  void dispose() {
    _ten.dispose();
    _hocKy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm môn học'),
      content: Form(
        key: _khoa,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _ten,
                decoration: const InputDecoration(labelText: 'Tên môn'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập tên môn.'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _hocKy,
                decoration:
                    const InputDecoration(labelText: 'Học kỳ (không bắt buộc)'),
              ),
              const SizedBox(height: 16),
              const Text('Màu hiển thị'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _cacMau
                    .map((m) => GestureDetector(
                          onTap: () => setState(() => _mau = m),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: mauTuHex(m),
                            child: _mau == m
                                ? const Icon(Icons.check,
                                    size: 18, color: Colors.white)
                                : null,
                          ),
                        ))
                    .toList(),
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
            if (!_khoa.currentState!.validate()) return;
            Navigator.pop(context, {
              'ten_mon': _ten.text.trim(),
              'hoc_ky': _hocKy.text.trim(),
              'mau_sac': _mau,
            });
          },
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}