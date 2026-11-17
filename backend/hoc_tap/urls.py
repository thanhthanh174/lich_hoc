from django.urls import include, path
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

from .views import (
    DangKyView, KhungGioRanhViewSet, MonHocViewSet,
    NhiemVuViewSet, ThongTinCaNhanView,
)

router = DefaultRouter()
router.register('mon-hoc', MonHocViewSet, basename='mon-hoc')
router.register('nhiem-vu', NhiemVuViewSet, basename='nhiem-vu')
router.register('khung-gio-ranh', KhungGioRanhViewSet, basename='khung-gio-ranh')

urlpatterns = [
    path('dang-ky/', DangKyView.as_view()),
    path('dang-nhap/', TokenObtainPairView.as_view()),
    path('lam-moi-token/', TokenRefreshView.as_view()),
    path('toi/', ThongTinCaNhanView.as_view()),
    path('', include(router.urls)),
]