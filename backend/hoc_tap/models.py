"""
models.py - App `hoc_tap`
Đồ án: Xây dựng ứng dụng AI hỗ trợ lập kế hoạch học tập cá nhân hóa

Quy ước đặt tên:
- Lớp (model): PascalCase, tiếng Việt không dấu (vd: MonHoc)
- Bảng, cột: snake_case, tiếng Việt không dấu (vd: mon_hoc, han_hoan_thanh)
- Bảng người dùng dùng User có sẵn của Django (settings.AUTH_USER_MODEL)
"""
from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.db.models.signals import post_save
from django.dispatch import receiver


# ---------------------------------------------------------------------------
# Lớp cha trừu tượng: mọi bảng đều có ngay_tao / ngay_cap_nhat
# (abstract = True nghĩa là Django KHÔNG tạo bảng cho lớp này,
#  chỉ dùng để các lớp khác kế thừa 2 cột bên dưới)
# ---------------------------------------------------------------------------
class MocThoiGian(models.Model):
    ngay_tao = models.DateTimeField("ngày tạo", auto_now_add=True)
    ngay_cap_nhat = models.DateTimeField("ngày cập nhật", auto_now=True)

    class Meta:
        abstract = True


# ---------------------------------------------------------------------------
# 1. ho_so: thông tin mở rộng của người dùng (quan hệ 1-1 với User)
# ---------------------------------------------------------------------------
class HoSo(MocThoiGian):
    nguoi_dung = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="ho_so",
        verbose_name="người dùng",
    )
    so_gio_hoc_toi_da_moi_ngay = models.DecimalField(
        "số giờ học tối đa mỗi ngày",
        max_digits=4,
        decimal_places=1,
        default=4,
        validators=[MinValueValidator(0.5), MaxValueValidator(16)],
    )

    class Meta:
        db_table = "ho_so"
        verbose_name = "hồ sơ"
        verbose_name_plural = "hồ sơ"

    def __str__(self):
        return f"Hồ sơ của {self.nguoi_dung}"


@receiver(post_save, sender=settings.AUTH_USER_MODEL)
def tu_dong_tao_ho_so(sender, instance, created, **kwargs):
    """Mỗi khi tạo User mới (đăng ký) thì tự tạo luôn HoSo với giá trị mặc định."""
    if created:
        HoSo.objects.create(nguoi_dung=instance)


# ---------------------------------------------------------------------------
# 2. mon_hoc
# ---------------------------------------------------------------------------
class MonHoc(MocThoiGian):
    nguoi_dung = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="danh_sach_mon_hoc",
        verbose_name="người dùng",
    )
    ten_mon = models.CharField("tên môn", max_length=150)
    mau_sac = models.CharField(
        "màu sắc (mã hex)", max_length=7, default="#2196F3",
        help_text="Ví dụ: #2196F3",
    )
    hoc_ky = models.CharField("học kỳ", max_length=50, blank=True, default="")

    class Meta:
        db_table = "mon_hoc"
        verbose_name = "môn học"
        verbose_name_plural = "môn học"
        ordering = ["ten_mon"]
        constraints = [
            models.UniqueConstraint(
                fields=["nguoi_dung", "ten_mon", "hoc_ky"],
                name="mon_hoc_duy_nhat_theo_nguoi_dung",
            )
        ]

    def __str__(self):
        return self.ten_mon


# ---------------------------------------------------------------------------
# 3. muc_tieu (tùy chọn)
# ---------------------------------------------------------------------------
class MucTieu(MocThoiGian):
    class TrangThai(models.TextChoices):
        DANG_THUC_HIEN = "dang_thuc_hien", "Đang thực hiện"
        HOAN_THANH = "hoan_thanh", "Hoàn thành"

    nguoi_dung = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="danh_sach_muc_tieu",
        verbose_name="người dùng",
    )
    tieu_de = models.CharField("tiêu đề", max_length=200)
    mo_ta = models.TextField("mô tả", blank=True, default="")
    ngay_dat_muc_tieu = models.DateField("ngày đạt mục tiêu", null=True, blank=True)
    trang_thai = models.CharField(
        "trạng thái", max_length=20,
        choices=TrangThai.choices, default=TrangThai.DANG_THUC_HIEN,
    )

    class Meta:
        db_table = "muc_tieu"
        verbose_name = "mục tiêu"
        verbose_name_plural = "mục tiêu"
        ordering = ["ngay_dat_muc_tieu"]

    def __str__(self):
        return self.tieu_de


