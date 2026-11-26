# Interactive AI Avatar ("Wynn") — Task Spec

Dokumen ini adalah instruksi untuk AI coding agent (Gemini CLI). Tujuannya: menambahkan **karakter maskot AI yang interaktif dan ekspresif** ke aplikasi Flutter **WynnDiff**, menggantikan orb statis (`WynnOrb`) di titik-titik utama, supaya percakapan dan proses remote coding terasa hidup.

Kerjakan **berurutan per fase**. Setelah setiap fase jalankan `flutter analyze` dan `flutter test`, lalu isi **Changelog** di bawah.

---

## 0. Cara kerja agent

1. **Sebelum menulis kode**, tampilkan rencana struktur file (sesuai bagian 3) dan daftar file yang akan diubah. Lalu lanjutkan.
2. Tulis kode **lengkap dan bisa di-compile**: tanpa `TODO`, tanpa fungsi kosong, tanpa `throw UnimplementedError()` (kecuali di slot renderer opsional yang dijelaskan di Fase 6, dan itu pun harus jatuh ke fallback, bukan crash).
3. Ikuti aturan project:
   - Import UI pakai `package:material_ui/material_ui.dart` (bukan `package:flutter/material.dart`). `dart:ui`, `dart:math`, `package:flutter/services.dart`, `package:flutter/physics.dart`, `package:flutter/scheduler.dart` boleh.
   - State management: `flutter_riverpod` ^3.5 → `Notifier` / `NotifierProvider` / `Provider`. Jangan `StateNotifier`.
   - Warna dari `lib/core/theme/app_colors.dart`. Kalau butuh warna baru, tambahkan token di `AppColors` (bagian `// AI avatar`).
   - **Jangan tambah dependency** di fase 1–5. Avatar harus 100% procedural (CustomPainter) tanpa aset gambar.
   - Hormati `MediaQuery.disableAnimationsOf(context)` dan pause saat app background (contoh pola sudah ada di `lib/core/widgets/wynn_orb.dart` → `WidgetsBindingObserver`).
4. Jangan hapus `WynnOrb`/`LevitationOrb` — biarkan file-nya, hanya ganti pemakaiannya.

---

## 1. Desain karakter

> Referensi visual: gaya **3D clay / soft toy** — bentuk membulat, permukaan lembut matte, bayangan halus, warna pastel lavender, ekspresi wajah besar dan ramah, pose "mengintip dari balik kartu" dengan tangan bertumpu di tepi kartu.
> **Karakter harus original.** Jangan meniru karakter manusia di gambar referensi (rambut, wajah, pakaian). Ambil *gaya*-nya saja.

### 1.1 Konsep: "Wynn"
Maskot kecil berbentuk **mochi/kacang bulat** yang memakai **hoodie lavender**, dengan **antena kecil ber-manik cahaya** di atas kepala (manik ini adalah "inti AI" — penerus visual `WynnOrb`). Kepribadian: ceria, penasaran, sedikit kikuk, suka dipuji.

### 1.2 Anatomi (urutan layer gambar, belakang → depan)
Semua ukuran relatif terhadap `s = size` (sisi kotak avatar). Titik pusat badan di `(0.5s, 0.56s)`.

