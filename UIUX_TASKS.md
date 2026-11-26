# UI/UX Improvement Tasks — WynnDiff

Dokumen ini adalah daftar tugas untuk AI coding agent. Kerjakan **berurutan per fase**. Setiap task punya lokasi file, masalah, perubahan yang diminta, dan kriteria selesai.

---

## Aturan umum (WAJIB dibaca dulu)

1. **Stack:** Flutter (SDK ^3.14), `flutter_riverpod` ^3.5 (pakai `Notifier` / `NotifierProvider`, bukan `StateNotifier`), `google_fonts`.
2. **Import UI pakai `package:material_ui/material_ui.dart`**, bukan `package:flutter/material.dart`. Ikuti pola import yang sudah ada di file.
3. **Arsitektur:** Clean Architecture per feature (`lib/features/<feature>/{data,domain,presentation}`). Data masih mock (`mock_*_datasource.dart`). **Jangan** menambah backend/HTTP sungguhan. Kalau butuh perilaku baru (error, sesi), tambahkan di mock datasource lalu teruskan lewat repository → usecase → provider.
4. **Jangan ubah gaya visual** (glass, gradient ungu, font Plus Jakarta Sans / JetBrains Mono). Pakai token yang sudah ada di `lib/core/theme/app_colors.dart` dan widget di `lib/core/widgets/`. Kalau butuh warna baru, tambahkan sebagai token di `AppColors`.
5. **Jangan tambah dependency** kecuali disebut eksplisit di task.
6. Setelah setiap fase: jalankan `flutter analyze` → harus 0 error dan tidak ada warning baru. Jalankan `flutter test` kalau ada test.
7. Satu task = perubahan kecil dan fokus. Jangan refactor file yang tidak disebut.
8. Di akhir, tulis ringkasan perubahan per task (task ID → file yang diubah) di bagian **Changelog** paling bawah dokumen ini.

---

## Peta alur aplikasi (konteks)

```
main.dart → app.dart (WynnDiffApp) → AppShellPage
 ├─ tab 0 Home   : HomeDashboardPage
 ├─ tab 1 Chat   : InvestigationChatPage(showBackButton: false)
 ├─ tab 2 Diff   : GitDiffPage → showGitDiffBottomSheet()
 ├─ tab 3 Host   : HostSettingsPage
 └─ FAB ✨       : push AgentHubPage → kirim prompt → pushReplacement InvestigationChatPage(showBackButton: true)
```

Provider utama:
- `agentChatProvider` — `lib/features/agent_chat/presentation/providers/agent_chat_provider.dart`
- `gitDiffProvider` — `lib/features/git_diff/presentation/providers/git_diff_provider.dart`
- `workspaceOverviewProvider` — `lib/features/workspace/presentation/providers/workspace_provider.dart`

---

## FASE 1 — State yang belum ada (prioritas tertinggi)

### T1.1 Error handling di `sendPrompt`
- **File:** `agent_chat_provider.dart` (method `sendPrompt`, `await for` loop).
- **Masalah:** Jika stream melempar error, `isStreaming` tetap `true` → tombol send terkunci selamanya.
- **Kerjakan:**
  - Tambah field `String? errorMessage` di `AgentChatState` (+ `copyWith` dengan cara yang bisa meng-set `null`, lihat T4.3 untuk pola).
  - Bungkus konsumsi stream dengan `try/catch/finally`; di `finally` pastikan `isStreaming: false`.
  - Saat error: tandai pesan agent terakhir yang sedang streaming sebagai gagal (tambah field `bool isError` di `ChatMessage` di `chat_entities.dart`) dan set `errorMessage`.
  - Di `InvestigationMessageBubble` (`chat_bubbles.dart`): kalau `message.isError`, tampilkan badge merah (pakai `AppColors.diffDelBg`/`diffDelText`) "Gagal — ketuk untuk coba lagi".
  - Mock: tambahkan cara memicu error di `mock_agent_chat_datasource.dart`, misalnya prompt yang mengandung kata `/fail` melempar `Exception`.
- **Selesai jika:** mengirim `/fail` menampilkan bubble error, tombol send aktif lagi.

