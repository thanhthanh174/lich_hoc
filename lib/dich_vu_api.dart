import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'cau_hinh.dart';

/// Lỗi có thông báo tiếng Việt để hiển thị thẳng cho người dùng.
class LoiApi implements Exception {
  final String thongBao;
  final bool hetPhien; // true khi cần đăng nhập lại
  LoiApi(this.thongBao, {this.hetPhien = false});

  @override
  String toString() => thongBao;
}

class DichVuApi {
  static const _khoaAccess = 'access_token';
  static const _khoaRefresh = 'refresh_token';
  // 45 giây: Backend có thể chờ AI tới 30 giây nên app phải chờ lâu hơn.
  static const _thoiGianCho = Duration(seconds: 45);
  static const _loiMang =
      'Không kết nối được máy chủ. Hãy kiểm tra Backend đã chạy chưa.';

  // ---------- Token ----------
  static Future<String?> layAccessToken() async {
    final kho = await SharedPreferences.getInstance();
    return kho.getString(_khoaAccess);
  }

  static Future<bool> daDangNhap() async => (await layAccessToken()) != null;

  static Future<void> dangXuat() async {
    final kho = await SharedPreferences.getInstance();
    await kho.remove(_khoaAccess);
    await kho.remove(_khoaRefresh);
  }

  // ---------- Hàm dùng chung ----------
  static dynamic _giaiMa(http.Response res) =>
      jsonDecode(utf8.decode(res.bodyBytes));

  /// Gom các thông báo lỗi mà Backend trả về thành một chuỗi.
  static String _docLoi(http.Response res) {
    try {
      final du = _giaiMa(res);
      if (du is Map) {
        final cacDong = <String>[];
        du.forEach((khoa, giaTri) {
          if (giaTri is List) {
            cacDong.addAll(giaTri.map((e) => e.toString()));
          } else {
            cacDong.add(giaTri.toString());
          }
        });
        if (cacDong.isNotEmpty) return cacDong.join('\n');
      }
    } catch (_) {}
    return 'Có lỗi xảy ra (mã ${res.statusCode}). Vui lòng thử lại.';
  }

  /// Gửi một request bất kỳ (GET, POST, DELETE...) tới Backend.
  static Future<http.Response> _gui(
    String phuongThuc,
    String duongDan, {
    Map<String, dynamic>? duLieu,
    bool kemToken = true,
  }) async {
    final token = kemToken ? await layAccessToken() : null;
    final yeuCau = http.Request(phuongThuc, Uri.parse('$diaChiGoc$duongDan'));
    yeuCau.headers['Content-Type'] = 'application/json';
    if (token != null) yeuCau.headers['Authorization'] = 'Bearer $token';
    if (duLieu != null) yeuCau.body = jsonEncode(duLieu);
    try {
      final luong = await yeuCau.send().timeout(_thoiGianCho);
      return await http.Response.fromStream(luong);
    } catch (_) {
      throw LoiApi(_loiMang);
    }
  }

  /// Dùng refresh token để xin access token mới. Trả về true nếu thành công.
  static Future<bool> _lamMoiToken() async {
    final kho = await SharedPreferences.getInstance();
    final refresh = kho.getString(_khoaRefresh);
    if (refresh == null) return false;
    final res = await _gui('POST', '/api/lam-moi-token/',
        duLieu: {'refresh': refresh}, kemToken: false);
    if (res.statusCode != 200) return false;
    final du = _giaiMa(res) as Map<String, dynamic>;
    await kho.setString(_khoaAccess, du['access'] as String);
    return true;
  }

  /// Gửi request có token; gặp 401 thì thử làm mới token một lần rồi gửi lại.
  static Future<http.Response> _guiCoToken(
    String phuongThuc,
    String duongDan, {
    Map<String, dynamic>? duLieu,
  }) async {
    var res = await _gui(phuongThuc, duongDan, duLieu: duLieu);
    if (res.statusCode == 401) {
      if (await _lamMoiToken()) {
        res = await _gui(phuongThuc, duongDan, duLieu: duLieu);
      }
      if (res.statusCode == 401) {
        throw LoiApi('Phiên đăng nhập đã hết hạn, hãy đăng nhập lại.',
            hetPhien: true);
      }
    }
    return res;
  }

  // ---------- Xác thực ----------
  static Future<void> dangNhap(String tenDangNhap, String matKhau) async {
    final res = await _gui(
      'POST',
      '/api/dang-nhap/',
      duLieu: {'username': tenDangNhap, 'password': matKhau},
      kemToken: false,
    );
    if (res.statusCode == 200) {
      final du = _giaiMa(res) as Map<String, dynamic>;
      final kho = await SharedPreferences.getInstance();
      await kho.setString(_khoaAccess, du['access'] as String);
      await kho.setString(_khoaRefresh, du['refresh'] as String);
    } else if (res.statusCode == 401) {
      throw LoiApi('Sai tên đăng nhập hoặc mật khẩu.');
    } else {
      throw LoiApi(_docLoi(res));
    }
  }

  static Future<void> dangKy(
      String tenDangNhap, String email, String matKhau) async {
    final res = await _gui(
      'POST',
      '/api/dang-ky/',
      duLieu: {'username': tenDangNhap, 'email': email, 'mat_khau': matKhau},
      kemToken: false,
    );
    if (res.statusCode != 201) throw LoiApi(_docLoi(res));
  }

  // ---------- Dữ liệu ----------
  static Future<Map<String, dynamic>> layThongTin() async {
    final res = await _guiCoToken('GET', '/api/toi/');
    if (res.statusCode == 200) return _giaiMa(res) as Map<String, dynamic>;
    throw LoiApi(_docLoi(res));
  }

  static Future<List<dynamic>> layDanhSach(String duongDan) async {
    final res = await _guiCoToken('GET', duongDan);
    if (res.statusCode == 200) return _giaiMa(res) as List<dynamic>;
    throw LoiApi(_docLoi(res));
  }

  static Future<Map<String, dynamic>> tao(
      String duongDan, Map<String, dynamic> duLieu) async {
    final res = await _guiCoToken('POST', duongDan, duLieu: duLieu);
    if (res.statusCode == 201 || res.statusCode == 200) {
      return _giaiMa(res) as Map<String, dynamic>;
    }
    throw LoiApi(_docLoi(res));
  }

  static Future<void> xoa(String duongDan) async {
    final res = await _guiCoToken('DELETE', duongDan);
    if (res.statusCode != 204) throw LoiApi(_docLoi(res));
  }

  static Future<Map<String, dynamic>> capNhat(
      String duongDan, Map<String, dynamic> duLieu) async {
    final res = await _guiCoToken('PATCH', duongDan, duLieu: duLieu);
    if (res.statusCode == 200) return _giaiMa(res) as Map<String, dynamic>;
    throw LoiApi(_docLoi(res));
  }
}