# ---------------------------------------------------------------------------
# 4. nhiem_vu
# ---------------------------------------------------------------------------
class NhiemVu(MocThoiGian):
    class DoQuanTrong(models.IntegerChoices):
        THAP = 1, "Thấp"
        TRUNG_BINH = 2, "Trung bình"
        CAO = 3, "Cao"

    class TrangThai(models.TextChoices):
        CHUA_LAM = "chua_lam", "Chưa làm"
        DANG_LAM = "dang_lam", "Đang làm"
        DA_XONG = "da_xong", "Đã xong"

    nguoi_dung = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="danh_sach_nhiem_vu",
        verbose_name="người dùng",
    )
    mon_hoc = models.ForeignKey(
        MonHoc,
        on_delete=models.CASCADE,
        related_name="danh_sach_nhiem_vu",
        verbose_name="môn học",
    )
    muc_tieu = models.ForeignKey(
        MucTieu,
        on_delete=models.SET_NULL,  # xóa mục tiêu thì nhiệm vụ vẫn còn
        null=True,
        blank=True,
        related_name="danh_sach_nhiem_vu",
        verbose_name="mục tiêu",
    )
    tieu_de = models.CharField("tiêu đề", max_length=200)
    mo_ta = models.TextField("mô tả", blank=True, default="")
    han_hoan_thanh = models.DateTimeField("hạn hoàn thành (deadline)")
    thoi_luong_du_kien = models.PositiveIntegerField(
        "thời lượng dự kiến (phút)",
        validators=[MinValueValidator(5), MaxValueValidator(1440)],
    )
    do_quan_trong = models.PositiveSmallIntegerField(
        "độ quan trọng",
        choices=DoQuanTrong.choices,
        default=DoQuanTrong.TRUNG_BINH,
    )
    trang_thai = models.CharField(
        "trạng thái", max_length=20,
        choices=TrangThai.choices, default=TrangThai.CHUA_LAM,
    )
    thoi_diem_hoan_thanh = models.DateTimeField(
        "thời điểm hoàn thành", null=True, blank=True
    )

    class Meta:
        db_table = "nhiem_vu"
        verbose_name = "nhiệm vụ"
        verbose_name_plural = "nhiệm vụ"
        ordering = ["han_hoan_thanh"]
        indexes = [
            models.Index(
                fields=["nguoi_dung", "trang_thai", "han_hoan_thanh"],
                name="nhiem_vu_loc_chinh_idx",
            )
        ]

    def clean(self):
        # Môn học phải thuộc cùng người dùng với nhiệm vụ
        if self.mon_hoc_id and self.mon_hoc.nguoi_dung_id != self.nguoi_dung_id:
            raise ValidationError("Môn học không thuộc về người dùng này.")
        if self.muc_tieu_id and self.muc_tieu.nguoi_dung_id != self.nguoi_dung_id:
            raise ValidationError("Mục tiêu không thuộc về người dùng này.")

    def __str__(self):
        return self.tieu_de


# ---------------------------------------------------------------------------
# 5. khung_gio_ranh
# ---------------------------------------------------------------------------
class KhungGioRanh(MocThoiGian):
    class ThuTrongTuan(models.IntegerChoices):
        # Cùng quy ước với date.weekday() của Python: 0 = Thứ Hai ... 6 = Chủ nhật
        THU_HAI = 0, "Thứ Hai"
        THU_BA = 1, "Thứ Ba"
        THU_TU = 2, "Thứ Tư"
        THU_NAM = 3, "Thứ Năm"
        THU_SAU = 4, "Thứ Sáu"
        THU_BAY = 5, "Thứ Bảy"
        CHU_NHAT = 6, "Chủ nhật"

    nguoi_dung = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="danh_sach_khung_gio_ranh",
        verbose_name="người dùng",
    )
    thu_trong_tuan = models.PositiveSmallIntegerField(
        "thứ trong tuần", choices=ThuTrongTuan.choices
    )
    gio_bat_dau = models.TimeField("giờ bắt đầu")
    gio_ket_thuc = models.TimeField("giờ kết thúc")

    class Meta:
        db_table = "khung_gio_ranh"
        verbose_name = "khung giờ rảnh"
        verbose_name_plural = "khung giờ rảnh"
        ordering = ["thu_trong_tuan", "gio_bat_dau"]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(gio_ket_thuc__gt=models.F("gio_bat_dau")),
                name="khung_gio_ranh_gio_ket_thuc_sau_gio_bat_dau",
            )
        ]

    def clean(self):
        if self.gio_bat_dau and self.gio_ket_thuc and self.gio_ket_thuc <= self.gio_bat_dau:
            raise ValidationError("Giờ kết thúc phải sau giờ bắt đầu.")

    def __str__(self):
        return f"{self.get_thu_trong_tuan_display()} {self.gio_bat_dau:%H:%M}-{self.gio_ket_thuc:%H:%M}"