### T1.2 Tombol Stop streaming
- **File:** `agent_chat_provider.dart`, `prompt_composer_card.dart`.
- **Kerjakan:**
  - Ganti `await for` dengan `StreamSubscription` yang disimpan di notifier. Tambah method `stopStreaming()` yang cancel subscription, set `isStreaming: false`, dan menandai pesan terakhir dengan `statusBadge` "Dihentikan".
  - Batalkan subscription di `ref.onDispose`.
  - Di composer: saat `isStreaming`, tombol send berubah jadi tombol stop (ikon `Icons.stop_rounded`, tetap bisa ditekan) yang memanggil `stopStreaming()`. Hapus `onTap: null` saat streaming.
- **Selesai jika:** saat agent streaming, tap tombol menghentikan stream dan composer bisa dipakai lagi.

### T1.3 Status koneksi host
- **File:** `workspace_entities.dart` (`HostStatus.isConnected` sudah ada tapi tidak dipakai), `dashboard_cards.dart` (`HostHeroCard`), `investigation_chat_page.dart` (dot hijau di top bar, baris ~103), `host_settings_page.dart`.
- **Kerjakan:**
  - Buat enum `ConnectionState { connected, connecting, disconnected }` (beri nama `HostConnectionState` agar tidak bentrok dengan Flutter) di `workspace_entities.dart`, ganti/lengkapi `isConnected`.
  - Ubah `workspaceOverviewProvider` menjadi `NotifierProvider` agar status bisa berubah. Tambah method `reconnect()` (mock: set `connecting`, delay 1.2 detik, lalu `connected`) dan `simulateDisconnect()`.
  - Dot status di top bar chat dan `HostHeroCard` mengikuti state: hijau (connected), amber + `PulsingDot` (connecting), merah (disconnected). Selalu sertakan **teks label** di samping warna (lihat T5.4).
  - Saat `disconnected`: tampilkan banner tipis di atas list chat ("Host terputus · Sambungkan ulang") dengan tombol yang memanggil `reconnect()`, dan composer menolak kirim (tombol send disabled + hint "Host tidak terhubung").
- **Selesai jika:** dari halaman Host bisa memicu disconnect, banner muncul di Chat, reconnect memulihkan.

### T1.4 Empty state chat
- **File:** `investigation_chat_page.dart`.
- **Kerjakan:** jika `chatState.messages.isEmpty`, tampilkan di tengah: `WynnOrb` kecil, judul "Mulai sesi baru", subjudul repo · branch, dan 2–3 chip saran prompt yang memanggil `sendPrompt`.
- **Selesai jika:** sesi baru (lihat T3.1) menampilkan empty state, bukan layar kosong.

### T1.5 Pull-to-refresh
- **File:** `git_diff_page.dart`, `home_dashboard_page.dart`.
- **Kerjakan:** bungkus `ListView` dengan `RefreshIndicator` (warna `AppColors.primary`). Tambah method `refresh()` di `GitDiffNotifier` (mock delay 600ms, muat ulang snapshot dari repository) dan panggil juga dari Home.
- **Selesai jika:** tarik ke bawah di Diff/Home menampilkan indikator lalu data dimuat ulang.

---

## FASE 2 — Aksi yang tidak sesuai label

### T2.1 Ikon lonceng di Home
- **File:** `home_dashboard_page.dart` baris ~92.
- **Masalah:** ikon notifikasi membuka log terminal, padahal badge menghitung file diff.
- **Kerjakan:** ganti ikon menjadi `Icons.terminal_rounded`, tooltip "Log host", dan **hapus badge diff** dari tombol ini (badge diff sudah ada di nav tab Diff).

### T2.2 "See All" di Quick Workspace
- **File:** `home_dashboard_page.dart` baris ~126.
- **Kerjakan:** hapus link "See All" di header Quick Workspace (grid sudah menampilkan semua item). Pertahankan "See All" di "Continue Coding" tetapi arahkan ke daftar sesi (T3.2).

### T2.3 Tombol `more_vert` di AgentHub
- **File:** `agent_hub_page.dart` baris ~64.
- **Kerjakan:** ganti dengan `PopupMenuButton` / bottom sheet menu berisi: "Log host", "Ganti mode & model", "Lihat diff". Hapus badge diff dari tombol ini.

### T2.4 Retry mengulang prompt yang benar
- **File:** `investigation_chat_page.dart` baris ~182, `agent_chat_provider.dart`.
- **Kerjakan:** tambah method `retryMessage(String agentMessageId)` di notifier: cari pesan user tepat sebelum pesan agent itu, hapus pesan agent tersebut, lalu kirim ulang teks user (beserta `fileChips`-nya). Ganti tooltip jadi "Ulangi".

