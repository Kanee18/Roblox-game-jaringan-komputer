# 🌐 NET QUEST — Kuis Jaringan Komputer & Internet (Roblox)

Game kuis Roblox untuk **Informatika Kelas 7 SMP**, elemen **Jaringan Komputer dan Internet**.
Siswa belajar sambil bergerak: soal muncul di layar raksasa, siswa **lari dan berdiri di kotak jawaban**,
lalu kotak yang salah **jatuh ke "Lubang Data"**! Setelah setiap soal selalu muncul **penjelasan materi**,
jadi siswa tetap belajar, bukan cuma main.

---

## ✨ Fitur

| Biar seru 🎮 | Biar tetap fokus belajar 📚 |
|---|---|
| Kotak jawaban warna-warni ala game show; kotak yang salah **jatuh** | **Penjelasan materi** muncul setelah SETIAP soal |
| Poin + **bonus kecepatan** + **bonus streak** 🔥 | **Zona Materi**: 6 papan ringkasan materi di lobi (bisa dibuka di layar, cocok untuk HP) |
| Bantuan **💡 50:50** (didapat jika benar 3x berturut-turut) | Soal diurutkan **dari mudah ke sulit** |
| **⚠ SOAL BOS** di akhir ronde (poin x2) | **Tidak ada eliminasi**: siswa yang salah tetap ikut sampai akhir |
| **Podium juara** + konfeti + papan "Juara Ronde Terakhir" | **Rapor pribadi** di akhir ronde: akurasi, topik terkuat & **topik yang perlu dipelajari lagi** |
| **Gelar & XP** yang tersimpan: Kabel Pemula → Hub Junior → Switch Cekatan → Router Hebat → Server Master → Legenda Internet | Saat soal berlangsung, Zona Materi dikunci supaya siswa fokus berpikir |
| Arena bertema jaringan: globe internet, rak server, kabel neon, paket data berjalan | **Panel Guru** untuk memilih topik, jumlah soal, waktu, dan mengontrol jalannya kuis |

### Materi & Bank Soal (68 soal)

| Topik | Jumlah soal |
|---|---|
| 🖧 Konsep Jaringan Komputer (PAN, LAN, MAN, WAN, client-server, P2P) | 11 |
| 🕸️ Topologi Jaringan (bus, star, ring, mesh, tree, rumus kabel mesh) | 12 |
| 📡 Perangkat Jaringan (NIC, UTP/RJ-45, hub, switch, router, modem, access point, repeater) | 10 |
| 🌐 Internet & Cara Kerjanya (ARPANET, ISP, IP address, DNS, URL, protokol, HTTPS, paket data) | 12 |
| 📶 Koneksi Kabel & Nirkabel (UTP, fiber optic, WiFi/SSID, Bluetooth, seluler/BTS, hotspot, Mbps) | 11 |
| 🔒 Keamanan & Proteksi Data (password kuat, OTP, phishing, malware, enkripsi & Caesar cipher, 2FA, cloud) | 12 |

Soal berupa **pilihan ganda (A/B/C/D)** dan **Benar/Salah**. Mode **🎲 Campuran** mengambil soal dari semua topik secara merata.

---

## 🚀 Cara Memasang (paling mudah, tanpa coding)

1. Unduh file **`NetQuest-KuisJaringan.rbxlx`** dari repository ini.
2. Buka **Roblox Studio** → **File → Open from File…** → pilih file tersebut.
3. Tekan tombol **▶ Play** (F5). Arena kuis akan **dibangun otomatis** oleh script.
   *(Saat belum di-Play, dunia memang kosong dan hanya ada papan petunjuk. Itu normal.)*
4. Untuk dimainkan siswa: **File → Publish to Roblox**, lalu atur game menjadi **Public** atau
   bagikan ke akun siswa (Game Settings → Permissions).

**Agar XP & gelar tersimpan permanen:** setelah publish, buka **Game Settings → Security →
aktifkan "Enable Studio Access to API Services"**. Jika tidak diaktifkan, game tetap berjalan normal,
hanya XP tidak tersimpan setelah keluar.

> 💡 Ingin menguji dengan banyak pemain? Di Studio: tab **Test → Clients and Servers → pilih 2-3 Players → Start**.

### Cara alternatif (untuk developer): Rojo
```bash
rojo serve          # sinkron langsung ke Studio dengan plugin Rojo
rojo build -o NetQuest-KuisJaringan.rbxlx   # membangun ulang file place
```

---

## 🎓 Panduan Guru

### Siapa yang bisa membuka Panel Guru?
- **Pemilik game** (akun yang mem-publish) otomatis menjadi guru.
- Akun guru lain: tambahkan di `ReplicatedStorage > QuizShared > Config`, bagian
  `Config.TeacherUserIds` (ID akun) atau `Config.TeacherNames` (username).
- Jika game milik **Grup**, anggota dengan rank ≥ `Config.GroupTeacherMinRank` (default 254) jadi guru.
- Saat diuji di **Roblox Studio**, semua pemain menjadi guru (bisa dimatikan dengan `Config.StudioEveryoneTeacher = false`).