# ---------------------------------------------------------------------------
# 6. ke_hoach_hoc_tap
# ---------------------------------------------------------------------------
class KeHoachHocTap(MocThoiGian):
    class NguonTao(models.TextChoices):
        QUY_TAC = "quy_tac", "Thuật toán quy tắc"
        AI = "ai", "AI"

    nguoi_dung = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="danh_sach_ke_hoach",
        verbose_name="người dùng",
    )
    ngay_bat_dau = models.DateField("ngày bắt đầu")
    ngay_ket_thuc = models.DateField("ngày kết thúc")
    nguon_tao = models.CharField(
        "nguồn tạo", max_length=10,
        choices=NguonTao.choices, default=NguonTao.QUY_TAC,
    )
    tom_tat_ai = models.TextField("tóm tắt/giải thích của AI", blank=True, default="")

    class Meta:
        db_table = "ke_hoach_hoc_tap"
        verbose_name = "kế hoạch học tập"
        verbose_name_plural = "kế hoạch học tập"
        ordering = ["-ngay_tao"]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(ngay_ket_thuc__gte=models.F("ngay_bat_dau")),
                name="ke_hoach_ngay_ket_thuc_khong_truoc_ngay_bat_dau",
            )
        ]

    def __str__(self):
        return f"Kế hoạch {self.ngay_bat_dau} → {self.ngay_ket_thuc}"


# ---------------------------------------------------------------------------
# 7. buoi_hoc: từng buổi học cụ thể được xếp vào lịch
#    (xếp lại lịch = xóa/tạo lại các buoi_hoc, nhiem_vu giữ nguyên)
# ---------------------------------------------------------------------------
class BuoiHoc(MocThoiGian):
    class TrangThai(models.TextChoices):
        DU_KIEN = "du_kien", "Dự kiến"
        HOAN_THANH = "hoan_thanh", "Hoàn thành"
        BO_LO = "bo_lo", "Bỏ lỡ"

    ke_hoach = models.ForeignKey(
        KeHoachHocTap,
        on_delete=models.CASCADE,
        related_name="danh_sach_buoi_hoc",
        verbose_name="kế hoạch",
    )
    nhiem_vu = models.ForeignKey(
        NhiemVu,
        on_delete=models.CASCADE,
        related_name="danh_sach_buoi_hoc",
        verbose_name="nhiệm vụ",
    )
    thoi_gian_bat_dau = models.DateTimeField("thời gian bắt đầu")
    thoi_gian_ket_thuc = models.DateTimeField("thời gian kết thúc")
    trang_thai = models.CharField(
        "trạng thái", max_length=20,
        choices=TrangThai.choices, default=TrangThai.DU_KIEN,
    )

    class Meta:
        db_table = "buoi_hoc"
        verbose_name = "buổi học"
        verbose_name_plural = "buổi học"
        ordering = ["thoi_gian_bat_dau"]
        indexes = [
            models.Index(fields=["ke_hoach", "thoi_gian_bat_dau"], name="buoi_hoc_ke_hoach_tg_idx"),
        ]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(thoi_gian_ket_thuc__gt=models.F("thoi_gian_bat_dau")),
                name="buoi_hoc_ket_thuc_sau_bat_dau",
            )
        ]

    def __str__(self):
        return f"{self.nhiem_vu} ({self.thoi_gian_bat_dau:%d/%m %H:%M})"


# ---------------------------------------------------------------------------
# 8. nhat_ky_ai: lưu lại mỗi lần gọi AI (để debug, làm minh chứng trong báo cáo)
# ---------------------------------------------------------------------------
class NhatKyAI(MocThoiGian):
    nguoi_dung = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="danh_sach_nhat_ky_ai",
        verbose_name="người dùng",
    )
    ke_hoach = models.ForeignKey(
        KeHoachHocTap,
        on_delete=models.SET_NULL,  # xóa kế hoạch vẫn giữ nhật ký
        null=True,
        blank=True,
        related_name="danh_sach_nhat_ky_ai",
        verbose_name="kế hoạch",
    )
    du_lieu_gui = models.JSONField("dữ liệu gửi", default=dict)
    # Dùng TextField (không phải JSONField) vì AI có thể trả về chuỗi KHÔNG phải JSON hợp lệ
    du_lieu_nhan = models.TextField("dữ liệu nhận", blank=True, default="")
    thanh_cong = models.BooleanField("thành công", default=False)

    class Meta:
        db_table = "nhat_ky_ai"
        verbose_name = "nhật ký AI"
        verbose_name_plural = "nhật ký AI"
        ordering = ["-ngay_tao"]

    def __str__(self):
        return f"AI {self.ngay_tao:%d/%m/%Y %H:%M} - {'OK' if self.thanh_cong else 'LỖI'}"