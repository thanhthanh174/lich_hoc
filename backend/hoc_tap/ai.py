"""ai.py - Gọi Gemini để giải thích/gợi ý kế hoạch học tập (có kiểm tra JSON và phương án dự phòng)."""
import json
import os
import re
import time

import requests
from django.utils import timezone

from .models import BuoiHoc, NhatKyAI, NhiemVu

URL_GOC = "https://generativelanguage.googleapis.com/v1beta/models"
TONG_THOI_GIAN = 30        # giây, tổng thời gian chờ AI cho một yêu cầu
THOI_GIAN_MOI_LAN = 15     # giây, timeout cho mỗi lần gọi
SO_LAN_THU_MOI_MO_HINH = 2
MA_LOI_THU_LAI = {429, 500, 502, 503, 504}

HUONG_DAN = (
    "Bạn là trợ lý học tập cho sinh viên Việt Nam. Dựa trên dữ liệu JSON bên dưới, "
    "hãy giải thích ngắn gọn vì sao kế hoạch được xếp như vậy và đưa ra gợi ý thực tế. "
    "Quy tắc: viết tiếng Việt, giọng thân thiện; không bịa thêm nhiệm vụ hay số liệu ngoài dữ liệu. "
    "Xưng hô: luôn gọi người dùng là \"bà\", tuyệt đối không dùng từ \"bạn\" để gọi người dùng. "
    "Tỉ lệ phải viết dưới dạng phần trăm, ví dụ 0.25 viết là \"25%\", 0.6 viết là \"60%\"; "
    "không bao giờ viết số thập phân như 0.25. "
    "Nếu ti_le_hoan_thanh là null thì nói là chưa đủ dữ liệu, đừng suy đoán. "
    "Nếu ti_le_hoan_thanh dưới 0.6 thì gợi ý giảm tải hoặc chia nhỏ buổi học; "
    "nếu từ 0.8 trở lên thì khen ngắn. "
    "Chỉ trả về MỘT đối tượng JSON, không kèm chữ nào khác, đúng dạng: "
    '{"tom_tat": "...", "goi_y": ["...", "..."], "canh_bao": ["..."]}. '
    "tom_tat tối đa 3 câu; goi_y từ 2 đến 4 mục; canh_bao là mảng rỗng nếu không có vấn đề, "
    "còn mỗi nhiệm vụ có so_phut_thieu lớn hơn 0 hoặc qua_han là true thì cần một cảnh báo."
)


