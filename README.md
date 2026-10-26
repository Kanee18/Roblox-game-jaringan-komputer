# 🌐 NET QUEST — Kuis Jaringan Komputer & Internet (Roblox)

Game kuis Roblox untuk **Informatika Kelas 7 SMP**, elemen **Jaringan Komputer dan Internet**.
Siswa mendaftar dengan **nama & nomor absen**, lalu belajar lewat **4 mode permainan** yang bergantian,
di dunia taman yang nyaman. Setiap jawaban benar menambah **Poin Rank** yang membuka **gelar** dan **pet keren**.

---

## ✨ Fitur Utama

### 📝 Pendaftaran Siswa
- Saat masuk, siswa **wajib mengisi Nama Lengkap, Nomor Absen, dan Kelas** sebelum bisa bergerak & ikut kuis.
- Nomor absen yang sama di kelas yang sama ditolak (mencegah salah ketik / dobel).
- Nama tampil di atas kepala: `05. Budi Santoso (7A)` + gelar, jadi guru mudah mengenali siswa.
- Data tersimpan; saat masuk lagi formulir sudah terisi otomatis.
- Guru bisa menekan **"Saya guru (lewati pendaftaran)"**.

### 🎮 4 Mode Permainan (bergiliran tiap ronde)
| Mode | Cara main | Kenapa seru / menantang |
|---|---|---|
| 🏃 **Lari & Pilih** | Lari & berdiri di kotak jawaban A/B/C/D. Kotak salah **jatuh** ke Lubang Data | Gerak fisik, tegang menunggu kotak jatuh |
| ⚡ **Kuis Kilat** | Tekan tombol jawaban di layar. Jawaban **tidak bisa diganti** | Adu cepat, bonus kecepatan sampai +100 |
| 🧱 **Lintasan Firewall** | **Balapan obby** di langit. Tiap gerbang ada soal & 4 **pintu**. Pintu salah = lantai tembus, jatuh! | Lompat-lompatan + berpikir; poin hanya jika benar di percobaan pertama; bonus juara finish |
| 🔐 **Pecahkan Sandi** | **Ketik** jawaban isian & pecahkan **Caesar Cipher** (contoh: `SPVUFS` geser 1 = `ROUTER`) | Tidak bisa menebak dari pilihan; melatih materi enkripsi |

Semua mode punya: **penjelasan materi setelah setiap soal**, soal **mudah → sulit**, **SOAL BOS** (poin x2),
**streak** 🔥, dan **bantuan** 💡 (50:50 atau petunjuk huruf) yang didapat jika benar 3x berturut-turut.

### 🐾 Hadiah: Poin Rank, Gelar & Pet
Semua poin dari jawaban benar dijumlahkan menjadi **Poin Rank** (tersimpan permanen).

| Pet | Kelangkaan | Poin Rank |
|---|---|---|
| Bit si Slime | Biasa | Gratis |
| Kucing Kabel | Biasa | 300 |
| Anjing Router | Langka | 800 |
| Burung WiFi (terbang) | Langka | 1.500 |
| Robot Server (terbang) | Epik | 2.500 |
| Naga Firewall (terbang, berapi) | Epik | 4.000 |
| Unicorn Cloud (berkilau) | Legendaris | 6.000 |
| Phoenix Fiber Optik (berapi) | Legendaris | 9.000 |
| Galaksi Internet | **Mitos** | 13.000 |

- Pet **mengikuti** siswa ke mana-mana dan terlihat oleh semua pemain.
- Menu **🐾 Pet**: koleksi pet; pet yang masih terkunci tampil sebagai **siluet misterius**.
- Saat Poin Rank cukup, muncul jendela **"PET BARU TERBUKA!"** dan pet langsung dipakai.
- Semua pet dipamerkan di **Taman Pet** lengkap dengan syaratnya, supaya siswa termotivasi.
- Gelar: Kabel Pemula → Hub Junior → Switch Cekatan → Router Hebat → Server Master → Legenda Internet.

### 🌳 Dunia yang Nyaman
Siang cerah dengan awan, **taman berumput** dengan pohon (ada pohon sakura), bunga, bangku, lampu taman,
**air mancur** dengan globe internet, **kolam**, bukit, **Zona Materi** berupa kios-kios papan materi,
**Taman Pet**, podium juara, dan **Lintasan Firewall** yang melayang di langit.

