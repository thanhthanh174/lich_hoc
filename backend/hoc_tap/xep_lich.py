"""
xep_lich.py - Thuật toán xếp lịch học rule-based (không dùng AI).

Ý tưởng:
1. Tính điểm ưu tiên cho từng nhiệm vụ (deadline, độ quan trọng, thời lượng còn lại).
2. Sắp xếp nhiệm vụ theo điểm giảm dần.
3. Lần lượt xếp từng nhiệm vụ vào các khung giờ rảnh sớm nhất (tham lam - greedy),
   chia thành các buổi tối đa 90 phút, không vượt quá số giờ học tối đa mỗi ngày,
   và luôn kết thúc trước deadline.
"""
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, time, timedelta

from django.db import transaction
from django.utils import timezone

from .models import BuoiHoc, HoSo, KeHoachHocTap, KhungGioRanh, NhiemVu

# --- Tham số của thuật toán (nêu rõ trong báo cáo) ---
TRONG_SO_DEADLINE = 0.5
TRONG_SO_QUAN_TRONG = 0.35
TRONG_SO_THOI_LUONG = 0.15
THOI_LUONG_CHUAN = 240   # phút, dùng để chuẩn hóa điểm thời lượng về 0-1
BUOI_TOI_DA = 90         # phút, độ dài tối đa một buổi học
BUOI_TOI_THIEU = 15      # phút, không tạo buổi ngắn hơn mức này (trừ phần cuối)
NGHI_GIUA_BUOI = 10      # phút nghỉ sau mỗi buổi


@dataclass
class NhiemVuXep:
    id: int
    han: datetime
    do_quan_trong: int
    phut_con_lai: int
    diem: float = 0.0


def tinh_diem_uu_tien(han, do_quan_trong, phut_con_lai, bay_gio):
    """Điểm càng cao càng được xếp trước. Kết quả trong khoảng 0 đến 1."""
    so_ngay_con = max((han - bay_gio).total_seconds() / 86400, 0)
    diem_deadline = 1 / (1 + so_ngay_con)               # càng gần deadline càng cao
    diem_quan_trong = do_quan_trong / 3                  # 1/3, 2/3, 3/3
    diem_thoi_luong = min(phut_con_lai / THOI_LUONG_CHUAN, 1)  # việc dài nên bắt đầu sớm
    diem = (TRONG_SO_DEADLINE * diem_deadline
            + TRONG_SO_QUAN_TRONG * diem_quan_trong
            + TRONG_SO_THOI_LUONG * diem_thoi_luong)
    return round(diem, 4)


def _tru_khoang(ds, b0, b1):
    """Cắt khoảng [b0, b1] ra khỏi danh sách các khoảng rảnh."""
    ket_qua = []
    for dau, cuoi in ds:
        if b1 <= dau or b0 >= cuoi:
            ket_qua.append([dau, cuoi])
            continue
        if b0 > dau:
            ket_qua.append([dau, b0])
        if b1 < cuoi:
            ket_qua.append([b1, cuoi])
    return ket_qua


def _lam_tron_len_5_phut(dt):
    dt = dt.replace(second=0, microsecond=0)
    du = dt.minute % 5
    return dt + timedelta(minutes=5 - du) if du else dt