def _phut(bat_dau, ket_thuc):
    return int((ket_thuc - bat_dau).total_seconds() // 60)


# ---------------------------------------------------------------------------
# 1. Thu thập dữ liệu gửi cho AI (không gửi email/tên đăng nhập)
# ---------------------------------------------------------------------------
def thu_thap_du_lieu(ke_hoach):
    nguoi_dung = ke_hoach.nguoi_dung
    bay_gio = timezone.now()

    phut_hoan_thanh = {}   # nhiem_vu_id -> phút đã hoàn thành (mọi kế hoạch)
    phut_da_xep = {}       # nhiem_vu_id -> phút dự kiến trong kế hoạch này
    so_hoan_thanh = 0
    so_bo_lo = 0
    so_buoi_du_kien = 0
    tong_phut_du_kien = 0

    cac_buoi = BuoiHoc.objects.filter(ke_hoach__nguoi_dung=nguoi_dung)
    for b in cac_buoi:
        phut = _phut(b.thoi_gian_bat_dau, b.thoi_gian_ket_thuc)
        if b.trang_thai == BuoiHoc.TrangThai.HOAN_THANH:
            so_hoan_thanh += 1
            phut_hoan_thanh[b.nhiem_vu_id] = phut_hoan_thanh.get(b.nhiem_vu_id, 0) + phut
        elif b.trang_thai == BuoiHoc.TrangThai.BO_LO:
            so_bo_lo += 1
        elif b.trang_thai == BuoiHoc.TrangThai.DU_KIEN and b.ke_hoach_id == ke_hoach.id:
            so_buoi_du_kien += 1
            tong_phut_du_kien += phut
            phut_da_xep[b.nhiem_vu_id] = phut_da_xep.get(b.nhiem_vu_id, 0) + phut

    tong = so_hoan_thanh + so_bo_lo
    ti_le = round(so_hoan_thanh / tong, 2) if tong else None

    cac_nhiem_vu = []
    ds = (NhiemVu.objects.filter(nguoi_dung=nguoi_dung)
          .exclude(trang_thai=NhiemVu.TrangThai.DA_XONG)
          .select_related("mon_hoc").order_by("han_hoan_thanh"))
    for nv in ds:
        con_lai = max(0, nv.thoi_luong_du_kien - phut_hoan_thanh.get(nv.id, 0))
        if con_lai == 0:
            continue
        da_xep = phut_da_xep.get(nv.id, 0)
        cac_nhiem_vu.append({
            "tieu_de": nv.tieu_de,
            "mon_hoc": nv.mon_hoc.ten_mon,
            "han": timezone.localtime(nv.han_hoan_thanh).strftime("%d/%m/%Y %H:%M"),
            "qua_han": nv.han_hoan_thanh < bay_gio,
            "do_quan_trong": nv.do_quan_trong,
            "phut_con_lai": con_lai,
            "phut_da_xep": da_xep,
            "so_phut_thieu": max(0, con_lai - da_xep),
        })

    return {
        "ngay_bat_dau": ke_hoach.ngay_bat_dau.strftime("%d/%m/%Y"),
        "ngay_ket_thuc": ke_hoach.ngay_ket_thuc.strftime("%d/%m/%Y"),
        "so_buoi_du_kien": so_buoi_du_kien,
        "tong_phut_du_kien": tong_phut_du_kien,
        "so_buoi_hoan_thanh": so_hoan_thanh,
        "so_buoi_bo_lo": so_bo_lo,
        "ti_le_hoan_thanh": ti_le,
        "nhiem_vu": cac_nhiem_vu[:15],
    }


# ---------------------------------------------------------------------------
# 2. Kiểm tra JSON do AI trả về (schema đơn giản)
# ---------------------------------------------------------------------------
def kiem_tra_ket_qua(van_ban):
    s = van_ban.strip()
    s = re.sub(r"^```(?:json)?\s*|\s*```$", "", s).strip()
    du = json.loads(s)  # sai JSON -> ném ValueError
    if not isinstance(du, dict):
        raise ValueError("Kết quả không phải đối tượng JSON.")

    tom_tat = du.get("tom_tat")
    if not isinstance(tom_tat, str) or not tom_tat.strip():
        raise ValueError("Thiếu trường tom_tat.")

    goi_y = du.get("goi_y")
    if (not isinstance(goi_y, list) or not goi_y
            or not all(isinstance(x, str) and x.strip() for x in goi_y)):
        raise ValueError("Trường goi_y không hợp lệ.")

    canh_bao = du.get("canh_bao", [])
    if not isinstance(canh_bao, list) or not all(isinstance(x, str) for x in canh_bao):
        raise ValueError("Trường canh_bao không hợp lệ.")

    return {
        "tom_tat": tom_tat.strip()[:600],
        "goi_y": [x.strip()[:300] for x in goi_y[:5]],
        "canh_bao": [x.strip()[:300] for x in canh_bao[:5] if x.strip()],
    }


def _lay_van_ban(phan_hoi):
    cac_phan = phan_hoi["candidates"][0]["content"]["parts"]
    return "".join(p.get("text", "") for p in cac_phan if not p.get("thought"))


# ---------------------------------------------------------------------------
# 3. Gọi Gemini: thử lại khi 429/5xx/lỗi mạng, đổi sang model dự phòng
# ---------------------------------------------------------------------------
def goi_gemini(du_lieu):
    """Trả về (ket_qua | None, ten_mo_hinh | None, cac_lan_thu, van_ban_tho)."""
    khoa = os.environ.get("GEMINI_API_KEY")
    cac_mo_hinh = [m for m in (os.environ.get("GEMINI_MODEL"),
                               os.environ.get("GEMINI_MODEL_DU_PHONG")) if m]
    cac_lan = []
    van_ban_tho = ""
    if not khoa or not cac_mo_hinh:
        cac_lan.append({"loi": "Thiếu biến môi trường GEMINI_API_KEY hoặc GEMINI_MODEL."})
        return None, None, cac_lan, van_ban_tho

    noi_dung_gui = (HUONG_DAN + "\n\nDữ liệu:\n"
                    + json.dumps(du_lieu, ensure_ascii=False))
    than = {
        "contents": [{"parts": [{"text": noi_dung_gui}]}],
        "generationConfig": {
            "responseMimeType": "application/json",
            "temperature": 0.4,
            "maxOutputTokens": 2000,
        },
    }
    bat_dau = time.monotonic()

    for mo_hinh in cac_mo_hinh:
        url = f"{URL_GOC}/{mo_hinh}:generateContent"
        for lan in range(1, SO_LAN_THU_MOI_MO_HINH + 1):
            con_lai = TONG_THOI_GIAN - (time.monotonic() - bat_dau)
            if con_lai < 3:
                cac_lan.append({"mo_hinh": mo_hinh, "lan": lan, "loi": "Hết thời gian chờ tổng."})
                return None, None, cac_lan, van_ban_tho
            muc = {"mo_hinh": mo_hinh, "lan": lan}
            cac_lan.append(muc)
            try:
                res = requests.post(
                    url,
                    headers={"x-goog-api-key": khoa, "Content-Type": "application/json"},
                    json=than,
                    timeout=min(THOI_GIAN_MOI_LAN, con_lai),
                )
            except requests.exceptions.RequestException as loi:
                muc["loi"] = f"Lỗi mạng ({type(loi).__name__})"
                time.sleep(1.5)
                continue

            muc["ma"] = res.status_code
            if res.status_code == 200:
                try:
                    van_ban_tho = _lay_van_ban(res.json())
                    ket_qua = kiem_tra_ket_qua(van_ban_tho)
                    return ket_qua, mo_hinh, cac_lan, van_ban_tho
                except (KeyError, IndexError, TypeError, ValueError) as loi:
                    muc["loi"] = f"Phản hồi không hợp lệ: {loi}"
                    continue  # thử lại cùng model
            muc["loi"] = res.text[:200]
            if res.status_code in MA_LOI_THU_LAI:
                time.sleep(1.5)
                continue
            break  # 400/403/404: đổi sang model khác ngay

    return None, None, cac_lan, van_ban_tho


# ---------------------------------------------------------------------------
# 4. Phương án dự phòng: tự viết giải thích từ số liệu khi AI lỗi
# ---------------------------------------------------------------------------
def giai_thich_du_phong(du_lieu):
    cac_nv = du_lieu["nhiem_vu"]
    tom_tat = (
        f"Kế hoạch từ {du_lieu['ngay_bat_dau']} đến {du_lieu['ngay_ket_thuc']} có "
        f"{du_lieu['so_buoi_du_kien']} buổi học dự kiến, tổng {du_lieu['tong_phut_du_kien']} phút. "
        "Hệ thống ưu tiên nhiệm vụ có hạn gần, độ quan trọng cao và còn nhiều việc phải làm."
    )
    goi_y = []
    if cac_nv:
        dau = cac_nv[0]
        goi_y.append(f'Nên bắt đầu với "{dau["tieu_de"]}" vì hạn gần nhất ({dau["han"]}).')
    ti_le = du_lieu["ti_le_hoan_thanh"]
    if ti_le is not None:
        goi_y.append(f"Tỉ lệ hoàn thành các buổi học của bà hiện là {round(ti_le * 100)}%.")
    goi_y.append("Hãy đánh dấu hoàn thành hoặc bỏ lỡ sau mỗi buổi để lịch được xếp lại sát thực tế hơn.")

    canh_bao = []
    for nv in cac_nv:
        if nv["qua_han"]:
            canh_bao.append(f'"{nv["tieu_de"]}" đã quá hạn.')
        elif nv["so_phut_thieu"] > 0:
            canh_bao.append(f'"{nv["tieu_de"]}" còn thiếu {nv["so_phut_thieu"]} phút chưa xếp được.')
    return {"tom_tat": tom_tat, "goi_y": goi_y[:4], "canh_bao": canh_bao[:5]}


# ---------------------------------------------------------------------------
# 5. Hàm chính được view gọi
# ---------------------------------------------------------------------------
def tao_giai_thich(ke_hoach):
    du_lieu = thu_thap_du_lieu(ke_hoach)
    ket_qua, mo_hinh, cac_lan, van_ban_tho = goi_gemini(du_lieu)

    thanh_cong = ket_qua is not None
    if not thanh_cong:
        ket_qua = giai_thich_du_phong(du_lieu)

    noi_dung = {**ket_qua, "nguon": "ai" if thanh_cong else "du_phong", "mo_hinh": mo_hinh}

    NhatKyAI.objects.create(
        nguoi_dung=ke_hoach.nguoi_dung,
        ke_hoach=ke_hoach,
        du_lieu_gui={"du_lieu": du_lieu, "cac_lan_thu": cac_lan},
        du_lieu_nhan=van_ban_tho or json.dumps(cac_lan, ensure_ascii=False),
        thanh_cong=thanh_cong,
    )
    ke_hoach.tom_tat_ai = json.dumps(noi_dung, ensure_ascii=False)
    ke_hoach.save(update_fields=["tom_tat_ai", "ngay_cap_nhat"])
    return noi_dung