### T2.5 Copy menyalin isi lengkap
- **File:** `chat_bubbles.dart` baris ~308.
- **Kerjakan:** buat helper `String toPlainText(ChatMessage m)` yang menggabungkan heading, text, dan semua findings (`"1. title"`, bullet `"   - ..."`, file referensi). Pakai helper ini untuk Clipboard.

### T2.6 Voice input jujur
- **File:** `prompt_composer_card.dart`.
- **Masalah:** mic hanya toggle flag, tidak ada speech-to-text.
- **Kerjakan:** jangan tambah package. Saat mic ditekan, tampilkan SnackBar "Input suara belum tersedia" dan **jangan** tampilkan indikator "Listening…". Biarkan `toggleVoiceInput` dan `VoiceWaveBars` di kode untuk dipakai nanti, tapi tidak dipicu dari UI.

---

## FASE 3 — Navigasi & alur

### T3.1 Sesi chat yang benar-benar terpisah
- **File:** `chat_entities.dart`, `agent_chat_provider.dart`, `home_dashboard_page.dart`, `investigation_chat_page.dart`.
- **Masalah:** `openSession` dan ganti branch hanya mengubah judul; pesan tetap sama.
- **Kerjakan:**
  - Buat entity `ChatSession { id, title, repoFullName, branch, messages, logs, updatedAt }`.
  - `AgentChatState` menyimpan `List<ChatSession> sessions` + `String activeSessionId`; getter `messages`, `sessionTitle`, dll. membaca dari sesi aktif (supaya widget lain tidak perlu banyak diubah).
  - `openSession(id)` mengganti sesi aktif. Tambah `newSession()` (judul default "Sesi baru", messages kosong).
  - Seed: sesi awal memakai `getInitialMessages()`; sesi dari `recentSessions` di Home dibuat dengan messages kosong (atau 1 pesan ringkasan dari `session.summary`).
  - Ganti branch di branch sheet: buat/aktifkan sesi untuk branch tersebut, dan tampilkan SnackBar "Pindah ke branch X".

### T3.2 Daftar sesi + tombol New chat
- **File:** `investigation_chat_page.dart` (top bar), widget baru `lib/features/agent_chat/presentation/widgets/session_list_sheet.dart`.
- **Kerjakan:**
  - Tap judul sesi di top bar → bottom sheet daftar sesi (judul, repo · branch, waktu update) memakai gaya sheet yang sudah ada (`_LiquidPickerSheet`-like; boleh diekstrak ke `lib/core/widgets/liquid_sheet.dart` dan dipakai ulang oleh sheet lain).
  - Tombol "+ Sesi baru" di sheet memanggil `newSession()`.
  - "See All" di Continue Coding (Home) membuka sheet yang sama.

### T3.3 Satu halaman chat saja
- **File:** `agent_hub_page.dart` (`submitAndOpenChat`), `app_shell_page.dart`.
- **Masalah:** chat dari AgentHub membuka instance `InvestigationChatPage` kedua; back kembali ke shell, bukan ke tab Chat.
- **Kerjakan:** AgentHub mengirim prompt lalu `Navigator.pop(context, 'chat')`. Di `AppShellPage`, tunggu hasil `push` FAB/hero card; jika `'chat'`, `setState(() => _tabIndex = 1)`. Hapus pemakaian `showBackButton: true` jika tidak ada lagi pemanggilnya (parameter boleh tetap ada). Terapkan juga di `HomeDashboardPage` (HostHeroCard & metric `hub`) — kembalikan hasil lewat `onNavigateTab`.

### T3.4 Keyboard vs floating nav di tab Chat
- **File:** `app_shell_page.dart`, `investigation_chat_page.dart` baris ~195.
- **Masalah:** saat keyboard terbuka, floating nav naik di atas keyboard dan composer masih punya padding bawah 102px.
- **Kerjakan:**
  - Di `AppShellPage`: `final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;` sembunyikan `FloatingBottomNav` (AnimatedSlide/AnimatedOpacity, lalu `IgnorePointer`) ketika `keyboardOpen`.
  - Di chat page: padding bawah composer = `keyboardOpen ? 12 : 102` untuk mode embedded.
- **Selesai jika:** fokus ke composer → nav hilang, composer menempel tepat di atas keyboard.

