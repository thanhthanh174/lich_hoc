import os
import requests

khoa = os.environ.get("GEMINI_API_KEY")
if not khoa:
    raise SystemExit("Thiếu biến môi trường GEMINI_API_KEY")

res = requests.get(
    "https://generativelanguage.googleapis.com/v1beta/models",
    headers={"x-goog-api-key": khoa},
    params={"pageSize": 100},
    timeout=60,
)
print(res.status_code)
if res.status_code == 200:
    for m in res.json().get("models", []):
        if "generateContent" in m.get("supportedGenerationMethods", []):
            print(m["name"].replace("models/", ""))
else:
    print(res.text[:500])