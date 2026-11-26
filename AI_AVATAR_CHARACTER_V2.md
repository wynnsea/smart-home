# Wynn v2 — Ganti Karakter Jadi Chibi Anime Girl

Dokumen ini instruksi untuk AI coding agent (Gemini CLI). Ini **revisi** dari `AI_AVATAR_TASKS.md` yang semua fasenya (1–6) sudah selesai.

**Masalah:** karakter yang sekarang adalah maskot mochi berhoodie dengan antena. Yang diinginkan: **karakter cewek chibi bergaya anime dalam render 3D clay / soft-toy** — seperti gambar referensi: cewek berambut cokelat dicepol berantakan, hoodie lavender, mata besar ekspresif, pipi merona, pose mengintip dari balik kartu dengan tangan bertumpu di tepi kartu dan satu tangan menopang pipi sambil wink.

**Yang dipertahankan (JANGAN diubah logikanya):** `avatar_mood.dart` (enum), `avatar_mood_provider.dart`, `avatar_controller.dart`, sistem gestur di `wynn_ai_avatar.dart`, `avatar_speech_bubble.dart`, `AvatarMotionController` (ticker, kedip, lirik, spring, partikel, sleepy), interface `AvatarRenderer`, semua integrasi layar, dan semua test yang ada (boleh disesuaikan kalau nama field berubah).

**Yang diganti:** visual karakter (painter), sebagian field `AvatarExpression`/`AvatarFrame` yang spesifik mochi, dan ditambah renderer berbasis sprite berlapis.

---

## 0. Aturan

1. Tampilkan dulu rencana file yang diubah/ditambah, lalu kerjakan.
2. Kode lengkap, bisa di-compile, tanpa `TODO`/fungsi kosong.
3. Import UI tetap `package:material_ui/material_ui.dart`. Riverpod 3 `Notifier`. Tidak menambah dependency.
4. Jalankan `flutter analyze` + `flutter test` setiap fase, isi **Changelog** di bawah.
5. Karakter adalah **desain original** bernama Wynn yang terinspirasi *gaya* referensi (chibi anime, 3D clay, palet lavender). Jangan menjiplak karakter anime/game yang sudah ada.

---

## 1. Strategi render (penting, baca dulu)

Render 3D clay seperti referensi **tidak bisa didapat 100% dari `CustomPainter`**. Karena itu ada dua renderer yang bisa dipertukarkan lewat interface `AvatarRenderer` yang sudah ada:

| Renderer | Kualitas | Butuh aset? | Status |
|---|---|---|---|
| **A. `ChibiProceduralRenderer`** | Chibi anime "semi-3D" (gradient, highlight, soft shadow). Mirip gaya, tidak sehalus referensi | Tidak | **Default sekarang**, menggantikan painter mochi |
| **B. `LayeredSpriteRenderer`** | Sama persis dengan gaya referensi (aset PNG hasil render/ilustrasi) dan tetap interaktif karena tiap bagian tubuh adalah layer terpisah yang digerakkan Flutter | Ya, PNG di `assets/avatar/wynn/` | Otomatis dipakai **jika** `assets/avatar/wynn/manifest.json` ada; kalau tidak ada, jatuh ke A |

Pemilihan otomatis: buat `avatarRendererProvider` (`FutureProvider<AvatarRenderer>`) yang mengecek `AssetManifest.loadFromAssetBundle(rootBundle)` apakah `assets/avatar/wynn/manifest.json` terdaftar. Selama loading, pakai A. `WynnAiAvatar` memakai provider ini bila parameter `renderer` tidak diberikan secara eksplisit.

---

## 2. Desain karakter Wynn v2

### 2.1 Proporsi chibi
Rasio dihitung terhadap tinggi kanvas `h` (kanvas persegi `s × s`, `h = s`).