def thuat_toan_xep_lich(ds_nhiem_vu, khung_gio, ngay_bat_dau, ngay_ket_thuc,
                        bay_gio, gioi_han_phut, khoang_da_ban=None, phut_da_hoc=None):
    """
    Hàm thuần (không đụng CSDL) để dễ kiểm thử.

    ds_nhiem_vu : list[NhiemVuXep]
    khung_gio   : dict {thu_trong_tuan: [(gio_bat_dau, gio_ket_thuc), ...]}
    khoang_da_ban : list[(datetime, datetime)] các khoảng đã có buổi học
    phut_da_hoc : dict {date: số phút đã học trong ngày}
    Trả về dict: buoi, khong_xep_duoc, thu_tu_uu_tien
    """
    khoang_da_ban = khoang_da_ban or []
    da_dung = defaultdict(int, phut_da_hoc or {})

    # Bước 1: tạo danh sách khoảng rảnh cho từng ngày
    khoang_ranh = {}
    ngay = ngay_bat_dau
    while ngay <= ngay_ket_thuc:
        ds = []
        for bd, kt in khung_gio.get(ngay.weekday(), []):
            dau = timezone.make_aware(datetime.combine(ngay, bd))
            cuoi = timezone.make_aware(datetime.combine(ngay, kt))
            dau = max(dau, bay_gio)  # không xếp vào quá khứ
            if cuoi - dau >= timedelta(minutes=BUOI_TOI_THIEU):
                ds.append([dau, cuoi])
        for b0, b1 in khoang_da_ban:
            ds = _tru_khoang(ds, b0, b1)
        khoang_ranh[ngay] = ds
        ngay += timedelta(days=1)

    # Bước 2: tính điểm và sắp xếp
    for nv in ds_nhiem_vu:
        nv.diem = tinh_diem_uu_tien(nv.han, nv.do_quan_trong, nv.phut_con_lai, bay_gio)
    xep_hang = sorted(ds_nhiem_vu, key=lambda nv: (-nv.diem, nv.han))

    # Bước 3: xếp lần lượt vào khung giờ rảnh
    buoi_moi, khong_xep = [], []
    for nv in xep_hang:
        con_lai = nv.phut_con_lai
        if nv.han <= bay_gio:
            khong_xep.append({'nhiem_vu_id': nv.id, 'so_phut_thieu': con_lai,
                              'ly_do': 'Nhiệm vụ đã quá hạn.'})
            continue
        han_ngay = timezone.localtime(nv.han).date()
        ngay = ngay_bat_dau
        while con_lai > 0 and ngay <= ngay_ket_thuc and ngay <= han_ngay:
            ds = khoang_ranh[ngay]
            i = 0
            while con_lai > 0 and i < len(ds) and gioi_han_phut - da_dung[ngay] > 0:
                dau, cuoi = ds[i]
                cuoi_hieu_luc = min(cuoi, nv.han)  # phải xong trước deadline
                kha_dung = int((cuoi_hieu_luc - dau).total_seconds() // 60)
                con_quota = gioi_han_phut - da_dung[ngay]
                doan = min(con_lai, BUOI_TOI_DA, kha_dung, con_quota)
                if doan <= 0 or (doan < BUOI_TOI_THIEU and doan < con_lai):
                    i += 1
                    continue
                ket_thuc_buoi = dau + timedelta(minutes=doan)
                buoi_moi.append({'nhiem_vu_id': nv.id, 'bat_dau': dau, 'ket_thuc': ket_thuc_buoi})
                con_lai -= doan
                da_dung[ngay] += doan
                bat_dau_tiep = ket_thuc_buoi + timedelta(minutes=NGHI_GIUA_BUOI)
                if bat_dau_tiep < cuoi:
                    ds[i] = [bat_dau_tiep, cuoi]
                else:
                    ds.pop(i)
            ngay += timedelta(days=1)
        if con_lai > 0:
            khong_xep.append({'nhiem_vu_id': nv.id, 'so_phut_thieu': con_lai,
                              'ly_do': 'Không đủ khung giờ rảnh trước deadline.'})

    buoi_moi.sort(key=lambda b: b['bat_dau'])
    return {
        'buoi': buoi_moi,
        'khong_xep_duoc': khong_xep,
        'thu_tu_uu_tien': [{'nhiem_vu_id': nv.id, 'diem': nv.diem} for nv in xep_hang],
    }


# ---------------------------------------------------------------------------
# Phần làm việc với CSDL
# ---------------------------------------------------------------------------
def _phut(buoi):
    return int((buoi.thoi_gian_ket_thuc - buoi.thoi_gian_bat_dau).total_seconds() // 60)


def phut_da_hoan_thanh(nhiem_vu):
    """Tổng số phút các buổi học đã hoàn thành của một nhiệm vụ."""
    buoi_xong = nhiem_vu.danh_sach_buoi_hoc.filter(trang_thai=BuoiHoc.TrangThai.HOAN_THANH)
    return sum(_phut(b) for b in buoi_xong)


def cap_nhat_trang_thai_nhiem_vu(nhiem_vu):
    """Gọi sau khi đổi trạng thái buổi học: đủ thời lượng thì nhiệm vụ tự chuyển 'đã xong'."""
    da_hoc = phut_da_hoan_thanh(nhiem_vu)
    if da_hoc >= nhiem_vu.thoi_luong_du_kien:
        if nhiem_vu.trang_thai != NhiemVu.TrangThai.DA_XONG:
            nhiem_vu.trang_thai = NhiemVu.TrangThai.DA_XONG
            nhiem_vu.thoi_diem_hoan_thanh = timezone.now()
            nhiem_vu.save(update_fields=['trang_thai', 'thoi_diem_hoan_thanh', 'ngay_cap_nhat'])
    elif da_hoc > 0 and nhiem_vu.trang_thai == NhiemVu.TrangThai.CHUA_LAM:
        nhiem_vu.trang_thai = NhiemVu.TrangThai.DANG_LAM
        nhiem_vu.save(update_fields=['trang_thai', 'ngay_cap_nhat'])


def _xep_va_luu(nguoi_dung, ke_hoach, bay_gio):
    ho_so, _ = HoSo.objects.get_or_create(nguoi_dung=nguoi_dung)
    gioi_han = int(ho_so.so_gio_hoc_toi_da_moi_ngay * 60)
    ngay_bd = max(ke_hoach.ngay_bat_dau, bay_gio.date())

    khung_gio = defaultdict(list)
    for k in KhungGioRanh.objects.filter(nguoi_dung=nguoi_dung):
        khung_gio[k.thu_trong_tuan].append((k.gio_bat_dau, k.gio_ket_thuc))

    ds_nhiem_vu = []
    ds_goc = NhiemVu.objects.filter(nguoi_dung=nguoi_dung).exclude(
        trang_thai=NhiemVu.TrangThai.DA_XONG)
    for nv in ds_goc:
        con_lai = nv.thoi_luong_du_kien - phut_da_hoan_thanh(nv)
        if con_lai > 0:
            ds_nhiem_vu.append(NhiemVuXep(id=nv.id, han=nv.han_hoan_thanh,
                                          do_quan_trong=nv.do_quan_trong, phut_con_lai=con_lai))

    # Các buổi đã hoàn thành/bỏ lỡ vẫn chiếm chỗ; buổi đã hoàn thành tính vào giới hạn giờ/ngày
    moc_dau = timezone.make_aware(datetime.combine(ngay_bd, time.min))
    khoang_da_ban, phut_da_hoc = [], defaultdict(int)
    da_co = BuoiHoc.objects.filter(
        ke_hoach__nguoi_dung=nguoi_dung,
        trang_thai__in=[BuoiHoc.TrangThai.HOAN_THANH, BuoiHoc.TrangThai.BO_LO],
        thoi_gian_ket_thuc__gt=moc_dau,
    )
    for b in da_co:
        khoang_da_ban.append((b.thoi_gian_bat_dau, b.thoi_gian_ket_thuc))
        if b.trang_thai == BuoiHoc.TrangThai.HOAN_THANH:
            phut_da_hoc[timezone.localtime(b.thoi_gian_bat_dau).date()] += _phut(b)

    ket_qua = thuat_toan_xep_lich(ds_nhiem_vu, khung_gio, ngay_bd, ke_hoach.ngay_ket_thuc,
                                  bay_gio, gioi_han, khoang_da_ban, phut_da_hoc)
    BuoiHoc.objects.bulk_create([
        BuoiHoc(ke_hoach=ke_hoach, nhiem_vu_id=b['nhiem_vu_id'],
                thoi_gian_bat_dau=b['bat_dau'], thoi_gian_ket_thuc=b['ket_thuc'])
        for b in ket_qua['buoi']
    ])
    return ket_qua


def _don_buoi_cu(buoi_qs, bay_gio):
    """Buổi dự kiến đã qua mà chưa đánh dấu -> tự tính là bỏ lỡ; buổi dự kiến còn lại -> xóa để xếp lại."""
    buoi_qs.filter(trang_thai=BuoiHoc.TrangThai.DU_KIEN,
                   thoi_gian_ket_thuc__lt=bay_gio).update(trang_thai=BuoiHoc.TrangThai.BO_LO)
    buoi_qs.filter(trang_thai=BuoiHoc.TrangThai.DU_KIEN).delete()


@transaction.atomic
def tao_ke_hoach(nguoi_dung, ngay_bat_dau, so_ngay):
    bay_gio = _lam_tron_len_5_phut(timezone.localtime())
    _don_buoi_cu(BuoiHoc.objects.filter(ke_hoach__nguoi_dung=nguoi_dung), bay_gio)
    ke_hoach = KeHoachHocTap.objects.create(
        nguoi_dung=nguoi_dung,
        ngay_bat_dau=ngay_bat_dau,
        ngay_ket_thuc=ngay_bat_dau + timedelta(days=so_ngay - 1),
        nguon_tao=KeHoachHocTap.NguonTao.QUY_TAC,
    )
    ket_qua = _xep_va_luu(nguoi_dung, ke_hoach, bay_gio)
    return ke_hoach, ket_qua


@transaction.atomic
def xep_lai_ke_hoach(ke_hoach):
    bay_gio = _lam_tron_len_5_phut(timezone.localtime())
    if bay_gio.date() > ke_hoach.ngay_ket_thuc:
        raise ValueError('Kế hoạch này đã hết hạn, hãy tạo kế hoạch mới.')
    _don_buoi_cu(ke_hoach.danh_sach_buoi_hoc.all(), bay_gio)
    return _xep_va_luu(ke_hoach.nguoi_dung, ke_hoach, bay_gio)