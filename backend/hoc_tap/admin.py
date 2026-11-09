from django.contrib import admin
from .models import HoSo, MonHoc, MucTieu, NhiemVu, KhungGioRanh, KeHoachHocTap, BuoiHoc, NhatKyAI

for mo_hinh in [HoSo, MonHoc, MucTieu, NhiemVu, KhungGioRanh, KeHoachHocTap, BuoiHoc, NhatKyAI]:
    admin.site.register(mo_hinh)