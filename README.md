# stogram

Власний клієнт на Flutter + TDLib. Деталі — `CLAUDE.md`, дизайни — `docs/`.

## Перший запуск

Платформні папки не в репо, згенеруй їх один раз:

```bash
flutter create --platforms=linux,windows,android --org dev.lenny --project-name app .
```

Видали згенерований `test/widget_test.dart`. Далі:

```bash
cp env.example.json env.json
```

Заповни `api_id` / `api_hash` з my.telegram.org і постав TDLib (`docs/TDLIB.md`).

```bash
flutter run -d linux --dart-define-from-file=env.json
```