### 📚 Materi & Bank Soal
- **86 soal** pilihan ganda & benar/salah, **24 soal isian**, dan **20 kata** teka-teki Caesar Cipher (diacak tiap ronde).
- 6 topik: Konsep Jaringan, Topologi, Perangkat Jaringan, Internet & Cara Kerjanya, Koneksi Kabel & Nirkabel, Keamanan & Proteksi Data.
- **Rapor pribadi** di akhir ronde: nilai, topik terkuat, topik yang perlu dipelajari lagi (dengan tombol langsung ke materinya).

---

## 🚀 Cara Memasang (tanpa coding)

1. Unduh file **`NetQuest-KuisJaringan.rbxlx`** dari repository ini.
2. Buka **Roblox Studio** → **File → Open from File…** → pilih file tersebut.
3. Tekan **▶ Play** (F5). Seluruh dunia **dibangun otomatis** oleh script (butuh beberapa detik).
   *(Sebelum di-Play, dunia memang kosong dan hanya ada papan petunjuk. Itu normal.)*
4. Isi formulir pendaftaran, lalu kuis dimulai otomatis setelah jeda 30 detik.
5. Untuk dimainkan siswa: **File → Publish to Roblox**, lalu atur akses di **Game Settings → Permissions**.

**Agar data siswa, Poin Rank & pet tersimpan permanen:** setelah publish, buka **Game Settings → Security →
aktifkan "Enable Studio Access to API Services"**. Tanpa ini game tetap berjalan, hanya data hilang saat keluar.

> 💡 Uji dengan banyak pemain: tab **Test → Clients and Servers → pilih 2-3 Players → Start**.
> Di Studio semua pemain dianggap guru; untuk ikut menjawab, tetap isi formulir pendaftaran.

### Untuk developer: Rojo
```bash
rojo serve                                   # sinkron langsung ke Studio dengan plugin Rojo
rojo build -o NetQuest-KuisJaringan.rbxlx    # membangun ulang file place
```

---

## 🎓 Panduan Guru

### Siapa yang menjadi guru?
- **Pemilik game** otomatis menjadi guru.
- Guru lain: isi `Config.TeacherUserIds` (ID akun) atau `Config.TeacherNames` (username) di `ReplicatedStorage > QuizShared > Config`.
- Game milik **Grup**: anggota dengan rank ≥ `Config.GroupTeacherMinRank` (default 254).

### Panel Guru (tombol 🎓 di kiri layar)
| Tombol | Fungsi |
|---|---|
| **Mode** | Bergiliran / Lari & Pilih / Kuis Kilat / Lintasan Firewall / Pecahkan Sandi |
| **Topik** | Campuran atau per bab |
| **Jumlah soal / Waktu per soal** | 5–30 soal, 5–60 detik |
| **Mulai otomatis ON/OFF** | OFF = kuis hanya mulai saat guru menekan Mulai |
| **▶ Mulai / ⏩ Kunci Jawaban / ⏹ Hentikan** | Mengendalikan jalannya ronde (Kunci juga mengakhiri balapan Firewall) |
| **📋 Daftar Siswa & Nilai** | Tabel siswa online: kelas, absen, nama, benar/soal, nilai (0-100), Poin Rank |
| **🖨 Cetak Rekap** | Mencetak rekap nilai lengkap ke **Developer Console (F9) → Server** untuk disalin ke Excel |

Rekap nilai juga otomatis tercetak di Output setiap akhir ronde, dengan format:
`Kelas | Absen | Nama | Benar/Soal | Nilai | Poin Sesi | Poin Rank`.

> Catatan: nama yang tampil ke pemain lain melewati **filter teks Roblox** (aturan wajib Roblox),
> jadi kadang sebagian nama bisa berubah menjadi `###`. Nama asli tetap tercatat di rekap Output.

### Saran alur di kelas (± 40 menit)
1. **5 menit**: matikan *Mulai otomatis*, siswa mendaftar lalu menjelajah **Zona Materi** & **Taman Pet**.
2. **10 menit**: ronde 🏃 Lari & Pilih untuk topik yang baru dipelajari.
3. **10 menit**: ronde 🧱 Lintasan Firewall atau ⚡ Kuis Kilat (mode Campuran).
4. **10 menit**: ronde 🔐 Pecahkan Sandi untuk menguatkan materi enkripsi & istilah.
5. **5 menit**: buka **📋 Daftar Siswa**, bahas soal yang banyak salah, minta siswa melihat rapor pribadinya.