| # | Layer | Bentuk & warna | Catatan "clay" |
|---|---|---|---|
| 1 | **Contact shadow** | Elips `0.56s × 0.08s` di bawah badan, `Colors.black` alpha 0.10–0.18 | Mengecil & memudar saat avatar melayang naik |
| 2 | **Antena** | Batang lengkung tipis (stroke `0.025s`, warna `avatarHoodDark`) dari puncak kepala, ujungnya **manik** radius `0.055s` | Manik punya radial gradient + glow (`MaskFilter.blur`) dengan warna sesuai mood (lihat 1.4). Batang bergoyang mengikuti gerakan (pegas, lag 1 frame) |
| 3 | **Badan/hoodie** | Superellipse/rounded blob `0.78s × 0.74s`, gradient vertikal `avatarHoodLight #CDB9FF` → `avatarHood #9F7BFF` | Highlight specular oval kiri-atas (putih alpha 0.35, blur), shading bawah gelap (`avatarHoodDark #7A55E8` alpha 0.35). **Tanpa outline** |
| 4 | **Telinga hoodie** | Dua tonjolan membulat kecil di kiri-kanan atas | Bisa "naik" (perk) saat `listening` |
| 5 | **Wajah** | Oval `0.56s × 0.46s`, `avatarFace #FFF4EA`, sedikit lebih rendah dari pusat | Inner shadow tipis di tepi atas (bayangan tudung hoodie) |
| 6 | **Pipi** | Dua elips `avatarBlush #FFB4C8` alpha 0.0–0.7, blur | Intensitas dari parameter `blush` |
| 7 | **Mata** | Elips gelap `avatarInk #2B2340`, tinggi dipengaruhi `eyeOpen` (0 = garis, 1 = penuh). 2 highlight putih (besar kiri-atas, kecil kanan-bawah) | Pupil (seluruh mata) bergeser `pupilOffset` maks `0.035s`. Mode khusus: `^ ^` (happy), `> <` (squeeze), wink satu mata |
| 8 | **Alis** | Dua kapsul pendek `avatarInk` alpha 0.75 | Rotasi dari `browTilt` (−1 khawatir … +1 marah/fokus), naik turun dari `browRaise` |
| 9 | **Mulut** | Path kurva: `mouthCurve` (−1 cemberut … +1 senyum), `mouthOpen` (0 tertutup … 1 terbuka "o"), isi `avatarMouth #8C3B5A` + lidah kecil `#FF8FA8` saat terbuka | Mulut terbuka dipakai saat berbicara (streaming) dan kaget |
| 10 | **Tangan** | Dua bulatan "mitten" `0.16s`, warna hoodie | Pose dari `ArmPose`: `rest` (samping badan), `peek` (bertumpu di tepi bawah frame, seperti mengintip kartu), `chin` (satu tangan di dagu — thinking), `wave` (melambai), `cheer` (dua tangan ke atas), `type` (dua tangan bergantian naik-turun cepat — streaming) |
| 11 | **Efek** | Partikel kecil: sparkle ✦, hati ♥, tetes keringat, "zZ", titik "…" | Digambar di painter terpisah (lihat 3), maksimal 8 partikel aktif |

Tambahkan token ini ke `AppColors`:
```dart
// AI avatar
static const Color avatarHoodLight = Color(0xFFCDB9FF);
static const Color avatarHood = Color(0xFF9F7BFF);
static const Color avatarHoodDark = Color(0xFF7A55E8);
static const Color avatarFace = Color(0xFFFFF4EA);
static const Color avatarBlush = Color(0xFFFFB4C8);
static const Color avatarInk = Color(0xFF2B2340);
static const Color avatarMouth = Color(0xFF8C3B5A);
```

### 1.3 Parameter ekspresi
Semua ekspresi dinyatakan sebagai satu data class yang **bisa di-interpolasi** (`lerp`), supaya transisi antar mood selalu mulus (durasi default 280ms, `Curves.easeOutCubic`):

```dart
@immutable
class AvatarExpression {
  final double eyeOpen;        // 0..1
  final EyeShape eyeShape;     // normal, happy (^), squeeze (><), wide
  final double browTilt;       // -1..1
  final double browRaise;      // -1..1
  final double mouthCurve;     // -1..1
  final double mouthOpen;      // 0..1
  final double blush;          // 0..1
  final double earPerk;        // 0..1
  final ArmPose armPose;
  final Color antennaColor;
  final double antennaGlow;    // 0..1
  static AvatarExpression lerp(AvatarExpression a, AvatarExpression b, double t);
}
```
Field enum (`eyeShape`, `armPose`) berpindah di `t >= 0.5`. Posisi tangan di-lerp di painter berdasarkan offset pose, bukan enum.

### 1.4 Tabel mood

