# WynnDiff

Mobile client untuk remote coding by prompt dan real-time `git diff` review (bagian dari ekosistem **Wynnsea**).

> **Status Tahap 1 (UI/UX & Clean Architecture):** Fokus saat ini pada desain UI/UX Flutter dengan **Clean Architecture** + **Riverpod** serta mock streaming & diff data yang realistis dan siap diuji langsung di HP Android (OPPO Reno8 4G / emulator). Backend `bridge/` (Go / FastAPI) dapat ditambahkan pada tahap berikutnya tanpa mengubah layer `domain/` maupun `presentation/`.

---

## Struktur Folder (Clean Architecture)

```text
wynnsea_agent/
├── README.md
├── pubspec.yaml
└── lib/
    ├── main.dart
    ├── app.dart
    ├── core/
    │   ├── theme/
    │   │   ├── app_colors.dart           # Palet ethereal pastel lavender/sky/peach + warna diff
    │   │   └── app_theme.dart            # Typography (Plus Jakarta Sans & JetBrains Mono)
    │   └── widgets/
    │       ├── ethereal_background.dart  # Living mesh gradient backdrop lembut
    │       ├── glass_surface.dart        # Frosted white cards & circular icon buttons
    │       ├── motion_widgets.dart       # FadeSlideEntrance, BouncyTap, LevitationOrb, dll.
    │       ├── wynn_orb.dart             # Iridescent animated AI Orb (CustomPainter)
    │       └── file_chip.dart            # Inline chip file kode (.dart, .ts, .tsx, .go)
    └── features/
        ├── workspace/                    # Home Dashboard & Host Settings
        │   ├── domain/                   # Entities, Repository interface, UseCase
        │   ├── data/                     # Mock datasource & Repository impl
        │   └── presentation/             # Riverpod providers, HomeDashboardPage, FloatingBottomNav
        ├── agent_chat/                   # AI Agent Hub & Investigation Stream
        │   ├── domain/                   # ChatMessage, FindingItem, AgentMode, ExecutionLog
        │   ├── data/                     # Mock SSE streaming datasource & Repository impl
        │   └── presentation/             # AgentHubPage, InvestigationChatPage, PromptComposerCard
        └── git_diff/                     # Changed Files & Unified Diff Viewer
            ├── domain/                   # DiffFile, DiffLine, Commit/Discard UseCases
            ├── data/                     # Mock Git Diff datasource & Repository impl
            └── presentation/             # GitDiffPage, GitDiffBottomSheet, UnifiedDiffViewer
```

---

## Mapping Desain UI/UX

1. **Home Dashboard (`HomeDashboardPage`)**
   - Header sapaan & avatar + tombol notifikasi/log host.
   - **Active Host Session Card**: progress bar gradasi ungu + animasi AI Orb `ONLINE`.
   - **Quick Workspace (2x2 Grid)**: kartu pastel (`Investigate`, `Git Diff`, `Test Suite`, `Bridge Sync`) lengkap dengan circular ring gauge.
   - **Continue Coding**: daftar thread/sesi terbaru dengan progress bar & jumlah file diff.
   - **Floating Pill Navigation Bar + Purple Sparkle FAB**: navigasi mengambang + tombol cepat ke AI Agent Hub.

2. **WynnDiff Agent Hub (`AgentHubPage`)**
   - Centerpiece **Iridescent AI Orb** beranimasi halus.
   - Sapaan *"Hello, Wynnsea / How Can I help you?"* + 2 kartu aksi cepat (`Investigate Code`, `Review Git Diff`).
   - **Dual-layer Bottom Prompt Composer**: bar status model/mode + link jumlah file diff, input multi-baris, mode/model picker, lampiran konteks, voice UI toggle, dan tombol kirim gradasi ungu.

3. **Investigation Chat Stream (`InvestigationChatPage`)**
   - Top bar dengan judul sesi, repo & branch, tombol cepat Terminal/Logs, Changed Files/Diff (dengan badge), dan Branch switcher.
   - Bubble user gradasi ungu & bubble agent putih frosted dengan mini orb, status badge, temuan bernomor, sub-bullets, dan inline file chips yang bisa diketuk langsung membuka diff.

4. **Changed Files & Unified Git Diff (`GitDiffBottomSheet` & `GitDiffPage`)**
   - Daftar file berubah (`+`, `~`, `-`), ringkasan baris `+` / `-`, tampilan unified diff dengan line gutter hijau/merah, serta aksi **Commit & Push** dan **Discard Changes** dengan dialog konfirmasi.

---

## Cara Menjalankan di Android (OPPO Reno8 4G / Emulator)

```bash
flutter pub get
flutter run
```

Untuk verifikasi lint & widget test:

```bash
flutter analyze
flutter test
```

---

## Catatan Tahap Berikutnya (`bridge/` + Tailscale)

Saat siap menghubungkan ke mesin host asli:
- Tambahkan folder `bridge/` (Go atau FastAPI) untuk endpoint `POST /prompt`, `GET /git/status`, `GET /git/diff`, `POST /git/commit`, `POST /git/reset`.
- Ganti implementasi datasource di `mobile/lib/features/*/data/datasources/` tanpa menyentuh `domain/` maupun `presentation/`.
- Gunakan **Tailscale** antar HP dan host Linux sehingga tidak perlu membuka port publik ke internet.