- **Kepala ~58% tinggi badan terlihat**, badan kecil, tangan bulat (mitten-like, jari tidak perlu digambar terpisah di procedural).
- Pusat kepala `(0.5s, 0.40s)`, radius wajah horizontal `0.27s`, vertikal `0.25s` (wajah sedikit lebih lebar, dagu membulat lembut — bukan lancip).
- Badan (hoodie) mulai `0.62s` sampai bawah kanvas, lebar bahu `0.62s`.
- Mata di garis `0.44s`, jarak antar pusat mata `0.20s`, ukuran mata `0.10s × 0.13s` (tinggi > lebar, gaya anime).

### 2.2 Layer (belakang → depan)

| # | Layer | Detail visual | Gerak sekunder |
|---|---|---|---|
| 1 | Contact shadow | Elips lembut di bawah | Mengecil saat melayang |
| 2 | **Rambut belakang** | Massa rambut cokelat `hairBase #6B4532` di belakang kepala, ujung bergelombang, sampai bahu | Bergoyang (spring) mengikuti tilt & napas, lag lebih besar dari kepala |
| 3 | **Cepol (bun)** | Lingkaran rambut di atas-belakang kepala agak ke kiri, dengan 2–3 helai lepas melengkung | Bergoyang dengan pivot di dasar cepol |
| 4 | Badan / hoodie | Hoodie lavender (`avatarHoodLight`→`avatarHood`), kerah hoodie membulat di leher, **2 tali hoodie** putih kecil dengan ujung bulat | Napas (scaleY) |
| 5 | Leher | Pendek, warna kulit sedikit lebih gelap (bayangan) | — |
| 6 | Kepala / wajah | Kulit `skinBase #FFE3D3` dengan shading `skinShade #F5C2AE` di tepi bawah & bawah poni, highlight lembut di dahi & pipi | Head tilt (rotasi Z kecil) + tilt 3D |
| 7 | Telinga | Kecil, sebagian tertutup rambut samping | — |
| 8 | Pipi | Blush `avatarBlush` + 2–3 garis kecil miring (gaya anime) saat `blush > 0.6` | — |
| 9 | **Mata anime** | Lihat 2.3 | Kedip, lirik, bentuk |
| 10 | Alis | Tipis melengkung warna `hairShade`, sebagian tertutup poni | `browTilt` / `browRaise` |
| 11 | Hidung | Titik kecil / garis pendek samar | — |
| 12 | Mulut | Lihat 2.4 | Bicara |
| 13 | **Rambut depan (poni)** | Poni menyamping berpotongan runcing-lembut (3–5 "tusuk" helai), menutupi sebagian dahi & alis; **rambut samping** dua untai di depan telinga sampai pipi/bahu | Spring paling ringan (paling cepat bergoyang) |
| 14 | **Ahoge + jepit bintang** | Satu helai rambut mencuat di atas kepala (*ahoge*) dan **jepit rambut bintang kecil** di sisi poni yang **menyala sesuai mood** — ini pengganti antena | Ahoge memakai spring `antennaOffset` yang sudah ada |
| 15 | **Tangan & lengan hoodie** | Lengan hoodie lavender tebal, tangan kulit bulat | Pose dari `ArmPose` (2.5) |
| 16 | Efek | Partikel yang sudah ada (✦ ♥ keringat zZ …) + **tanda "!"** untuk startle | — |

Highlight "clay" untuk semua bentuk besar: radial gradient terang di kiri-atas, gelap di kanan-bawah, dan **rim light** tipis putih alpha 0.25 di tepi kiri. **Tanpa outline hitam** (inilah yang membuat kesan 3D clay, bukan anime 2D flat).

Token warna baru di `AppColors` (bagian `// AI avatar`):
```dart
static const Color avatarSkin = Color(0xFFFFE3D3);
static const Color avatarSkinShade = Color(0xFFF5C2AE);
static const Color avatarHair = Color(0xFF6B4532);
static const Color avatarHairShade = Color(0xFF4A2E22);
static const Color avatarHairHighlight = Color(0xFF9A6A4E);
static const Color avatarIris = Color(0xFF5A3A2E);
static const Color avatarIrisLight = Color(0xFFA9765A);
static const Color avatarStarClip = Color(0xFFFFD66B);
```
Token mochi yang tidak terpakai lagi (`avatarFace` dsb.) dihapus.

