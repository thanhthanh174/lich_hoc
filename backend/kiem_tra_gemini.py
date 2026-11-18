import os
import time
import requests

khoa = os.environ.get("GEMINI_API_KEY")
chinh = os.environ.get("GEMINI_MODEL")
du_phong = os.environ.get("GEMINI_MODEL_DU_PHONG")
if not khoa or not chinh:
    raise SystemExit("Thiếu biến môi trường GEMINI_API_KEY hoặc GEMINI_MODEL")

cac_mo_hinh = [chinh] + ([du_phong] if du_phong else [])
du_lieu = {
    "contents": [
        {"parts": [{"text": "Trả lời bằng tiếng Việt, đúng 1 câu: chúc bạn học tốt."}]}
    ]
}

for mo_hinh in cac_mo_hinh:
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{mo_hinh}:generateContent"
    for lan in range(1, 4):
        bat_dau = time.time()
        try:
            res = requests.post(
                url,
                headers={"x-goog-api-key": khoa, "Content-Type": "application/json"},
                json=du_lieu,
                timeout=40,
            )
            giay = round(time.time() - bat_dau, 1)
            print(f"[{mo_hinh}] lần {lan}: mã {res.status_code} ({giay}s)")
            if res.status_code == 200:
                print(res.text[:600])
                raise SystemExit(0)
            print(res.text[:200])
        except requests.exceptions.RequestException as loi:
            print(f"[{mo_hinh}] lần {lan}: lỗi mạng ({type(loi).__name__})")
        time.sleep(3)

print("Cả hai model đều thất bại.")