| Mood | Kapan | Mata | Alis | Mulut | Tangan | Gerak badan | Antena | Efek |
|---|---|---|---|---|---|---|---|---|
| `idle` | Default | normal 1.0, kedip acak | 0 | senyum kecil 0.35 | `rest` (atau `peek` jika `pose: peek`) | Napas: skala Y ±2% periode 3.2s, melayang ±3% s periode 4s | lavender `primaryLight`, glow 0.4 | — |
| `listening` | Composer fokus / ada teks / voice aktif | `wide` 1.0, pupil melihat ke bawah (ke input) | raise +0.5 | senyum 0.6, open 0.15 | `peek` / dua tangan sedikit naik | Condong ke depan (scale 1.04), napas lebih cepat | `tintBlueFg`, glow 0.6 | 1 sparkle kecil saat masuk mood |
| `thinking` | `isStreaming` dan pesan agent terakhir **belum punya teks**, atau `mode == investigate` saat streaming | 0.8, pupil ke kanan-atas, sesekali melirik kiri-kanan | tilt +0.4 (fokus) | datar 0, sedikit miring | `chin` | Kepala miring 6° bergantian lambat | `tintBlueFg` berdenyut 1.2s | Titik "…" mengambang bergantian di samping kepala |
| `streaming` | `isStreaming` dan teks pesan agent sedang bertambah | 0.9, pupil mengikuti "baca" kiri→kanan | 0.1 | **berbicara**: `mouthOpen` osilasi 0.1–0.6 dengan frekuensi ~7Hz, diberi "kick" setiap chunk masuk | `type` | Bob kecil setiap chunk | `primary`, glow berdenyut cepat | — |
| `success` *(transient 2.4s)* | Stream selesai dengan diff baru, commit/push sukses | `happy` (^ ^) | raise +0.6 | senyum 1.0, open 0.4 | `cheer` | Lompat kecil (squash → stretch → land, 2×) | `tintGreenFg`, glow 1.0 | 3–5 sparkle meledak keluar |
| `error` | `errorMessage != null` atau pesan terakhir `isError` | `wide`, pupil bergetar kecil | tilt −0.7 (khawatir) | cemberut −0.5, open 0.2 | dua tangan dekat wajah | Shake horizontal 300ms saat masuk mood, lalu diam tegang | `tintAmberFg` berkedip 2× | Tetes keringat di pelipis |
| `offline` | `HostConnectionState.disconnected` | 0.25 (ngantuk) | tilt −0.3 | datar −0.1 | `rest` | Napas lambat, sedikit turun (melayang lebih rendah) | abu-abu `textMuted`, glow 0 | "zZ" naik pelan |
| `connecting` | `HostConnectionState.connecting` | 0.9, melirik kiri-kanan cepat | raise +0.3 | "o" kecil (open 0.3) | `rest` | — | `tintAmberFg` berputar/berdenyut | — |
| `sleepy` | `idle` tanpa interaksi > 45 detik | turun pelan ke 0.2, sesekali "terbangun" | −0.2 | menguap sesekali (open 0.8 selama 900ms) | `rest` | Napas sangat lambat | redup | "zZ" |

Prioritas jika beberapa kondisi aktif bersamaan (paling atas menang):
`reaction (transient)` > `offline` > `connecting` > `error` > `success (transient)` > `streaming` > `thinking` > `listening` > `sleepy` > `idle`.

### 1.5 Mikro-perilaku (yang bikin "hidup")
Wajib ada, semuanya berbasis waktu acak (pakai `math.Random` dengan seed per-instance agar beberapa avatar tidak sinkron):
- **Kedip**: interval acak 2.5–6s, durasi 140ms; 20% kemungkinan kedip dua kali.
- **Lirikan**: tiap 4–9s di `idle`, pupil menoleh ke arah acak selama 600–1200ms lalu kembali.
- **Squash & stretch**: setiap perubahan mood memicu squash kecil (scaleY 0.94, scaleX 1.04, 120ms) lalu kembali dengan pegas.
- **Antena ber-lag**: ujung antena mengikuti gerakan badan dengan pegas (`SpringSimulation` atau damping manual), jadi bergoyang saat avatar bergerak/dimiringkan.
- **Menoleh ke konten**: di halaman chat, saat pesan baru user muncul avatar menoleh ke kanan (ke bubble user) 800ms; saat user mengetik, mata melihat ke bawah.
- **Variasi idle**: setiap 20–40s, mainkan satu "fidget" acak: lambai kecil, garuk pipi, antena berputar, atau menguap.

---

## 2. Interaksi sentuhan

| Gestur | Reaksi | Aksi tambahan (opsional, lewat callback) |
|---|---|---|
| **Tap** ("boop") | Squash cepat, mata `squeeze` (> <) 350ms, blush naik ke 0.8, 1 hati muncul. Tap ke-2 dalam 1.5s → wink. Tap ke-3 → giggle (badan bergetar halus + mulut terbuka) | `onTap` dipanggil setelah reaksi dimulai. Panggil `HapticFeedback.selectionClick()` |
| **Long press** | Avatar melambai (`wave`), tampilkan **speech bubble** berisi tips/status kontekstual (lihat 2.1) | `onLongPress` |
| **Drag / pan** | Avatar **memiringkan diri** ke arah jari: rotasi 3D (`Matrix4..setEntry(3, 2, 0.0015)..rotateX(..)..rotateY(..)`) maks ±0.35 rad, dan **mata mengikuti posisi jari** (pupilOffset). Saat dilepas, kembali ke netral dengan **spring** (`SpringDescription(mass: 1, stiffness: 180, damping: 14)`) — boleh sedikit overshoot | — |
| **Elus** (drag bolak-balik horizontal ≥ 3 kali dalam 1.2s) | Mata `happy`, blush 1.0, 2–3 hati, badan bergoyang senang 1.2s | `HapticFeedback.lightImpact()` |
| **Diam lama** | Masuk `sleepy`. Tap apa saja → kaget kecil (mata `wide` 300ms) lalu `idle` | — |