### 2.3 Mata anime (bagian terpenting untuk ekspresi)
Satu mata terdiri dari:
1. **Sklera** putih (bentuk oval tinggi, bagian atas sedikit rata).
2. **Iris** besar (≈ 75% tinggi mata), gradient vertikal `avatarIris` (atas) → `avatarIrisLight` (bawah), di-clip ke dalam sklera.
3. **Pupil** gelap kecil di tengah iris.
4. **Highlight**: 1 besar oval di kiri-atas iris + 1 kecil di kanan-bawah (putih alpha 0.95). Highlight **tidak** ikut bergerak penuh saat lirik (geser 30% saja) supaya terlihat "basah".
5. **Garis kelopak atas** tebal `avatarHairShade`, dengan 2 bulu mata kecil di ujung luar.
6. Lirik (`pupilOffset`) menggeser iris+pupil di dalam sklera, di-clip.

Bentuk khusus dari `EyeShape`:
| EyeShape | Gambar |
|---|---|
| `normal` | Seperti di atas |
| `wide` | Sklera +15%, iris mengecil 85% (kesan kaget/waspada), highlight lebih besar |
| `happy` | Mata tertutup lengkung **^** (garis tebal melengkung ke atas) |
| `squeeze` | **> <** |
| `winkRight` (bool) | Mata kanan jadi lengkung **^** atau garis lengkung kebawah ala wink, mata kiri normal — persis pose referensi |
| `eyeOpen` kecil | Kelopak atas turun menutupi (clip dari atas); pada 0 jadi garis lengkung bawah |

### 2.4 Mulut
- `mouthCurve > 0.5` dan `mouthOpen > 0.3` → mulut terbuka senyum lebar (bentuk "D") dengan lidah merah muda di bawah, gigi atas putih tipis.
- `mouthOpen` kecil + curve positif → senyum kecil (garis lengkung) atau "ω" kucing saat `blush > 0.7` (opsional, imut).
- `mouthCurve < 0` → cemberut kecil / garis bergelombang (khawatir).
- Bicara (`mouthTalkBoost`) → bergantian antara "a" (oval terbuka) dan "i" (lebar tipis).
- `sleepy` menguap → oval besar vertikal.

### 2.5 Pose tangan (`ArmPose`)
| ArmPose | Gambar | Referensi |
|---|---|---|
| `peek` | Kedua lengan terlipat di tepi bawah kanvas, tangan bulat menggantung di atas "tepi kartu" | Pose utama referensi |
| `chin` | Tangan kanan menopang pipi (telapak di bawah pipi, kepala sedikit miring ke tangan), tangan kiri `peek`/rest | Referensi (tangan di pipi) — dipakai `thinking` dan idle-fidget |
| `rest` | Tangan di samping badan / di depan perut | |
| `wave` | Tangan kanan terangkat melambai (rotasi bolak-balik) | |
| `cheer` | Dua tangan terkepal ke atas | `success` |
| `type` | Dua tangan di depan bergantian naik-turun cepat | `streaming` |
| `worry` | Dua tangan dekat mulut/pipi | `error` |

Saat `AvatarPoseMode.peek` badan bawah dipotong oleh tepi bawah kanvas (seperti badan di balik kartu) dan `ArmPose.rest` digambar sebagai `peek`.

### 2.6 Penyesuaian field domain
Ganti nama field yang spesifik mochi (update semua pemakaian & test):
| Lama | Baru | Makna |
|---|---|---|
| `earPerk` | `ahogePerk` | Ahoge berdiri tegak (1) / layu (0) — `listening` tinggi, `sleepy`/`offline` layu |
| `antennaColor` | `accentColor` | Warna nyala jepit bintang & ahoge-tip glow |
| `antennaGlow` | `accentGlow` | Kekuatan nyala |
| `AvatarFrame.antennaOffset` | `hairSwayOffset` | Dipakai untuk rambut belakang, cepol, poni, ahoge (dengan multiplier berbeda per layer: poni 0.6, samping 0.8, belakang 1.0, cepol 0.7, ahoge 1.4) |
| `AvatarSize.swayAntenna` | `swayHair` | |

