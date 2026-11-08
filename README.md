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

Воркфлоу `Desktop builds` збирає TDLib під кожну платформу (теж з кешем) і кладе його в бандл: `stogram-linux-x64.tar.gz` (розпакуй і запусти `app`) та `stogram-windows-x64.zip` (`app.exe`, поруч `tdjson.dll` з залежностями).
