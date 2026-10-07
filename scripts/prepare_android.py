#!/usr/bin/env python3
"""Vá thư mục android do `flutter create` sinh ra để APK release chạy được.

Dùng: python3 scripts/prepare_android.py mobile_app

Việc làm (idempotent - chạy nhiều lần vẫn an toàn):
  1. Thêm quyền INTERNET vào AndroidManifest.xml chính. Template của Flutter chỉ
     bật INTERNET cho bản debug/profile, nên APK release không gọi được API.
  2. Cho phép http thường (usesCleartextTraffic) để test với backend chạy ở LAN.
  3. Đặt tên hiển thị của app là "WorkFlow".
  4. Nâng minSdk tối thiểu lên 23 (flutter_secure_storage yêu cầu).
"""
import pathlib
import re
import sys

APP_LABEL = "WorkFlow"
MIN_SDK = 23


def patch_manifest(root: pathlib.Path) -> None:
    path = root / "android/app/src/main/AndroidManifest.xml"
    text = path.read_text(encoding="utf-8")

    if "android.permission.INTERNET" not in text:
        text = re.sub(
            r"(<manifest[^>]*>)",
            r'\1\n    <uses-permission android:name="android.permission.INTERNET"/>',
            text,
            count=1,
        )

    if "usesCleartextTraffic" not in text:
        text = text.replace(
            "<application",
            '<application\n        android:usesCleartextTraffic="true"',
            1,
        )

    text = re.sub(r'android:label="[^"]*"', f'android:label="{APP_LABEL}"', text, count=1)
    path.write_text(text, encoding="utf-8")
    print(f"patched {path}")


def patch_gradle(root: pathlib.Path) -> None:
    app_dir = root / "android/app"
    kts = app_dir / "build.gradle.kts"
    groovy = app_dir / "build.gradle"

    if kts.exists():
        text = kts.read_text(encoding="utf-8")
        new = re.sub(
            r"minSdk\s*=\s*flutter\.minSdkVersion",
            f"minSdk = maxOf(flutter.minSdkVersion, {MIN_SDK})",
            text,
        )
        kts.write_text(new, encoding="utf-8")
        print(f"patched {kts}")
    elif groovy.exists():
        text = groovy.read_text(encoding="utf-8")
        new = re.sub(
            r"minSdkVersion\s+flutter\.minSdkVersion",
            f"minSdkVersion Math.max(flutter.minSdkVersion, {MIN_SDK})",
            text,
        )
        new = re.sub(
            r"minSdk\s*=\s*flutter\.minSdkVersion",
            f"minSdk = Math.max(flutter.minSdkVersion, {MIN_SDK})",
            new,
        )
        groovy.write_text(new, encoding="utf-8")
        print(f"patched {groovy}")
    else:
        sys.exit("Không tìm thấy android/app/build.gradle(.kts)")


def main() -> None:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "mobile_app")
    patch_manifest(root)
    patch_gradle(root)


if __name__ == "__main__":
    main()