Aturan:
- Tilt dan pupil-follow disimpan di `ValueNotifier`/controller lokal widget, **bukan** di provider Riverpod (supaya drag tidak me-rebuild layar).
- Area tap = seluruh kotak avatar, minimum 48×48 (untuk ukuran `xs` perbesar hit area dengan padding transparan).
- Avatar yang `interactive: false` (contoh: di bubble chat lama) tidak memproses gestur sama sekali.

### 2.1 Speech bubble kontekstual
Widget `AvatarSpeechBubble` (gelembung glass kecil dengan ekor ke avatar, muncul dengan scale+fade, hilang otomatis 3.5s atau saat di-tap). Teks dipilih dari state saat ini, contoh:
- Ada diff: `"Ada {n} file yang nunggu direview 👀"` → tap bubble membuka `showGitDiffBottomSheet`.
- Offline: `"Host-nya lagi nggak nyambung. Coba sambungkan ulang?"` → tap memanggil `reconnect()`.
- Error: `"Barusan ada yang gagal. Mau aku coba lagi?"` → tap memanggil `retryMessage` untuk pesan error terakhir.
- Idle tanpa diff: salah satu dari 5 tips acak (tulis 5 tips singkat tentang fitur app, Bahasa Indonesia).
- Sapaan sesuai jam saat pertama kali muncul di Hub (pakai logika sapaan yang sudah ada di Home).

---

## 3. Arsitektur & struktur file

Buat feature baru:

```
lib/features/ai_avatar/
├── domain/
│   ├── avatar_mood.dart            # enum AvatarMood, AvatarReaction, ArmPose, EyeShape
│   └── avatar_expression.dart      # AvatarExpression + lerp + preset per mood (const map)
├── presentation/
│   ├── providers/
│   │   ├── avatar_mood_provider.dart     # Provider<AvatarMood> — derivasi dari state app
│   │   └── avatar_controller.dart        # Notifier: reaksi transient, composerActive, lastInteraction, chunk pulse
│   ├── controllers/
│   │   └── avatar_motion_controller.dart # ChangeNotifier lokal per widget: ticker, kedip, lirik, tilt, spring, partikel
│   ├── painters/
│   │   ├── avatar_body_painter.dart      # layer 1–10
│   │   └── avatar_effects_painter.dart   # layer 11 (partikel)
│   ├── renderers/
│   │   ├── avatar_renderer.dart          # abstract interface + enum AvatarRendererKind
│   │   ├── procedural_avatar_renderer.dart
│   │   ├── rive_avatar_slot.dart         # slot opsional (Fase 6)
│   │   └── glb_avatar_slot.dart          # slot opsional (Fase 6)
│   └── widgets/
│       ├── wynn_ai_avatar.dart           # widget publik utama
│       ├── avatar_speech_bubble.dart
│       └── avatar_debug_page.dart        # halaman preview semua mood (hanya kDebugMode)
```

### 3.1 API widget publik
```dart
enum AvatarSize { xs, sm, md, lg } // 34, 48, 88, 168 dp

class WynnAiAvatar extends ConsumerStatefulWidget {
  const WynnAiAvatar({
    super.key,
    this.size = AvatarSize.md,
    this.customSize,              // override dp jika perlu
    this.interactive = true,
    this.animate = true,          // false = render 1 frame statis
    this.moodOverride,            // paksa mood (dipakai di bubble pesan lama & debug page)
    this.pose = AvatarPoseMode.standing, // standing | peek
    this.heroTag,
    this.showSpeechBubble = false,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
  });
}
```

Level detail per ukuran (penting untuk performa):
| Size | Tangan | Antena goyang | Partikel | Kedip/lirik | Gestur |
|---|---|---|---|---|---|
| `xs` | tidak | tidak | tidak | ya | tap saja |
| `sm` | ya (sederhana) | ya | maks 3 | ya | tap |
| `md` | ya | ya | maks 6 | ya | semua |
| `lg` | ya | ya | maks 8 | ya | semua + speech bubble |

### 3.2 Alur data
```
agentChatProvider ─┐
gitDiffProvider ───┼─► avatarMoodProvider (Provider<AvatarMood>, murni/derivasi)
workspaceProvider ─┤
avatarController ──┘   (reaksi transient, composerActive, sleepy timer)
                                  │  ref.watch (hanya mood, bukan seluruh state)
                                  ▼
                        WynnAiAvatar (ConsumerStatefulWidget)
                                  │  set target expression
                                  ▼
                AvatarMotionController (ChangeNotifier lokal + Ticker)
                                  │  notifyListeners per frame
                                  ▼
          RepaintBoundary → CustomPaint(painter: body, foregroundPainter: effects)
```

