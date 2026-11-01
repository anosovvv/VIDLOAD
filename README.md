# VIDLOAD

## English

VIDLOAD is a compact macOS app for saving permitted public YouTube and
Instagram videos to your Mac. It can save video as a QuickTime-compatible MP4
or extract audio as MP3. yt-dlp, FFmpeg, and Deno are included inside the
application. Homebrew and Terminal setup are not required.

### Install or update

1. Download `VIDLOAD-1.1.1-macOS.zip` from [Releases](../../releases/latest).
2. Quit VIDLOAD, unzip the download, and move `VIDLOAD.app` to Applications,
   replacing the previous version if installed.
3. Open VIDLOAD from Finder or Spotlight. Requires macOS 14 or later, Intel or Apple Silicon.

Version 1.1.1 fixes YouTube JavaScript challenge failures, updates yt-dlp to
2026.10.26, and bundles Deno 2.9.8 for both Mac architectures.
The app has no Developer ID signature and is not notarized, so macOS may
ask you to approve it in System Settings → Privacy & Security.

The Russian installation guide and privacy notes follow below.

## Русский

Небольшое приложение для macOS, которое сохраняет **разрешённые публичные** видео с YouTube и Instagram в папку на Mac.

VIDLOAD не поддерживает приватные материалы, DRM и обход ограничений сервисов. 

## Установка

1. Откройте страницу [Releases](../../releases) и скачайте архив из последнего релиза.
2. Распакуйте архив и перенесите `VIDLOAD.app` в папку «Программы».
3. Запустите приложение через Finder или Spotlight.

Homebrew, `yt-dlp` и FFmpeg устанавливать отдельно **не нужно**: нужные версии уже находятся внутри `VIDLOAD.app`.

## Что нового в 1.1.1

- исправлена загрузка YouTube при ошибках обработки JavaScript;
- встроенный yt-dlp обновлён до 2026.10.26;
- добавлен Deno 2.9.8 для Apple Silicon и Intel — отдельно устанавливать его не нужно.

Для обновления закройте VIDLOAD, распакуйте новый архив и замените приложение в папке «Программы».

## Что нового в 1.1.0

- убрана лишняя галочка-подтверждение;
- окно о прозрачности и разрешениях теперь показывается только при первом запуске;
- ссылка, выбор формата и кнопка «Скачать» объединены в один быстрый блок.
- добавлен переключатель русского и английского языков прямо в окне приложения.

### Предупреждение macOS

Приложение распространяется без Apple Developer ID и нотариального заверения. Поэтому macOS может показать стандартное предупреждение о неизвестном разработчике. Это ожидаемо. Если вы доверяете скачанному релизу, откройте приложение через Finder: удерживая Control, нажмите на `VIDLOAD.app` и выберите «Открыть», затем подтвердите запуск.

## Safari и разрешение к диску

Опция «Использовать текущую сессию Safari» нужна только когда YouTube или Instagram просят войти в аккаунт. Она передаёт текущие cookie Safari только выбранному сервису и только на время одной загрузки; VIDLOAD их не сохраняет.

macOS защищает cookie Safari, поэтому при использовании этой опции может потребоваться «Полный доступ к диску» для VIDLOAD. Это широкое системное разрешение — включайте его только для версии приложения, которой доверяете. Для обычных публичных ссылок без сессии Safari оно не нужно.

## Системные требования

- macOS 14 или новее;
- Mac с Apple Silicon или Intel.

MP4-файлы после скачивания дополнительно подготавливаются для QuickTime: H.264-видео и AAC-аудио.

## Сборка из исходников

Обычным пользователям исходники не нужны: берите готовый архив из Releases. Для сборки проекта в Xcode сначала выполните `Scripts/fetch-bundled-tools.sh`; скрипт загрузит такие же встроенные инструменты в локальную папку проекта. Homebrew не нужен.

## Компоненты с открытым исходным кодом

Релиз включает `yt-dlp`, FFmpeg и Deno как отдельные исполняемые процессы. Сведения о версиях, лицензиях и исходниках — в [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Их копии также помещены внутрь релизного приложения.
