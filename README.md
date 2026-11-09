# stogram

Власний клієнт на Flutter + TDLib. Деталі — `CLAUDE.md`, дизайни — `docs/`.

## Перший запуск

```bash
cp env.example.json env.json
```

Заповни `api_id` / `api_hash` з my.telegram.org і постав TDLib (`docs/TDLIB.md`).

```bash
flutter run -d linux --dart-define-from-file=env.json
```

## APK

Збирається в GitHub Actions (`Android APK`): TDLib під arm64-v8a і armeabi-v7a збирається з сирців і кешується, тож довго лише перший раз.
Потрібні секрети репо `TG_API_ID` і `TG_API_HASH` (Settings → Secrets and variables → Actions).
APK — в артефакті `stogram-apk` на сторінці запуску.

## Linux і Windows

На Linux для голосових і відео потрібен системний libmpv: на Arch `sudo pacman -S mpv`, на Ubuntu/Debian `sudo apt install libmpv2`.

Воркфлоу `Desktop builds` збирає TDLib під кожну платформу (теж з кешем) і кладе його в бандл: `stogram-linux-x64.tar.gz` (розпакуй і запусти `app`) та `stogram-windows-x64.zip` (`app.exe`, поруч `tdjson.dll` з залежностями).

Кожен мерж у `main` публікує реліз `dev-<коміт>` (prerelease) з APK, Linux і Windows збірками.

## Оновлення в застосунку

Збірки з `main` знають свій тег (`BUILD_TAG`). На старті й кожні 6 годин застосунок дивиться найсвіжіший реліз цього репо, і якщо там новіший файл під його платформу — показує плашку «Оновити»: Android відкриває системний інсталятор, Linux розпаковує архів поверх себе й перезапускається, Windows підміняє файли скриптом після виходу.

Підпис APK — постійний ключ із секретів `ANDROID_KEYSTORE_BASE64` і `ANDROID_KEYSTORE_PASSWORD` (alias `stogram`). Згенерувати:

```bash
keytool -genkeypair -keystore stogram.jks -storetype PKCS12 -alias stogram -keyalg RSA -keysize 4096 -validity 10000 -dname "CN=stogram"
base64 -w0 stogram.jks
```

Сам `.jks` не губи і в репо не клади: без нього нові APK не стануть поверх старих.