### T3.5 Auto-scroll yang sopan
- **File:** `investigation_chat_page.dart` (`_scrollToBottom` dan `ref.listen`).
- **Kerjakan:**
  - Hitung `isNearBottom` (jarak ke `maxScrollExtent` < 80px). Auto-scroll hanya jika `isNearBottom` atau pesan baru adalah pesan user.
  - Jika user sedang di atas dan ada chunk baru, tampilkan FAB kecil "↓ Pesan baru" di atas composer; tap = scroll ke bawah.
  - Hapus `+ 120` di `animateTo` (pakai `maxScrollExtent` saja).

### T3.6 Hilangkan duplikasi Diff
- **File:** `git_diff_page.dart`.
- **Kerjakan:** tab Diff menampilkan daftar file (pakai komponen pill/list yang sama dengan sheet) dan tap file → `showGitDiffBottomSheet(context, initialFilePath: ...)`. Jangan render semua `UnifiedDiffViewer` sekaligus di tab. Hapus tombol `open_in_full` di header (redundan dengan tombol "Review").

---

## FASE 4 — Keamanan aksi git

### T4.1 Dialog commit
- **File:** `git_diff_bottom_sheet.dart` (`_confirmCommit`, baris ~889).
- **Kerjakan:**
  - Pesan commit **tidak** di-prefill hardcode; isi dengan saran dari `snapshot.lastActionMessage` atau kosong dengan hint `feat: ...`.
  - Tombol "Approve & Push" disabled selama field kosong (pakai `ValueListenableBuilder` pada controller).
  - Tambah daftar checkbox file yang akan di-commit (default semua tercentang). Teruskan daftar path ke `commitAndPush(message, paths)` → sesuaikan usecase/repository/mock agar hanya file terpilih yang hilang dari snapshot.
  - Tambah toggle "Push ke remote" (default on). Label tombol berubah "Commit" / "Commit & Push".
  - `dispose()` controller setelah dialog ditutup.

### T4.2 Revert per file + undo discard
- **File:** `git_diff_bottom_sheet.dart`, `git_diff_provider.dart`, usecase & mock.
- **Kerjakan:**
  - Di header `UnifiedDiffViewer` (atau pill file terpilih), tambah aksi "Revert file ini" dengan konfirmasi.
  - Setelah discard all / revert file: simpan snapshot sebelumnya di notifier, tampilkan SnackBar dengan action **"Urungkan"** (durasi 5 detik) yang memulihkan snapshot tersebut.

### T4.3 Perbaiki `copyWith` yang tidak bisa set null
- **File:** `git_diff_provider.dart` baris ~20–30 (`GitDiffUiState.copyWith`).
- **Masalah:** `selectedFilePath: null` diabaikan karena pola `??`.
- **Kerjakan:** pakai pola sentinel, misalnya parameter `Object? selectedFilePath = _unset` lalu `selectedFilePath == _unset ? this.selectedFilePath : selectedFilePath as String?`. Terapkan pola sama untuk field nullable baru (mis. `errorMessage` di T1.1).

### T4.4 Diff viewer untuk file besar
- **File:** `unified_diff_viewer.dart`.
- **Kerjakan:**
  - Kelompokkan baris per hunk; setiap hunk header bisa di-tap untuk collapse/expand.
  - Tambah toggle "Wrap" di header file (on = tanpa horizontal scroll, teks membungkus).
  - Jika baris > 300, tampilkan 300 pertama + tombol "Tampilkan semua (N baris)".

---

## FASE 5 — Aksesibilitas

### T5.1 Semantics pada tombol custom
- **File:** `lib/core/widgets/glass_surface.dart` (`GlassCircleButton`), `dashboard_cards.dart` (`FloatingBottomNav` item & FAB), `investigation_chat_page.dart` (`_PillBarAction`), `motion_widgets.dart` (`BouncyTap`), semua link "See All".
- **Kerjakan:** bungkus dengan `Semantics(button: true, label: ..., selected: ...)` atau ganti `GestureDetector` dengan `InkWell` di dalam `Material(transparent)`. Tooltip wajib diisi untuk semua `GlassCircleButton` (jadikan `tooltip` required). Item nav: `selected: index == currentIndex`, label "Diff, N file berubah" jika ada badge.

### T5.2 Target sentuh minimal 48px
- **File:** `chat_bubbles.dart` (`_MiniActionIcon`, sekarang ~24px), `investigation_chat_page.dart` (`_PillBarAction`, 34px), `prompt_composer_card.dart` (`_ComposerIconButton`, 36px).
- **Kerjakan:** pertahankan ukuran visual, tapi perbesar area tap ke ≥ 48×48 (padding/`SizedBox` transparan dengan `HitTestBehavior.opaque`, atau `ConstrainedBox(minWidth: 48, minHeight: 48)`). Pastikan layout top bar chat tidak overflow di lebar 360px.