Tambahan di `AvatarExpression`: `double headTilt` (−1..1, kepala miring ke samping; `chin` dan `thinking` memakai +0.35), ikut di-lerp.

### 2.7 Mood (update dari tabel `AI_AVATAR_TASKS.md` §1.4)
Logika & prioritas tidak berubah. Hanya ekspresi visualnya:

| Mood | Wynn v2 |
|---|---|
| `idle` | Senyum manis, kedip, lirik. Pose `peek`. Fidget acak: pindah ke `chin` + wink (pose referensi) 2.5s, merapikan poni dengan satu tangan, menguap kecil |
| `listening` | Mata `wide` berbinar (highlight membesar), ahoge tegak, badan condong ke depan, mulut "o" kecil antusias, jepit bintang biru |
| `thinking` | `chin`, kepala miring, mata melirik ke atas-samping, bibir mengerucut, "…" di samping kepala, jepit bintang biru berdenyut |
| `streaming` | `type`, mulut bicara, mata membaca kiri→kanan, jepit ungu berdenyut cepat |
| `success` | `happy` ^ ^, mulut "D" lebar, `cheer`, lompat kecil, sparkle, jepit hijau terang |
| `error` | `wide`, alis khawatir, cemberut bergelombang, `worry`, tetes keringat di pelipis, ahoge melengkung jadi "?", jepit amber berkedip |
| `offline` | Mata hampir tertutup, kepala tertunduk sedikit, ahoge layu, "zZ", jepit abu-abu |
| `connecting` | Mata melirik kiri-kanan, mulut "o", jepit amber berputar pelan |
| `sleepy` | Kelopak turun pelan, kepala mengangguk-angguk (head bob), menguap, "zZ" |

Reaksi gestur (sudah ada, update visual):
- `boop` → mata `squeeze` > <, blush penuh + garis blush, ahoge memantul.
- `wink` → **wink + tangan `chin`** (pose referensi).
- `giggle` → mata `happy`, tangan menutup mulut, badan bergetar.
- `pet` (dielus) → mata `happy`, blush, hati, rambut bergoyang ke arah elusan (pakai arah drag sebagai impuls ke spring rambut).
- `startle` → mata `wide`, "!" di atas kepala, ahoge tegak lurus.

### 2.8 Ukuran kecil
Chibi di 34dp tidak terbaca kalau digambar seluruh badan. Tambah mode framing:
| AvatarSize | Framing |
|---|---|
| `xs` (34) | **Bust/close-up**: hanya kepala + sedikit bahu, kepala memenuhi ~90% kanvas. Tanpa tangan, tanpa sway rambut, mata & mulut tetap animasi |
| `sm` (48) | Kepala + bahu, tangan hanya untuk `peek`/`cheer` |
| `md` (88) | Setengah badan, semua pose |
| `lg` (168) | Setengah badan penuh detail, semua efek |

Implementasi: painter menerapkan `canvas.scale/translate` framing di awal berdasarkan `AvatarSize`, jadi geometri internal tetap satu set.

---

## 3. Fase pengerjaan

### Fase A — Domain update
- [x] Rename field sesuai 2.6, tambah `headTilt`, update preset `kMoodExpressions` & reaksi sesuai 2.7.
- [x] Token warna baru, hapus token mochi yang tak terpakai.
- [x] Update test yang terdampak.
- **Selesai jika:** `flutter analyze` & `flutter test` lulus tanpa perubahan perilaku mood.