### Isi Panel Guru (tombol 🎓 di kiri layar)
| Tombol | Fungsi |
|---|---|
| **Topik** | Klik untuk mengganti topik ronde berikutnya (Campuran / per bab) |
| **Jumlah soal − / +** | 5 – 30 soal per ronde |
| **Waktu/soal − / +** | 5 – 60 detik untuk soal pilihan ganda |
| **Mulai otomatis ON/OFF** | ON: ronde dimulai otomatis setelah jeda 30 detik. OFF: menunggu guru menekan Mulai |
| **▶ Mulai Kuis Sekarang** | Langsung memulai ronde |
| **⏩ Kunci Jawaban Sekarang** | Menghentikan timer lebih awal jika semua siswa sudah memilih |
| **⏹ Hentikan Ronde** | Menghentikan ronde dan kembali ke lobi |

### Saran alur di kelas (± 40 menit)
1. **5 menit – Eksplorasi**: matikan *Mulai otomatis*, biarkan siswa menjelajah **Zona Materi** di lobi.
2. **10 menit – Ronde 1**: pilih topik yang baru dipelajari, 10 soal.
3. **5 menit – Diskusi**: bahas soal yang banyak salah (lihat jumlah 👥 pemain di tiap kotak saat jawaban diungkap).
4. **10 menit – Ronde 2**: mode 🎲 Campuran.
5. **5 menit – Refleksi**: minta siswa menyebutkan "topik yang perlu dipelajari lagi" dari rapor pribadi mereka.

---

## ✏️ Menambah / Mengubah Soal

Buka `ReplicatedStorage > QuizShared > Questions` (atau file `src/shared/Questions.lua`).
**Jawaban yang benar selalu ditulis PERTAMA**; urutan pilihan akan diacak otomatis di dalam game.

```lua
-- Pilihan ganda
{ topik = "perangkat", lv = 1, q = "Perangkat yang memancarkan WiFi adalah...",
	c = { "Access Point", "Monitor", "Printer", "Keyboard" },
	e = "Access Point memancarkan sinyal WiFi agar perangkat bisa terhubung tanpa kabel." },

-- Benar / Salah
{ topik = "keamanan", lv = 1, bs = true, q = "Password sebaiknya dibagikan ke teman dekat.", jawab = false,
	e = "Salah! Password bersifat rahasia dan tidak boleh dibagikan kepada siapa pun." },
```

- `topik`: `konsep`, `topologi`, `perangkat`, `internet`, `koneksi`, `keamanan`
- `lv`: 1 = mudah, 2 = sedang, 3 = sulit
- `e`: penjelasan yang muncul setelah jawaban diungkap. **Selalu isi**, karena bagian ini yang membuat siswa belajar.

Ringkasan materi di papan Zona Materi bisa diubah di `QuizShared > Materi`.

## ⚙️ Pengaturan Lain (`QuizShared > Config`)
Waktu jeda, poin, bantuan 50:50, nama & batas XP gelar, warna kotak, suara, dan waktu langit
bisa diubah di satu file ini. Setiap baris sudah diberi keterangan bahasa Indonesia.

**Suara & musik:** suara bawaan memakai file standar Roblox. Untuk musik latar, cari audio di **Toolbox → Audio**,
salin ID-nya, lalu isi `Config.MusicId = "rbxassetid://ID_AUDIO"`.

## 🎨 Menghias Arena Sendiri
Arena dibuat oleh script `ServerScriptService > QuizServer > MapBuilder`. Agar bisa dihias di mode edit:
1. Buka **View → Command Bar**, lalu jalankan:
   ```lua
   require(game.ServerScriptService.QuizServer.MapBuilder).Build()
   ```
2. Folder **Workspace > ArenaKuis** akan muncul. Tambahkan hiasan sesukamu, lalu simpan.
3. Jangan menghapus atau mengganti nama bagian penting: `KotakJawaban` (Pad1-4, Papan1-4), `LubangData`, `Layar`, `Podium`.
   Jika ada yang hilang, arena otomatis dibangun ulang saat Play.

---

## 🗂️ Struktur Proyek

```
default.project.json        # proyek Rojo
NetQuest-KuisJaringan.rbxlx # file place siap dibuka di Roblox Studio
src/
├── shared/   → ReplicatedStorage.QuizShared
│   ├── Config.lua      # semua pengaturan game
│   ├── Questions.lua   # bank soal (68 soal) + pengacak
│   └── Materi.lua      # ringkasan materi Zona Materi
├── server/   → ServerScriptService.QuizServer (Script)
│   ├── init.server.lua # alur permainan, skor, panel guru, 50:50
│   ├── MapBuilder.lua  # pembangun arena otomatis
│   └── PlayerData.lua  # penyimpanan XP & gelar (DataStore)
└── client/   → StarterPlayerScripts.QuizClient (LocalScript)
    ├── init.client.lua # tampilan layar: soal, timer, efek, hasil, materi, panel guru
    └── Ui.lua          # fungsi bantu UI
```

Kurikulum acuan: Capaian Pembelajaran Informatika Fase D, elemen Jaringan Komputer dan Internet (JKI).