Detail:
- `avatarMoodProvider` gunakan `ref.watch(provider.select(...))` untuk field yang relevan saja (`isStreaming`, `errorMessage`, teks pesan terakhir kosong/tidak, `connectionState`, `hasChanges`) — jangan watch seluruh state.
- `AvatarController` (Notifier) menyimpan: `AvatarReaction? activeReaction` + waktu habis, `bool composerActive`, `DateTime lastInteraction`. Method: `triggerReaction(AvatarReaction r, {Duration duration})`, `setComposerActive(bool)`, `registerInteraction()`, `pulseChunk()`.
- **Trigger otomatis** (pasang `ref.listen` di dalam `AvatarController.build`):
  - `agentChatProvider`: `isStreaming` berubah `true → false` tanpa error → `triggerReaction(success)` **hanya jika** ada diff baru (bandingkan jumlah file `gitDiffProvider` sebelum/sesudah) atau pesan agent terakhir berstatus verified; jika tidak, cukup reaksi kecil `nod`.
  - Teks pesan agent terakhir bertambah → `pulseChunk()` (dipakai untuk "kick" mulut).
  - `gitDiffProvider.lastActionMessage` berubah setelah commit sukses → `success`.
- Timer `sleepy`: jangan pakai `Timer.periodic` global. Cukup simpan `lastInteraction` dan biarkan `AvatarMotionController` (yang sudah punya ticker) mengecek selisih waktu.
- `AvatarMotionController` memegang satu `Ticker` (via `TickerProvider` dari State). Semua animasi (napas, kedip, lirik, spring tilt, partikel, transisi ekspresi) dihitung dari `elapsed` di satu tick — **jangan** membuat banyak `AnimationController` terpisah.
- Saat `animate == false`, `disableAnimations == true`, atau app di background: ticker berhenti; painter menggambar ekspresi target secara statis.

### 3.3 Aturan performa (target OPPO Reno8 4G, 60fps)
- Hanya `CustomPaint` yang di-repaint per frame (`repaint: motionController`). Tidak ada `setState` per frame, tidak ada rebuild parent.
- Bungkus avatar dengan `RepaintBoundary`.
- Painter: siapkan `Paint`/`Path` yang bisa dipakai ulang sebagai field; hindari alokasi `Shader` baru setiap frame kecuali ukuran berubah (cache by size).
- `MaskFilter.blur` hanya untuk glow antena dan blush; sigma kecil (≤ 0.04s).
- **Tidak ada `BackdropFilter`** di dalam avatar.
- Di list chat: **hanya avatar pada pesan agent terakhir** yang `animate: true`. Avatar pada pesan lama: `animate: false, interactive: false, moodOverride: idle` (atau `error` jika pesan itu `isError`).
- Pause ticker saat widget tidak terlihat: gunakan `TickerMode.of(context)` (ticker Flutter sudah otomatis mute di route yang tertutup) + `WidgetsBindingObserver` untuk lifecycle.
- `shouldRepaint` harus membandingkan nilai, bukan selalu `true`.

### 3.4 Aksesibilitas
- `Semantics(label: 'Wynn, asisten AI. ${moodLabel}. Ketuk untuk berinteraksi', button: interactive)`.
- `moodLabel` dalam Bahasa Indonesia: "Siap", "Mendengarkan", "Sedang berpikir", "Sedang menjawab", "Berhasil", "Terjadi kesalahan", "Host terputus", "Menyambungkan", "Mengantuk".
- Saat mood berubah ke `error`/`success`/`offline`, panggil `SemanticsService.announce` sekali (jangan untuk streaming).
- Reduce motion: tampilkan ekspresi statis yang sesuai mood (tetap informatif), tanpa gerak, tanpa partikel.

---

## 4. Integrasi ke layar