### Fase B — `ChibiProceduralRenderer`
- [x] File baru `presentation/painters/chibi_body_painter.dart` (gantikan `avatar_body_painter.dart`; hapus file lama setelah semua referensi pindah). Pecah method per layer: `_drawHairBack`, `_drawBun`, `_drawBody`, `_drawFace`, `_drawEyes`, `_drawBrows`, `_drawMouth`, `_drawBangs`, `_drawAhogeAndClip`, `_drawArms`. Setiap method < 120 baris.
- [x] Rambut: buat dengan `Path` kurva Bézier; poni = 4–5 helai berbentuk daun runcing; setiap helai memiliki pivot di atas dan dirotasi oleh `hairSwayOffset × multiplier`.
- [x] Mata sesuai 2.3 dengan `canvas.save/clipPath` untuk iris & kelopak.
- [x] Framing per ukuran sesuai 2.8.
- [x] Pertahankan aturan performa: cache `Paint`/`Shader` per ukuran, `shouldRepaint` berbasis nilai, tanpa `BackdropFilter`, `MaskFilter.blur` hanya untuk blush, glow jepit, dan contact shadow.
- [x] `ProceduralAvatarRenderer` → rename `ChibiProceduralRenderer` (update referensi).
- [x] `AvatarDebugPage`: tambahkan toggle background terang/gelap dan toggle framing agar mudah dicek.
- **Selesai jika:** di debug page karakter jelas terbaca sebagai cewek chibi berambut cokelat dicepol dengan hoodie lavender, semua mood & reaksi terlihat berbeda, `xs` tetap jelas wajahnya.

### Fase C — `LayeredSpriteRenderer` (aset opsional)
- [x] File baru `presentation/renderers/layered_sprite_renderer.dart` + `presentation/painters/sprite_avatar_painter.dart`.
- [x] Baca `assets/avatar/wynn/manifest.json` (format di §4), load semua `ui.Image` sekali (cache statis di memori, `precacheImage`/`decodeImageFromList`), lalu gambar dengan `canvas.drawImageRect` per layer di painter yang sama-sama mendengarkan `AvatarMotionController`.
- [x] Pemilihan varian dari parameter kontinu: mata → `happy`/`squeeze`/`wink` dari `eyeShape`; `eyeOpen < 0.15` → `closed`, `< 0.6` → `half`, selain itu `open`/`wide`. Mulut → aturan 2.4 dipetakan ke nama varian. Alis → `neutral`/`raised`/`worried`/`focused` dari `browTilt`/`browRaise`. Lengan → nama `ArmPose`.
- [x] Gerak: layer `hair_*` dan `ahoge` dirotasi di sekitar `pivot` masing-masing oleh `hairSwayOffset`; `iris` digeser oleh `pupilOffset` dan di-clip oleh mask sklera (layer `eye_mask`); seluruh kepala ikut `headTilt` + tilt 3D; badan ikut napas; tangan `wave`/`type` diberi rotasi/translate kecil di atas sprite pose.
- [x] Jika satu varian tidak ada di manifest → pakai varian `default` layer itu; jika manifest invalid → log `debugPrint` sekali dan jatuh ke renderer A (jangan crash).
- [x] `avatarRendererProvider` (§1) + update `WynnAiAvatar`.
- [x] Sertakan **1 set aset contoh minimal yang dibuat programatik?** → **Tidak.** Cukup pastikan fallback bekerja. Tambahkan test yang memastikan manifest tidak ada → renderer A.
- [x] Tambahkan `assets/avatar/wynn/` di `pubspec.yaml` **hanya** jika foldernya ada; jika belum, tulis petunjuk di §4 saja (jangan bikin folder kosong yang membuat build gagal).
- **Selesai jika:** tanpa aset app berjalan normal dengan renderer A; logika pemilihan varian punya unit test.

### Fase D — Polish
- [x] Hero transition Home → Hub tetap mulus dengan karakter baru.
- [x] Pose `peek` di tepi composer Hub: tangan karakter benar-benar terlihat bertumpu di tepi atas kartu composer (sesuaikan `Positioned` agar garis tepi kartu tepat di bawah tangan).
- [x] Cek semua skenario manual di `AI_AVATAR_TASKS.md` §7 masih lulus.
- [x] Profiling: avatar `lg` + drag di Hub tetap < 16ms per frame.

