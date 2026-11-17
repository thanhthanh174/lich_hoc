from rest_framework import generics, permissions, viewsets
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import HoSo, KhungGioRanh, MonHoc, NhiemVu
from .serializers import (
    DangKySerializer, HoSoSerializer, KhungGioRanhSerializer,
    MonHocSerializer, NhiemVuSerializer,
)


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
        # Lọc tùy chọn: /api/nhiem-vu/?trang_thai=chua_lam&mon_hoc=1
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