from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework import serializers

from .models import BuoiHoc, HoSo, KeHoachHocTap, KhungGioRanh, MonHoc, NhiemVu

User = get_user_model()


class DangKySerializer(serializers.ModelSerializer):
    mat_khau = serializers.CharField(
        write_only=True,
        min_length=6,
        error_messages={
            'min_length': 'Mật khẩu phải có ít nhất 6 ký tự.',
            'blank': 'Mật khẩu không được để trống.',
        },
    )

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'mat_khau']

    def create(self, validated_data):
        return User.objects.create_user(
            username=validated_data['username'],
            email=validated_data.get('email', ''),
            password=validated_data['mat_khau'],
        )


class HoSoSerializer(serializers.ModelSerializer):
    so_gio_hoc_toi_da_moi_ngay = serializers.DecimalField(
        max_digits=4, decimal_places=1,
        min_value=0.5, max_value=16,
        coerce_to_string=False,
        error_messages={
            'min_value': 'Số giờ học tối đa mỗi ngày phải từ 0.5 giờ trở lên.',
            'max_value': 'Số giờ học tối đa mỗi ngày không được quá 16 giờ.',
        },
    )

    class Meta:
        model = HoSo
        fields = ['so_gio_hoc_toi_da_moi_ngay']


class MonHocSerializer(serializers.ModelSerializer):
    class Meta:
        model = MonHoc
        fields = ['id', 'ten_mon', 'mau_sac', 'hoc_ky', 'ngay_tao', 'ngay_cap_nhat']
        read_only_fields = ['ngay_tao', 'ngay_cap_nhat']

    def validate(self, attrs):
        nguoi_dung = self.context['request'].user
        ten_mon = attrs.get('ten_mon', getattr(self.instance, 'ten_mon', None))
        hoc_ky = attrs.get('hoc_ky', getattr(self.instance, 'hoc_ky', ''))
        trung = MonHoc.objects.filter(nguoi_dung=nguoi_dung, ten_mon=ten_mon, hoc_ky=hoc_ky)
        if self.instance:
            trung = trung.exclude(pk=self.instance.pk)
        if trung.exists():
            raise serializers.ValidationError('Môn học này đã tồn tại trong học kỳ.')
        return attrs


class NhiemVuSerializer(serializers.ModelSerializer):
    # Trả thêm tên môn và màu để màn hình Flutter hiển thị không cần gọi API khác
    ten_mon = serializers.CharField(source='mon_hoc.ten_mon', read_only=True)
    mau_sac = serializers.CharField(source='mon_hoc.mau_sac', read_only=True)

    class Meta:
        model = NhiemVu
        fields = [
            'id', 'mon_hoc', 'ten_mon', 'mau_sac', 'tieu_de', 'mo_ta',
            'han_hoan_thanh', 'thoi_luong_du_kien', 'do_quan_trong',
            'trang_thai', 'thoi_diem_hoan_thanh', 'ngay_tao', 'ngay_cap_nhat',
        ]
        read_only_fields = ['thoi_diem_hoan_thanh', 'ngay_tao', 'ngay_cap_nhat']

    def validate_mon_hoc(self, gia_tri):
        if gia_tri.nguoi_dung_id != self.context['request'].user.id:
            raise serializers.ValidationError('Môn học không tồn tại.')
        return gia_tri

    @staticmethod
    def _gan_thoi_diem_hoan_thanh(du_lieu, trang_thai_cu=None):
        """Tự đặt/xóa thoi_diem_hoan_thanh theo trạng thái."""
        trang_thai = du_lieu.get('trang_thai', trang_thai_cu)
        if trang_thai == NhiemVu.TrangThai.DA_XONG:
            if trang_thai_cu != NhiemVu.TrangThai.DA_XONG:
                du_lieu['thoi_diem_hoan_thanh'] = timezone.now()
        else:
            du_lieu['thoi_diem_hoan_thanh'] = None

    def create(self, validated_data):
        self._gan_thoi_diem_hoan_thanh(validated_data)
        return super().create(validated_data)

    def update(self, instance, validated_data):
        self._gan_thoi_diem_hoan_thanh(validated_data, instance.trang_thai)
        return super().update(instance, validated_data)


class KhungGioRanhSerializer(serializers.ModelSerializer):
    class Meta:
        model = KhungGioRanh
        fields = ['id', 'thu_trong_tuan', 'gio_bat_dau', 'gio_ket_thuc', 'ngay_tao', 'ngay_cap_nhat']
        read_only_fields = ['ngay_tao', 'ngay_cap_nhat']

    def validate(self, attrs):
        thu = attrs.get('thu_trong_tuan', getattr(self.instance, 'thu_trong_tuan', None))
        bat_dau = attrs.get('gio_bat_dau', getattr(self.instance, 'gio_bat_dau', None))
        ket_thuc = attrs.get('gio_ket_thuc', getattr(self.instance, 'gio_ket_thuc', None))

        if ket_thuc <= bat_dau:
            raise serializers.ValidationError('Giờ kết thúc phải sau giờ bắt đầu.')

        # Không cho 2 khung giờ rảnh chồng lên nhau trong cùng một thứ
        trung = KhungGioRanh.objects.filter(
            nguoi_dung=self.context['request'].user,
            thu_trong_tuan=thu,
            gio_bat_dau__lt=ket_thuc,
            gio_ket_thuc__gt=bat_dau,
        )
        if self.instance:
            trung = trung.exclude(pk=self.instance.pk)
        if trung.exists():
            raise serializers.ValidationError('Khung giờ này bị trùng với khung giờ rảnh đã có.')
        return attrs