---

## 4. Spesifikasi aset untuk `LayeredSpriteRenderer`

Bagian ini juga panduan buat pemilik project jika ingin membuat aset sendiri (render 3D / ilustrasi / AI image generator lalu dipotong per layer).

### 4.1 Aturan umum
- Semua PNG transparan, **kanvas sama 1024×1024**, karakter di posisi yang sama persis di semua file (supaya layer pas ditumpuk tanpa offset).
- Pencahayaan konsisten dari kiri-atas, gaya 3D clay matte, tanpa outline hitam.
- Ukuran total disarankan < 3 MB (kompres dengan pngquant/oxipng).

### 4.2 Daftar layer
```
assets/avatar/wynn/
├── manifest.json
├── shadow.png
├── hair_back.png
├── hair_bun.png
├── body_hoodie.png
├── head_base.png            # wajah + telinga tanpa mata/mulut/alis
├── blush.png
├── eye_mask.png             # bentuk sklera kedua mata (dipakai untuk clip iris)
├── eye_white.png
├── iris.png                 # kedua iris + pupil, posisi tengah
├── eye_highlight.png
├── eyes_half.png  eyes_closed.png  eyes_happy.png  eyes_squeeze.png  eyes_wink.png  eyes_wide.png
├── brows_neutral.png  brows_raised.png  brows_worried.png  brows_focused.png
├── mouth_smile.png  mouth_grin.png  mouth_o.png  mouth_talk_a.png  mouth_talk_i.png
├── mouth_frown.png  mouth_flat.png  mouth_yawn.png  mouth_cat.png
├── hair_bangs.png
├── hair_side_left.png  hair_side_right.png
├── ahoge.png
├── star_clip.png            # jepit, diwarnai ulang lewat ColorFilter sesuai accentColor
├── arms_peek.png  arms_chin.png  arms_rest.png  arms_wave.png
├── arms_cheer.png  arms_type.png  arms_worry.png  arms_cover_mouth.png
└── fx_sweat.png  fx_exclaim.png  fx_question.png
```
Mata variasi (`eyes_*`) menggantikan gabungan `eye_white + iris + eye_highlight` saat aktif.

### 4.3 `manifest.json`
```json
{
  "version": 1,
  "canvas": 1024,
  "layers": {
    "hair_back":  { "file": "hair_back.png",  "pivot": [512, 300], "sway": 1.0 },
    "hair_bun":   { "file": "hair_bun.png",   "pivot": [430, 170], "sway": 0.7 },
    "hair_bangs": { "file": "hair_bangs.png", "pivot": [512, 260], "sway": 0.6 },
    "ahoge":      { "file": "ahoge.png",      "pivot": [520, 150], "sway": 1.4 },
    "iris":       { "file": "iris.png",       "maxOffset": [22, 14] }
  },
  "variants": {
    "eyes":  ["half", "closed", "happy", "squeeze", "wink", "wide"],
    "brows": ["neutral", "raised", "worried", "focused"],
    "mouth": ["smile", "grin", "o", "talk_a", "talk_i", "frown", "flat", "yawn", "cat"],
    "arms":  ["peek", "chin", "rest", "wave", "cheer", "type", "worry", "cover_mouth"]
  },
  "headPivot": [512, 560],
  "framing": {
    "xs": { "center": [512, 430], "scale": 2.1 },
    "sm": { "center": [512, 470], "scale": 1.6 },
    "md": { "center": [512, 520], "scale": 1.15 },
    "lg": { "center": [512, 540], "scale": 1.0 }
  }
}
```

### 4.4 Prompt contoh untuk membuat base karakter (AI image generator)
> *Original chibi anime girl mascot named Wynn, 3D clay render, soft matte plasticine texture, big expressive brown eyes with glossy highlights, rosy blush cheeks, messy brown hair in a high side bun with loose strands and side-swept bangs, a single ahoge strand, small yellow star hair clip, oversized lavender hoodie with white drawstrings, cute friendly smile, front view, centered, arms resting on the bottom edge as if peeking over a card, soft studio lighting from top-left, plain transparent background, no outline, Pixar-like toy style, consistent character sheet.*