---

## ✏️ Menambah / Mengubah Soal (`QuizShared > Questions`)

**Jawaban yang benar selalu ditulis PERTAMA**; urutan pilihan diacak otomatis.

```lua
-- Pilihan ganda (mode Lari & Pilih, Kuis Kilat, Lintasan Firewall)
{ topik = "perangkat", lv = 1, q = "Perangkat yang memancarkan WiFi adalah...",
	c = { "Access Point", "Monitor", "Printer", "Keyboard" },
	e = "Access Point memancarkan sinyal WiFi agar perangkat bisa terhubung tanpa kabel." },

-- Benar / Salah
{ topik = "keamanan", lv = 1, bs = true, q = "Password sebaiknya dibagikan ke teman dekat.", jawab = false,
	e = "Salah! Password bersifat rahasia." },

-- Isian (mode Pecahkan Sandi), di bagian Questions.Isian
{ topik = "internet", lv = 1, q = "Sistem penerjemah nama domain disingkat ...", jawab = { "DNS" },
	e = "DNS = Domain Name System." },

-- Kata teka-teki Caesar Cipher, di bagian Questions.CipherWords (huruf A-Z saja)
{ kata = "ROUTER", topik = "perangkat", petunjuk = "perangkat pemilih rute data" },
```

- `topik`: `konsep`, `topologi`, `perangkat`, `internet`, `koneksi`, `keamanan`
- `lv`: 1 = mudah, 2 = sedang, 3 = sulit
- `e`: penjelasan setelah jawaban diungkap. **Selalu isi**, karena bagian inilah yang membuat siswa belajar.

## ⚙️ Pengaturan Lain
- `QuizShared > Config`: waktu tiap mode, poin & bonus, jumlah gerbang Firewall, pertanyaan kelas pada pendaftaran,
  nama & batas gelar, suara, waktu langit. Setiap baris diberi keterangan bahasa Indonesia.
- `QuizShared > PetCatalog`: nama pet & syarat Poin Rank.
- `QuizShared > Materi`: isi papan Zona Materi.
- Musik latar: cari audio di **Toolbox → Audio**, salin ID-nya, isi `Config.MusicId = "rbxassetid://ID"`.

## 🎨 Menghias Dunia Sendiri
1. **View → Command Bar**, jalankan:
   ```lua
   require(game.ServerScriptService.QuizServer.MapBuilder).Build()
   ```
2. Folder **Workspace > ArenaKuis** dan terrain akan muncul. Tambahkan hiasan sesukamu lalu simpan.
3. Jangan menghapus atau mengganti nama bagian penting: `KotakJawaban`, `LubangData`, `Layar`, `Podium`,
   `LintasanFirewall`. Jika ada yang hilang, dunia otomatis dibangun ulang saat Play.

---

## 🗂️ Struktur Proyek

```
default.project.json         # proyek Rojo
NetQuest-KuisJaringan.rbxlx  # file place siap dibuka di Roblox Studio
src/
├── shared/  → ReplicatedStorage.QuizShared
│   ├── Config.lua       # semua pengaturan game
│   ├── Questions.lua    # bank soal PG/BS/isian + Caesar Cipher
│   ├── Materi.lua       # ringkasan materi Zona Materi
│   └── PetCatalog.lua   # daftar pet + pembuat model pet
├── server/  → ServerScriptService.QuizServer (Script)
│   ├── init.server.lua  # alur ronde, panel guru, hadiah pet, rekap
│   ├── Core.lua         # state bersama & perhitungan skor
│   ├── Roster.lua       # pendaftaran siswa, papan nama, rekap nilai
│   ├── MapBuilder.lua   # pembangun dunia otomatis
│   ├── PlayerData.lua   # penyimpanan data (DataStore)
│   └── Modes/           # Kotak (Lari & Pilih), Kilat, Firewall, Sandi
└── client/  → StarterPlayerScripts.QuizClient (LocalScript)
    ├── init.client.lua  # tampilan layar semua mode, panel guru
    ├── Registration.lua # formulir pendaftaran
    ├── Pets.lua         # pet pengikut, koleksi pet, jendela pet baru
    └── Ui.lua           # fungsi bantu UI
```

Kurikulum acuan: Capaian Pembelajaran Informatika Fase D, elemen Jaringan Komputer dan Internet (JKI).