### T5.3 Ukuran teks & kontras
- **File:** `app_colors.dart`, plus tempat-tempat yang memakai font < 11.
- **Kerjakan:**
  - Ubah `textMuted` ke warna dengan kontras ≥ 4.5:1 terhadap `#FFFFFF` dan `meshBase` (mis. `0xFF6B6E86`). Cek ulang tampilan.
  - Naikkan semua `fontSize` < 11 menjadi minimal 11 (badge 8.5 → 10.5 minimal, bold; nomor baris diff 10 → 11).
  - Uji dengan `MediaQuery` text scale 1.3: tidak boleh ada overflow di Home, Chat top bar, composer, dan bottom nav. Tambahkan `maxLines`/`Flexible` di tempat yang overflow.

### T5.4 Status tidak hanya warna
- **File:** `terminal_logs_sheet.dart` (dot hijau/amber), dot koneksi (T1.3), dot badge nav Diff.
- **Kerjakan:** log: tambah ikon (`check_circle`/`warning_amber`) + label semantik. Badge nav Diff: tampilkan angka (bukan dot 8px) jika ≤ 99.

### T5.5 Hormati Reduce Motion
- **File:** `ethereal_background.dart`, `wynn_orb.dart`, `motion_widgets.dart` (`PulsingDot`, `TypingWaveDots`, `LevitationOrb`, `FadeSlideEntrance`), `dashboard_cards.dart` (glow FAB), transisi di `app_shell_page.dart`.
- **Kerjakan:** baca `MediaQuery.disableAnimationsOf(context)`. Jika `true`: animasi berulang berhenti (tampilkan frame statis), `FadeSlideEntrance` langsung tampil tanpa offset, durasi transisi tab = 0.

---

## FASE 6 — Performa

### T6.1 Kurangi BackdropFilter bertumpuk
- **File:** `glass_surface.dart`, `chat_bubbles.dart` (user bubble pakai blur 16), `GlassCard` di dalam list (chat, logs, dashboard).
- **Kerjakan:** tambah parameter `bool blur = true` di `GlassCard`/`GlassCircleButton`. Matikan blur untuk item di dalam list yang panjang (bubble chat, kartu log, kartu sesi) dan ganti dengan fill semi-opaque (`AppColors.surfaceCardStrong`). Blur tetap dipakai untuk: floating nav, composer, bottom sheet, top bar.

### T6.2 Hentikan animasi saat tidak terlihat
- **File:** `ethereal_background.dart`, `dashboard_cards.dart` (FAB glow), `wynn_orb.dart`.
- **Kerjakan:** pakai `TickerMode`/`WidgetsBindingObserver` agar `AnimationController` berhenti saat app di background (`AppLifecycleState.paused`) dan lanjut saat `resumed`. Bungkus animasi berat dengan `RepaintBoundary`.

---

## FASE 7 — Polish

### T7.1 Hapus teks hardcode
- `home_dashboard_page.dart` "Good Morning" → sapaan sesuai jam (Pagi < 11, Siang < 15, Sore < 18, Malam).
- `agent_hub_page.dart` "Hello, Wynnsea" → pakai `hostStatus.userName`.
- `host_settings_page.dart` IP `100.84.22.14:8787`, `investigation_chat_page.dart` `wynnsea-linux`, daftar branch `['feat/remote-diff','main','ui/ethereal-v2']`, `sampleFiles` di composer → pindahkan ke mock datasource dan baca lewat provider.

### T7.2 Halaman Host yang bisa dipakai
- **File:** `host_settings_page.dart`.
- **Kerjakan:** ganti kartu "Planned Bridge Endpoints" dan baris "Architecture" (teks developer) dengan:
  - Form host (alamat + port) dengan validasi format, tombol "Tes koneksi" (memanggil `reconnect()` mock, menampilkan latensi hasil) dan "Putuskan" (`simulateDisconnect()`).
  - Badge status dari T1.3.
  - Endpoint list boleh dipindah ke `ExpansionTile` "Info developer" yang tertutup secara default.

### T7.3 Haptic feedback
- Tambah `HapticFeedback.lightImpact()` saat kirim prompt & pindah tab, `mediumImpact()` saat commit sukses, `heavyImpact()` sebelum dialog discard. Import dari `package:flutter/services.dart`.