Lalu buat varian ekspresi dengan seed/karakter yang sama (wink + hand on cheek, happy closed eyes cheering, worried with sweat drop, sleepy yawning, focused thinking with hand on chin, surprised wide eyes), dan pisahkan per layer di editor gambar (Photoshop/Krita/GIMP) sesuai daftar 4.2.

---

## 5. Checklist akhir
- [x] `flutter analyze` bersih, `flutter test` lulus.
- [x] Tanpa folder aset: karakter chibi procedural tampil di semua titik integrasi (bubble chat `xs`, top bar `sm`, empty state & hero card `md`, Hub `lg`, peek di composer).
- [x] Semua gestur (boop, wink berantai, giggle, elus, long press, drag tilt) tetap jalan; rambut & ahoge bergoyang saat di-drag.
- [x] Reduce motion: statis tapi ekspresi sesuai mood.
- [x] Performa: < 16ms/frame saat drag avatar `lg`.

---

## Changelog
<!-- Agent: `Fase X — file — catatan` -->
- `Fase A — app_colors.dart, avatar_mood.dart, avatar_expression.dart, avatar_frame.dart, avatar_motion_controller.dart, avatar_effects_painter.dart, avatar_expression_test.dart — Tambah token warna 3D clay chibi & hapus avatarFace; rename ahogePerk/accentColor/accentGlow/hairSwayOffset/accentPulse/swayHair; tambah headTilt, ArmPose.coverMouth, AvatarParticleKind.exclamation, talkShape, isYawning, isQuestionAhoge; tambah impuls arah elusan ke spring rambut dan fidget idle chin+wink 2.5s; flutter analyze 0 issue & 15/15 test lulus.`
- `Fase B — chibi_body_painter.dart, chibi_procedural_renderer.dart, avatar_renderer.dart, rive_avatar_slot.dart, glb_avatar_slot.dart, wynn_ai_avatar.dart, avatar_debug_page.dart — Ganti painter mochi (hapus avatar_body_painter.dart & procedural_avatar_renderer.dart) dengan ChibiBodyPainter 3D soft-clay (cepol berantakan, poni menyamping & helai samping bergoyang, hoodie lavender + tali + manset tebal, mata anime glossy ber-highlight basah & clip kelopak, mulut D/cat/yawn/talk, ahoge & jepit bintang menyala, framing xs/sm/md/lg); tambah toggle BG terang/gelap & framing di AvatarDebugPage; flutter analyze 0 issue & 15/15 test lulus.`
- `Fase C — layered_sprite_renderer.dart, sprite_avatar_painter.dart, avatar_renderer_provider.dart, wynn_ai_avatar.dart, layered_sprite_renderer_test.dart — Tambah LayeredSpriteRenderer & SpriteAvatarPainter membaca manifest.json (§4.3) dengan cache ui.Image statis, clip iris via eye_mask, rotasi pivot rambut/ahoge, color filter jepit bintang, fallback varian default & fallback aman ke ChibiProceduralRenderer saat aset/manifest tidak ada atau rusak; integrasi otomatis via avatarRendererProvider; tambah 7 unit test varian & fallback (22/22 test lulus).`
- `Fase D — chibi_body_painter.dart, wynn_ai_avatar.dart, agent_hub_page.dart, wynn_ai_avatar_test.dart — Rapikan clipping pose peek di tepi atas kartu composer (hoodie & manset sejajar garis kartu, hanya tangan menjuntai di atas tepi kartu), haluskan Hero flightShuttleBuilder Home→Hub dengan SizedBox.expand + dukungan sprite/procedural, tambah uji AvatarDebugPage & benchmark paint 60 frame lg (< 16ms/frame); verifikasi penuh flutter analyze (0 issue) & 24/24 test lulus.`
