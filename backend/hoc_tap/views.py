from django.utils import timezone
from django.utils.dateparse import parse_date
from rest_framework import generics, mixins, permissions, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from .ai import tao_giai_thich

from .models import BuoiHoc, HoSo, KeHoachHocTap, KhungGioRanh, MonHoc, NhiemVu
from .serializers import (
    BuoiHocSerializer, DangKySerializer, HoSoSerializer, KeHoachSerializer,
    KhungGioRanhSerializer, MonHocSerializer, NhiemVuSerializer, TaoKeHoachSerializer,
)
from .xep_lich import cap_nhat_trang_thai_nhiem_vu, tao_ke_hoach, xep_lai_ke_hoach


class DangKyView(generics.CreateAPIView):
    serializer_class = DangKySerializer
    permission_classes = [permissions.AllowAny]


class ThongTinCaNhanView(APIView):
    """GET: xem thông tin tài khoản. PATCH: sửa số giờ học tối đa mỗi ngày."""

    def _phan_hoi(self, request):
        ho_so, _ = HoSo.objects.get_or_create(nguoi_dung=request.user)
        return Response({
            'id': request.user.id,
            'username': request.user.username,
            'email': request.user.email,
            'so_gio_hoc_toi_da_moi_ngay': HoSoSerializer(ho_so).data['so_gio_hoc_toi_da_moi_ngay'],
        })

    def get(self, request):
        return self._phan_hoi(request)

    def patch(self, request):
        ho_so, _ = HoSo.objects.get_or_create(nguoi_dung=request.user)
        serializer = HoSoSerializer(ho_so, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return self._phan_hoi(request)


class ViewSetCuaToi(viewsets.ModelViewSet):
    """Lớp cha: chỉ trả dữ liệu của người đang đăng nhập, tạo mới thì tự gán chủ sở hữu."""

    def get_queryset(self):
        return super().get_queryset().filter(nguoi_dung=self.request.user)

    def perform_create(self, serializer):
        serializer.save(nguoi_dung=self.request.user)


class MonHocViewSet(ViewSetCuaToi):
    queryset = MonHoc.objects.all()
    serializer_class = MonHocSerializer


class NhiemVuViewSet(ViewSetCuaToi):
    queryset = NhiemVu.objects.select_related('mon_hoc')
    serializer_class = NhiemVuSerializer

    def get_queryset(self):
        ds = super().get_queryset()
        trang_thai = self.request.query_params.get('trang_thai')
        mon_hoc = self.request.query_params.get('mon_hoc')
        if trang_thai:
            ds = ds.filter(trang_thai=trang_thai)
        if mon_hoc:
            ds = ds.filter(mon_hoc_id=mon_hoc)
        return ds


class KhungGioRanhViewSet(ViewSetCuaToi):
    queryset = KhungGioRanh.objects.all()
    serializer_class = KhungGioRanhSerializer


class KeHoachViewSet(viewsets.ReadOnlyModelViewSet):
    """Xem kế hoạch; tạo kế hoạch bằng thuật toán; xếp lại lịch."""
    serializer_class = KeHoachSerializer

    def get_queryset(self):
        return KeHoachHocTap.objects.filter(nguoi_dung=self.request.user)

    @action(detail=False, methods=['post'], url_path='tao')
    def tao(self, request):
        dau_vao = TaoKeHoachSerializer(data=request.data)
        dau_vao.is_valid(raise_exception=True)
        ngay_bat_dau = dau_vao.validated_data.get('ngay_bat_dau') or timezone.localdate()
        ke_hoach, ket_qua = tao_ke_hoach(request.user, ngay_bat_dau, dau_vao.validated_data['so_ngay'])
        return Response({
            'ke_hoach': KeHoachSerializer(ke_hoach).data,
            'khong_xep_duoc': ket_qua['khong_xep_duoc'],
            'thu_tu_uu_tien': ket_qua['thu_tu_uu_tien'],
        }, status=201)

    @action(detail=True, methods=['post'], url_path='xep-lai')
    def xep_lai(self, request, pk=None):
        ke_hoach = self.get_object()
        try:
            ket_qua = xep_lai_ke_hoach(ke_hoach)
        except ValueError as loi:
            return Response({'chi_tiet': str(loi)}, status=400)
        ke_hoach.refresh_from_db()
        return Response({
            'ke_hoach': KeHoachSerializer(ke_hoach).data,
            'khong_xep_duoc': ket_qua['khong_xep_duoc'],
            'thu_tu_uu_tien': ket_qua['thu_tu_uu_tien'],
        })

    @action(detail=True, methods=['post'], url_path='giai-thich')
    def giai_thich(self, request, pk=None):
        """Nhờ AI giải thích/gợi ý kế hoạch; AI lỗi thì dùng phương án dự phòng."""
        ke_hoach = self.get_object()
        return Response(tao_giai_thich(ke_hoach))


class BuoiHocViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin,
                     mixins.UpdateModelMixin, viewsets.GenericViewSet):
    """Xem buổi học (lọc theo ngày/kế hoạch) và đánh dấu hoàn thành/bỏ lỡ bằng PATCH."""
    serializer_class = BuoiHocSerializer
    http_method_names = ['get', 'patch', 'head', 'options']

    def get_queryset(self):
        ds = BuoiHoc.objects.filter(
            ke_hoach__nguoi_dung=self.request.user
        ).select_related('nhiem_vu__mon_hoc')
        ke_hoach = self.request.query_params.get('ke_hoach')
        ngay = parse_date(self.request.query_params.get('ngay', ''))
        if ke_hoach:
            ds = ds.filter(ke_hoach_id=ke_hoach)
        if ngay:
            ds = ds.filter(thoi_gian_bat_dau__date=ngay)
        return ds

    def perform_update(self, serializer):
        buoi = serializer.save()
        cap_nhat_trang_thai_nhiem_vu(buoi.nhiem_vu)