| Lokasi | Sekarang | Ganti dengan |
|---|---|---|
| `lib/features/agent_chat/presentation/widgets/chat_bubbles.dart` ~baris 211 (avatar pesan agent) | `WynnOrb(size: 34, animate: isStreaming)` | `WynnAiAvatar(size: AvatarSize.xs, animate: isLatestAgentMessage, interactive: isLatestAgentMessage, moodOverride: isLatestAgentMessage ? null : (message.isError ? AvatarMood.error : AvatarMood.idle))`. Tambahkan parameter `isLatestAgentMessage` ke `InvestigationMessageBubble` dan isi dari `investigation_chat_page.dart` |
| `investigation_chat_page.dart` top bar (sebelah judul sesi) | dot status koneksi | Tambah `WynnAiAvatar(size: AvatarSize.sm)` di kiri judul. Tap → buka log host (`showTerminalLogsSheet`). Dot + label status tetap ada |
| `investigation_chat_page.dart` ~baris 517 `_EmptyChatState` | `WynnOrb(size: 74)` | `WynnAiAvatar(size: AvatarSize.md, showSpeechBubble: true)` — speech bubble menyapa dan menyarankan prompt |
| `lib/features/workspace/presentation/widgets/dashboard_cards.dart` ~baris 152 `HostHeroCard` | `Hero(tag: 'wynn-agent-orb', child: WynnOrb(size: 82))` | `WynnAiAvatar(size: AvatarSize.md, customSize: 82, heroTag: 'wynn-agent-orb')`. Tap avatar **tidak** ikut memicu onTap kartu (hentikan propagasi), melainkan reaksi boop + speech bubble status |
| `lib/features/agent_chat/presentation/pages/agent_hub_page.dart` ~baris 77 | `LevitationOrb(size: 158, heroTag: 'wynn-agent-orb')` | `WynnAiAvatar(size: AvatarSize.lg, heroTag: 'wynn-agent-orb', showSpeechBubble: true)` — avatar paling interaktif (tilt, elus, long press) |
| `agent_hub_page.dart` composer di bawah | `PromptComposerCard` | **Pose "peek"**: tambahkan avatar `AvatarSize.sm` dengan `pose: AvatarPoseMode.peek` yang menempel di tepi atas kanan composer (tangan bertumpu di tepi kartu, seperti mengintip) memakai `Stack` + `Positioned(top: -30)`. Pastikan tidak menutupi status strip composer dan tidak menerima tap yang menghalangi input |
| `lib/features/agent_chat/presentation/widgets/prompt_composer_card.dart` | `TextField` tanpa `FocusNode` | Tambah `FocusNode`; listener fokus & `controller` text → `ref.read(avatarControllerProvider.notifier).setComposerActive(hasFocus || text.isNotEmpty)`. Dispose FocusNode |

**Hero transition**: Home → Hub memakai tag `'wynn-agent-orb'`. Pastikan dua sisi Hero me-render `WynnAiAvatar` dan gunakan `flightShuttleBuilder` yang menampilkan avatar statis (`animate: false`) selama terbang agar tidak ada dua ticker berjalan.

**Debug page**: tambahkan entri di halaman Host (di dalam `ExpansionTile` "Info developer" yang sudah ada) → "Preview avatar" yang membuka `AvatarDebugPage` (hanya jika `kDebugMode`). Isinya: grid semua mood × ukuran, slider untuk setiap parameter `AvatarExpression`, dan tombol untuk memicu setiap reaksi.

---

## 5. Fase pengerjaan

### Fase 1 — Domain & ekspresi
- [x] `avatar_mood.dart`: enum `AvatarMood` (idle, listening, thinking, streaming, success, error, offline, connecting, sleepy), `AvatarReaction` (boop, wink, giggle, pet, wave, nod, success, errorShake, startle), `ArmPose`, `EyeShape`, `AvatarPoseMode`.
- [x] `avatar_expression.dart`: class `AvatarExpression` + `lerp` + `const Map<AvatarMood, AvatarExpression> kMoodExpressions` sesuai tabel 1.4, + override ekspresi untuk tiap `AvatarReaction`.
- [x] Token warna di `AppColors`.
- **Selesai jika:** unit test `test/ai_avatar/avatar_expression_test.dart` memverifikasi `lerp(a, b, 0) == a`, `lerp(a, b, 1) == b`, dan nilai tengah berada di antara keduanya.

### Fase 2 — Painter procedural (statis dulu)
- [x] `AvatarBodyPainter` menggambar layer 1–10 dari `AvatarExpression` + `AvatarFrame` (data per frame: breathe, floatY, tilt, pupilOffset, squash, antennaOffset, blinkAmount).
- [x] `AvatarEffectsPainter` untuk partikel.
- [x] `WynnAiAvatar` versi statis (tanpa ticker) yang sudah bisa ditaruh di layar.
- [x] `AvatarDebugPage` grid semua mood.
- **Selesai jika:** semua 9 mood terlihat berbeda dan jelas terbaca di ukuran `xs` (34dp) dan `lg` (168dp). Tidak ada gambar yang terpotong di luar kotak (kecuali antena/partikel yang memang boleh overflow — pakai `clipBehavior: Clip.none` dan sisakan padding).