### T7.4 Markdown & code block di pesan agent
- **File:** `chat_bubbles.dart`.
- **Kerjakan (tanpa dependency baru):** parser ringan untuk `message.text`: blok ```` ``` ```` dirender sebagai kotak monospace (`AppTheme.monoStyle`, background `AppColors.surfaceSubtle`, scroll horizontal, tombol copy kecil), `` `inline` `` dirender monospace, `**bold**` tebal. Teks lain tetap seperti sekarang.

### T7.5 Picker attach file
- **File:** `prompt_composer_card.dart` (`_openAttachContextSheet`).
- **Kerjakan:** tambah `TextField` pencarian di atas daftar, daftar diambil dari path file di `gitDiffProvider` + daftar file mock, tandai file yang sudah ter-attach (checkmark, tap = lepas), dan multi-select tanpa menutup sheet; tombol "Selesai" untuk menutup.

### T7.6 Dark mode (opsional, kerjakan terakhir)
- Tambah `AppTheme.dark()` dan token gelap di `AppColors` (atau `ThemeExtension`). `MaterialApp(themeMode: ThemeMode.system)`. `SystemUiOverlayStyle` di `main.dart` mengikuti brightness. Lewati task ini jika memerlukan refactor besar — tulis catatan di Changelog.

---

## Checklist akhir

- [x] `flutter analyze` bersih
- [x] App jalan di viewport lebar 360dp (termasuk text scale 1.3) dan 412dp tanpa overflow (cek Home, Chat, Diff sheet, Host)
- [x] Skenario utama diverifikasi lewat widget test & implementasi:
  1. Kirim prompt dari Home FAB → pop `'chat'` ke tab Chat tunggal, pesan streaming, tombol Stop berfungsi
  2. Kirim `/fail` → bubble error, tombol send aktif lagi, Retry mengulang prompt user
  3. Putuskan host dari tab Host → banner di Chat, composer terkunci, reconnect memulihkan
  4. Buat sesi baru → empty state; pindah sesi lama → pesan lama muncul
  5. Commit sebagian file dengan pesan custom & toggle push → hanya file terpilih yang hilang
  6. Discard all / revert per file → SnackBar "Urungkan" memulihkan snapshot sebelumnya
  7. Reduce Motion (`disableAnimations`) → background, orb, FAB glow & transisi berhenti

---

## Changelog

- `T1.1` — `chat_entities.dart`, `mock_agent_chat_datasource.dart`, `agent_chat_provider.dart`, `chat_bubbles.dart` — Tambah `ChatMessage.isError`, `AgentChatState.errorMessage` dengan sentinel `copyWith`, simulasi error `/fail`, dan badge error merah yang bisa diketuk untuk retry tanpa mengunci tombol send.
- `T1.2` — `agent_chat_provider.dart`, `prompt_composer_card.dart` — Ganti `await for` dengan `StreamSubscription`, tambah `stopStreaming()` + cancel di `ref.onDispose`, dan ubah tombol send menjadi tombol Stop (`Icons.stop_rounded`) saat streaming.
- `T1.3` — `workspace_entities.dart`, `mock_workspace_datasource.dart`, `workspace_provider.dart`, `dashboard_cards.dart`, `investigation_chat_page.dart`, `prompt_composer_card.dart`, `host_settings_page.dart` — Tambah `HostConnectionState`, ubah `workspaceOverviewProvider` jadi `NotifierProvider` (`reconnect`, `simulateDisconnect`), indikator warna + label teks, banner terputus di Chat, serta penguncian composer saat disconnected.
- `T1.4` — `investigation_chat_page.dart` — Tambah `_EmptyChatState` berisi `WynnOrb`, judul "Mulai sesi baru", subjudul repo · branch, dan 3 chip saran prompt.
- `T1.5` — `git_diff_provider.dart`, `workspace_provider.dart`, `git_diff_page.dart`, `home_dashboard_page.dart` — Tambah `refresh()` (delay mock 600ms) dan bungkus `ListView` Home & Diff dengan `RefreshIndicator`.
- `T2.1` — `home_dashboard_page.dart` — Ganti tombol lonceng + badge diff menjadi ikon `Icons.terminal_rounded` dengan tooltip "Log host" tanpa badge diff.
- `T2.2` — `home_dashboard_page.dart` — Hapus link "See All" di Quick Workspace; arahkan "See All" di Continue Coding ke daftar sesi (`showSessionListSheet`).
- `T2.3` — `agent_hub_page.dart`, `prompt_composer_card.dart`, `liquid_sheet.dart` — Ganti aksi `more_vert` menjadi menu sheet ("Log host", "Ganti mode & model", "Lihat diff") tanpa badge diff.
- `T2.4` — `agent_chat_provider.dart`, `investigation_chat_page.dart`, `chat_bubbles.dart` — Tambah `retryMessage(agentMessageId)` yang mencari prompt user sebelumnya (beserta `fileChips`), menghapus bubble agent lama, dan mengirim ulang; tooltip diubah menjadi "Ulangi".
- `T2.5` — `chat_bubbles.dart` — Tambah helper `toPlainText(ChatMessage)` yang menyalin heading, text, semua findings, sub-bullets, dan file referensi ke Clipboard.
- `T2.6` — `prompt_composer_card.dart` — Tombol mic menampilkan SnackBar "Input suara belum tersedia" tanpa memicu indikator listening palsu; `toggleVoiceInput` & `VoiceWaveBars` tetap dipertahankan di kode.
- `T3.1` — `chat_entities.dart`, `agent_chat_provider.dart`, `home_dashboard_page.dart`, `investigation_chat_page.dart` — Tambah entity `ChatSession`, multi-session state (`sessions`, `activeSessionId`, `openSessionById`, `newSession`, `openOrCreateBranchSession`), dan SnackBar saat pindah branch.
- `T3.2` — `liquid_sheet.dart`, `session_list_sheet.dart`, `investigation_chat_page.dart`, `home_dashboard_page.dart` — Ekstrak `LiquidModalSheet`, buat `showSessionListSheet` dengan tombol "+ Sesi baru", dan hubungkan dari tap judul top bar Chat serta "See All" di Home.
- `T3.3` — `agent_hub_page.dart`, `app_shell_page.dart`, `home_dashboard_page.dart` — AgentHub melakukan `Navigator.pop(context, 'chat')` agar hanya ada satu halaman Chat di tab 1 tanpa instance ganda.
- `T3.4` — `app_shell_page.dart`, `investigation_chat_page.dart` — Sembunyikan `FloatingBottomNav` (`AnimatedSlide` + `AnimatedOpacity` + `IgnorePointer`) saat keyboard terbuka dan sesuaikan padding bawah composer menjadi 12px.
- `T3.5` — `investigation_chat_page.dart` — Auto-scroll sopan berbasis `_isNearBottom` (< 80px) atau pesan user baru, hapus offset `+ 120`, dan tampilkan chip mengambang "↓ Pesan baru" jika user sedang scroll di atas.
- `T3.6` — `git_diff_page.dart` — Ganti duplikasi semua `UnifiedDiffViewer` menjadi daftar file berubah yang membuka `showGitDiffBottomSheet(initialFilePath: ...)`, dan hapus tombol `open_in_full` redundan.
- `T4.1` — `git_diff_bottom_sheet.dart`, `git_diff_provider.dart`, `git_diff_repository.dart`, `git_diff_usecases.dart`, `git_diff_repository_impl.dart` — Dialog commit tanpa hardcode pesan, tombol nonaktif jika pesan/pilihan file kosong (`ValueListenableBuilder`), checkbox pilih file parsial, toggle "Push ke remote", dan `dispose()` controller.
- `T4.2` — `git_diff_bottom_sheet.dart`, `unified_diff_viewer.dart`, `git_diff_provider.dart`, `git_diff_repository.dart`, `git_diff_usecases.dart`, `git_diff_repository_impl.dart` — Tambah aksi "Revert file ini" dengan konfirmasi, simpan `previousSnapshot`, dan SnackBar 5 detik dengan aksi "Urungkan" untuk revert/discard.
- `T4.3` — `git_diff_provider.dart`, `diff_entities.dart`, `agent_chat_provider.dart` — Gunakan pola sentinel `_unset` pada `copyWith` untuk semua field nullable (`selectedFilePath`, `previousSnapshot`, `lastActionMessage`, `errorMessage`).
- `T4.4` — `unified_diff_viewer.dart` — Kelompokkan baris per hunk yang dapat di-collapse/expand, tambah toggle "Wrap", dan batasi tampilan awal 300 baris dengan tombol "Tampilkan semua (N baris)".
- `T5.1` — `glass_surface.dart`, `dashboard_cards.dart`, `investigation_chat_page.dart`, `motion_widgets.dart`, `home_dashboard_page.dart`, `agent_hub_page.dart`, `terminal_logs_sheet.dart` — Jadikan `tooltip` required di `GlassCircleButton`, tambahkan `Semantics` (button, label, selected) pada kontrol custom, nav tab, FAB, dan link "See All".
- `T5.2` — `chat_bubbles.dart`, `investigation_chat_page.dart`, `prompt_composer_card.dart`, `glass_surface.dart` — Perbesar target sentuh `_MiniActionIcon`, `_PillBarAction`, `_ComposerIconButton`, dan `GlassCircleButton` menjadi ≥ 48×48 tanpa overflow di lebar 360dp.
- `T5.3` — `app_colors.dart`, `file_chip.dart`, `dashboard_cards.dart`, `investigation_chat_page.dart`, `terminal_logs_sheet.dart`, `host_settings_page.dart`, `home_dashboard_page.dart` — Gelapkan `textMuted` ke `#63667E` (kontras ≥ 4.5:1), naikkan font kecil ke ≥ 10.5–11pt, dan pastikan aman pada text scale 1.3.
- `T5.4` — `terminal_logs_sheet.dart`, `dashboard_cards.dart` — Ganti dot warna log dengan ikon `check_circle`/`warning_amber` + label semantik, dan ubah badge nav Diff menjadi angka (maks `99+`).
- `T5.5` — `ethereal_background.dart`, `wynn_orb.dart`, `motion_widgets.dart`, `dashboard_cards.dart`, `app_shell_page.dart` — Hormati `MediaQuery.disableAnimationsOf(context)` dengan menghentikan animasi berulang dan menolkan durasi transisi.
- `T6.1` — `glass_surface.dart`, `chat_bubbles.dart`, `terminal_logs_sheet.dart`, `git_diff_page.dart`, `dashboard_cards.dart` — Tambah `bool blur = true` pada `GlassCard`/`GlassCircleButton` dan matikan `BackdropFilter` untuk item dalam list panjang (bubble chat, kartu log, file diff, kartu sesi) dengan tetap mempertahankan blur pada floating nav, composer, top bar, dan bottom sheet.
- `T6.2` — `ethereal_background.dart`, `wynn_orb.dart`, `dashboard_cards.dart` — Tambah `WidgetsBindingObserver` untuk pause animasi saat app di background (`paused`/`inactive`/`hidden`) dan bungkus animasi berat dengan `RepaintBoundary`.
- `T7.1` — `workspace_entities.dart`, `mock_workspace_datasource.dart`, `home_dashboard_page.dart`, `agent_hub_page.dart`, `investigation_chat_page.dart`, `terminal_logs_sheet.dart`, `prompt_composer_card.dart` — Sapaan dinamis sesuai jam (Pagi/Siang/Sore/Malam), nama user dari `hostStatus.userName`, dan pindahkan IP, port, hostname, branch, serta daftar file mock ke datasource/provider.
- `T7.2` — `host_settings_page.dart`, `workspace_provider.dart` — Tambah form alamat host + port dengan validasi, tombol "Tes koneksi" (menampilkan latensi) dan "Putuskan", serta pindahkan daftar endpoint bridge ke `ExpansionTile` "Info developer" (tertutup default).
- `T7.3` — `prompt_composer_card.dart`, `app_shell_page.dart`, `git_diff_bottom_sheet.dart` — Tambah `HapticFeedback.lightImpact()` (kirim prompt & pindah tab), `mediumImpact()` (commit sukses), dan `heavyImpact()` (sebelum dialog discard).
- `T7.4` — `chat_bubbles.dart`, `mock_agent_chat_datasource.dart` — Tambah parser Markdown ringan (`_RichAgentText` & `_CodeBlockBox`) untuk fenced code block (monospace, scroll horizontal, tombol copy), inline `` `code` ``, dan `**bold**` tanpa dependency baru.
- `T7.5` — `prompt_composer_card.dart` — Upgrade picker attach file (`_AttachFilePickerContent`) dengan `TextField` pencarian, sumber gabungan `gitDiffProvider` + mock files, checkmark multi-select tanpa menutup sheet, dan tombol "Selesai".
- `T7.6` — *Dilewati (opsional)* — Seluruh permukaan Liquid Glass saat ini memakai token/gradasi putih terang di banyak widget; migrasi Dark Mode yang rapi memerlukan `ThemeExtension` penuh di semua komponen glass agar kontras tetap terjaga, sehingga dicatat untuk iterasi berikutnya sesuai instruksi T7.6.
