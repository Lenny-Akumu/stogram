# TDLib

Клієнт вантажить `td_json_client` через FFI (`lib/core/tdlib/`). Бінарник у репо не кладемо.

- **Linux (Arch):** `yay -S libtdjson` або зібрати з https://github.com/tdlib/td. Шукається спершу в `lib/` поруч з виконуваним файлом, далі системні шляхи; можна вказати `TDJSON_PATH`.
- **Windows:** `tdjson.dll` поруч з `.exe` або шлях у `TDJSON_PATH`.
- **Android:** `libtdjson.so` під кожну ABI в `android/app/src/main/jniLibs/<abi>/`.

Версія TDLib — 1.8.x (пласкі `setTdlibParameters`).