### Fase 3 — Gerak & mikro-perilaku
- [x] `AvatarMotionController` dengan satu `Ticker`: napas, melayang, kedip acak, lirikan, squash saat ganti mood, antena pegas, transisi ekspresi (lerp 280ms), mulut berbicara, partikel, fidget idle, deteksi sleepy.
- [x] Hormati reduce motion & lifecycle.
- **Selesai jika:** di debug page, avatar terlihat "hidup" saat idle (kedip, lirik, napas) dan transisi antar mood mulus tanpa lompatan.

### Fase 4 — Interaksi sentuhan
- [x] Tap/boop (+wink/giggle berantai), long press + speech bubble, drag-tilt 3D + pupil follow + spring return, deteksi elus, bangun dari sleepy.
- [x] Haptic sesuai tabel 2.
- [x] `AvatarSpeechBubble` dengan teks kontekstual (2.1) dan aksi tap.
- **Selesai jika:** drag terasa responsif (tidak ada jank), lepas jari kembali ke netral dengan pegas, dan elus memicu reaksi senang.

### Fase 5 — State app & integrasi layar
- [x] `avatarMoodProvider` + `AvatarController` dengan trigger otomatis (3.2).
- [x] FocusNode di composer → `setComposerActive`.
- [x] Ganti semua titik di tabel bagian 4, termasuk pose peek di Hub dan Hero.
- [x] Test `test/ai_avatar/avatar_mood_provider_test.dart`: gunakan `ProviderContainer` dengan override provider mock untuk memverifikasi urutan prioritas mood (minimal: offline mengalahkan streaming, error mengalahkan streaming, listening saat composer aktif, thinking vs streaming berdasarkan teks kosong/tidak).
- [x] Widget test: pump `WynnAiAvatar` untuk setiap mood × ukuran tanpa exception; pump dengan `MediaQuery(disableAnimations: true)` dan pastikan `tester.hasRunningAnimations == false` setelah `pump`.
- **Selesai jika:** skenario manual di bagian 7 lulus.

### Fase 6 — Slot renderer eksternal (opsional, tanpa menambah dependency)
- [x] `AvatarRenderer` interface:
  ```dart
  abstract interface class AvatarRenderer {
    Widget build(BuildContext context, AvatarRenderInput input);
  }
  class AvatarRenderInput { // dikirim tiap frame/perubahan
    final AvatarMood mood; final AvatarExpression expression;
    final Offset tilt; final Offset lookAt; final AvatarReaction? reaction; final double size;
  }
  ```
- [x] `ProceduralAvatarRenderer` = implementasi default (pakai painter Fase 2–3).
- [x] `RiveAvatarSlot` & `GlbAvatarSlot`: kelas yang menerima `assetPath` dan `fallback`; karena package belum dipasang, keduanya **selalu** me-render `fallback` (procedural) dan mendokumentasikan di doc-comment cara menghubungkannya:
  - **Rive (direkomendasikan untuk karakter 2.5D/clay ringan):** state machine `"Wynn"` dengan input `mood` (number = `AvatarMood.index`), `tiltX`/`tiltY` (number −1..1), `lookX`/`lookY` (number), trigger `boop`, `wave`, `celebrate`, `shake`.
  - **GLB via `model_viewer_plus`:** catat bahwa ini memakai WebView, lebih berat, sebaiknya hanya untuk ukuran `lg` di Hub; nama animasi yang diharapkan: `idle`, `think`, `talk`, `cheer`, `worry`, `sleep`.
- [x] `WynnAiAvatar` menerima parameter `renderer` (default `ProceduralAvatarRenderer`).
- **Selesai jika:** mengganti renderer tidak mengubah logika mood/gestur, dan app tetap berjalan tanpa aset apa pun.

---

## 6. Hal yang TIDAK boleh dilakukan
- Menambah package (rive, model_viewer_plus, lottie, flame, dll.) di fase 1–6.
- Menggunakan gambar/aset bitmap untuk karakter.
- Meniru karakter dari gambar referensi atau karakter berhak cipta lain.
- Menaruh state tilt/pan di Riverpod.
- Menjalankan lebih dari satu `Ticker` per avatar, atau membiarkan avatar di pesan chat lama tetap beranimasi.
- `BackdropFilter` di dalam avatar.

---

## 7. Checklist akhir

- [x] `flutter analyze` bersih, `flutter test` lulus.
- [ ] Profiling (`flutter run --profile`, Performance overlay) di Hub dengan avatar `lg` + drag terus-menerus: raster & UI thread di bawah 16ms; tidak ada rebuild di luar avatar (cek dengan Flutter DevTools "Track widget rebuilds").
- [ ] Skenario manual:
  1. Buka Home → avatar di Hero card kedip & melirik. Tap → boop + speech bubble status. Tap kartu (di luar avatar) → masuk Hub dengan Hero transition mulus.
  2. Di Hub: drag avatar → miring 3D & mata mengikuti jari, lepas → pegas kembali. Elus → hati & mata ^ ^. Long press → lambai + tips.
  3. Fokus ke composer → avatar (peek & header) berubah ke `listening`, mata melihat ke input.
  4. Kirim prompt → `thinking` (tangan di dagu, "…") → `streaming` (mulut bicara, tangan mengetik) → selesai dengan diff baru → `success` (lompat + sparkle) → kembali `idle`.
  5. Kirim `/fail` → `error` (shake, keringat). Long press → bubble "Mau aku coba lagi?" → tap → retry.
  6. Tab Host → Putuskan → avatar di mana pun berubah `offline` (zZ, antena abu). Tes koneksi → `connecting` → `idle`.
  7. Diamkan 45 detik → `sleepy`. Tap → kaget lalu `idle`.
  8. Aktifkan "Remove animations" di Android → avatar statis tapi ekspresi tetap sesuai mood.
  9. Scroll chat panjang → hanya avatar pesan terakhir yang bergerak.

---

## Changelog

- `Fase 1` — `app_colors.dart`, `avatar_mood.dart`, `avatar_expression.dart`, `test/ai_avatar/avatar_expression_test.dart` — Tambah token warna clay maskot "Wynn", enum mood/reaksi/pose/size, `AvatarExpression` dengan `lerp`, preset 9 mood & 9 reaksi, serta unit test interpolasi.
- `Fase 2` — `avatar_frame.dart`, `avatar_body_painter.dart`, `avatar_effects_painter.dart`, `wynn_ai_avatar.dart`, `avatar_debug_page.dart` — Implementasi painter 3D soft-clay layer 1–10 (dengan cache shader & tanpa `BackdropFilter`), layer 11 partikel (`✦`, `♥`, keringat, `zZ`, `…`), widget publik `WynnAiAvatar`, dan halaman preview debug semua mood + slider.
- `Fase 3` — `avatar_motion_controller.dart`, `avatar_body_painter.dart`, `avatar_effects_painter.dart`, `wynn_ai_avatar.dart`, `avatar_debug_page.dart` — Tambah `AvatarMotionController` berbasis satu `Ticker` (napas, melayang, kedip acak + double-blink, lirikan, squash & stretch, antena pegas ber-lag, transisi 280ms `easeOutCubic`, mulut bicara + chunk kick, fidget idle, deteksi sleepy 45s) dengan kepatuhan Reduce Motion & `WidgetsBindingObserver`.
- `Fase 4` — `avatar_speech_bubble.dart`, `wynn_ai_avatar.dart` — Implementasi interaksi sentuhan (tap berantai boop → wink → giggle + bangun dari sleepy, long press → wave + `AvatarSpeechBubble` kontekstual dengan auto-dismiss 3.5s & aksi tap, drag tilt 3D + pupil follow + `SpringSimulation` return, deteksi elus horizontal + hati & haptic, target sentuh ≥ 48×48).
- `Fase 5` — `avatar_controller.dart`, `avatar_mood_provider.dart`, `wynn_ai_avatar.dart`, `chat_bubbles.dart`, `investigation_chat_page.dart`, `dashboard_cards.dart`, `agent_hub_page.dart`, `prompt_composer_card.dart`, `host_settings_page.dart`, `test/ai_avatar/avatar_mood_provider_test.dart`, `test/ai_avatar/wynn_ai_avatar_test.dart` — Tambah derivasi mood berbasis `.select`, trigger otomatis stream/diff/commit, pengumuman aksesibilitas `SemanticsService.sendAnnouncement`, `FocusNode` composer → `listening`, integrasi Wynn di seluruh layar termasuk Hero `'wynn-agent-orb'` statis saat terbang, pose `peek` di tepi composer Hub, menu `"Preview avatar"` (khusus `kDebugMode`) di Host, serta unit & widget test lengkap.
- `Fase 6` — `avatar_renderer.dart`, `procedural_avatar_renderer.dart`, `rive_avatar_slot.dart`, `glb_avatar_slot.dart`, `wynn_ai_avatar.dart`, `test/ai_avatar/wynn_ai_avatar_test.dart` — Tambah interface `AvatarRenderer`, `ProceduralAvatarRenderer` sebagai default, serta slot eksternal `RiveAvatarSlot` & `GlbAvatarSlot` ber-fallback procedural dengan dokumentasi integrasi state machine Rive & animasi GLB.
