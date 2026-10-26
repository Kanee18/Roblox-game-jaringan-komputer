# NET QUEST — Kuis Jaringan Komputer & Internet (Roblox)

Game kuis Roblox untuk **Informatika Kelas 7 SMP**, elemen **Jaringan Komputer dan Internet**.
Siswa mendaftar dengan **nama & nomor absen**, lalu memainkan **Petualangan 4 Game** berturut-turut di sebuah
pulau yang tertata rapi. Poin keempat game **dijumlahkan menjadi POIN TOTAL**, dan semua poin menjadi
**Poin Rank** permanen untuk membuka **gelar** dan **pet**.

---

## Fitur Utama

### Pendaftaran siswa
- Saat masuk, siswa **wajib mengisi Nama Lengkap, Nomor Absen, dan Kelas** sebelum bisa bergerak & ikut kuis.
- Nomor absen yang sama di kelas yang sama ditolak (mencegah salah ketik / dobel).
- Nama tampil di atas kepala (`05. Budi Santoso (7A)` + gelar), jadi guru mudah mengenali siswa.
- Data tersimpan; saat masuk lagi formulir sudah terisi otomatis.
- Guru bisa menekan **"Saya guru, lewati pendaftaran"**.

### Petualangan 4 Game (mode bawaan)
Keempat game dimainkan **berurutan dalam satu sesi**. Tiap game punya arena sendiri di pulau.

| # | Game | Arena | Cara main |
|---|---|---|---|
| 1 | **Lari & Pilih** | Arena utara | Lari & berdiri di kotak jawaban A/B/C/D. Kotak salah **jatuh ke kolam** |
| 2 | **Kuis Kilat** | Panggung timur | Tekan tombol jawaban di layar secepat mungkin. Jawaban **tidak bisa diganti** |
| 3 | **Lintasan Firewall** | Menara selatan (lintasan di langit) | **Balapan obby**: tiap gerbang ada soal & 4 pintu. Pintu salah = jatuh! |
| 4 | **Pecahkan Sandi** | Lab barat | **Ketik** jawaban isian & pecahkan **Caesar Cipher** (`SPVUFS` geser 1 = `ROUTER`) |

**Sistem poin**
- Setiap game: 5 soal (Lintasan Firewall: 6 gerbang). Benar lebih cepat = poin lebih besar, plus bonus streak.
- **POIN TOTAL = poin game 1 + 2 + 3 + 4**. Papan peringkat di alun-alun diperbarui langsung.
- **Bonus tamat +200** untuk siswa yang ikut menjawab di **keempat** game (yang diam saja tidak dapat).
- Di antara game muncul layar **Hasil Game** (peringkat game itu + peringkat total sementara) selama 10 detik.
- Di akhir: podium juara, dan **Rapor**: peringkat, poin total, nilai 0-100, poin tiap game,
  topik terkuat, topik yang perlu dipelajari lagi (dengan tombol langsung ke materinya), gelar, dan pet berikutnya.

Semua game punya **penjelasan materi setelah setiap soal**, soal **mudah ke sulit**, **SOAL BOS** (poin x2),
**streak**, dan **bantuan** (50:50 atau petunjuk huruf) yang didapat jika benar 3x berturut-turut.
Guru juga bisa memilih satu game saja lewat Panel Guru.

### Hadiah: Poin Rank, Gelar & Pet
Poin total setiap sesi ditambahkan ke **Poin Rank** (tersimpan permanen).

| Pet | Kelangkaan | Poin Rank |
|---|---|---|
| Bit si Slime | Biasa | Gratis |
| Kucing Kabel | Biasa | 600 |
| Anjing Router | Langka | 1.500 |
| Burung WiFi (terbang) | Langka | 3.000 |
| Robot Server (terbang) | Epik | 5.000 |
| Naga Firewall (terbang) | Epik | 8.000 |
| Unicorn Cloud (terbang) | Legendaris | 12.000 |
| Phoenix Fiber Optik (terbang) | Legendaris | 17.000 |
| Galaksi Internet (terbang) | **Mitos** | 25.000 |

- Gelar: Kabel Pemula (0) → Hub Junior (1.000) → Switch Cekatan (3.000) → Router Hebat (6.000)
  → Server Master (10.000) → Legenda Internet (16.000).
- Semua pet bergaya **chibi** yang seragam (badan bulat, mata besar, ciri khas masing-masing) dan **mengikuti** siswa.
- Menu **PET**: koleksi pet; pet yang masih terkunci tampil sebagai **siluet**.
- Saat Poin Rank cukup, muncul jendela **"Pet Baru Terbuka!"** dengan tombol **Pakai Sekarang**.
- Semua pet dipamerkan di **Taman Pet** lengkap dengan syaratnya.

### Dunia: Pulau NET QUEST
```
                 [1] ARENA LARI & PILIH (utara)
                          |
  [4] LAB SANDI ----- ALUN-ALUN ----- [2] PANGGUNG KUIS KILAT (timur)
   + Jalur Zona Materi    |   (spawn, air mancur, papan peringkat, podium)
   + TAMAN PET            |
                 [3] MENARA LINTASAN FIREWALL (selatan)
```
- Pulau berumput dengan pantai, jalan setapak yang menghubungkan setiap zona, pohon, bangku, lampu taman.
- **Papan peringkat** berdiri di alun-alun (bukan di bawah tanah lagi) dan menampilkan POIN TOTAL secara langsung.
- Saat game dimulai, semua siswa dipindahkan otomatis ke arena game tersebut.

### Tampilan (UI)
- Desain kartu yang konsisten: kartu putih membulat, font **Builder Sans** (font resmi Roblox) + **Fredoka** untuk angka.
- Kiri: kartu **POIN TOTAL** + Poin Rank + kemajuan menuju pet berikutnya, tombol Bantuan, PET, MATERI, PANDUAN, GURU.
- Atas: kartu soal dengan nama game, topik, nomor soal, dan pengatur waktu.
- Otomatis mengecil di layar HP/tablet. Daftar pemain bawaan Roblox disembunyikan selama game agar tidak menutupi soal.

### Materi & bank soal
- **86 soal** pilihan ganda & benar/salah, **24 soal isian**, dan **20 kata** teka-teki Caesar Cipher (diacak tiap sesi).
- 6 topik: Konsep Jaringan, Topologi, Perangkat Jaringan, Internet & Cara Kerjanya, Koneksi Kabel & Nirkabel,
  Keamanan & Proteksi Data. Ringkasan materinya bisa dibaca di menu **MATERI** dan papan **Zona Materi**.

---

## Cara Memasang (tanpa coding)

1. Unduh file **`NetQuest-KuisJaringan.rbxlx`** dari repository ini.
2. Buka **Roblox Studio** → **File → Open from File…** → pilih file tersebut.
3. Tekan **Play** (F5). Seluruh pulau **dibangun otomatis** oleh script (butuh beberapa detik).
   *(Sebelum di-Play, dunia memang kosong. Itu normal.)*
4. Isi formulir pendaftaran, lalu Petualangan dimulai otomatis setelah jeda 30 detik.
5. Untuk dimainkan siswa: **File → Publish to Roblox**, lalu atur akses di **Game Settings → Permissions**.

**Agar data siswa, Poin Rank & pet tersimpan permanen:** setelah publish, buka **Game Settings → Security →
aktifkan "Enable Studio Access to API Services"**. Tanpa ini game tetap berjalan, hanya data hilang saat keluar.

> Uji dengan banyak pemain: tab **Test → Clients and Servers → pilih 2-3 Players → Start**.
> Di Studio semua pemain dianggap guru; untuk ikut menjawab, tetap isi formulir pendaftaran.

### Memakai aset gratis dari Toolbox (opsional)
Dunia bawaan sudah lengkap, tetapi hiasannya bisa diganti dengan model gratis dari **Toolbox**:

1. Buat folder **`AsetDunia`** di **ServerStorage**, lalu masukkan model dengan nama persis:
   `Pohon`, `PohonKelapa`, `Bangku`, `Lampu`, `Batu`, `Semak`. Model itu akan dipakai di seluruh pulau.
2. Untuk pet: buat folder **`AsetPet`** di **ReplicatedStorage**, isi model dengan nama id pet:
   `slime`, `cat`, `dog`, `bird`, `robot`, `dragon`, `unicorn`, `phoenix`, `galaxy`.
3. Hapus folder **Workspace > ArenaKuis** (jika ada), lalu tekan Play agar pulau dibangun ulang dengan aset baru.

> **Penting:** model Toolbox kadang berisi script tersembunyi yang berbahaya. Setelah memasukkan model,
> cari kata `Script` di Explorer dan hapus semua script di dalam model hiasan/pet.

### Untuk developer: Rojo
```bash
rojo serve                                   # sinkron langsung ke Studio dengan plugin Rojo
rojo build -o NetQuest-KuisJaringan.rbxlx    # membangun ulang file place
```

### Memakai Roblox Studio MCP bersama Claude Code
Server MCP Roblox Studio berjalan di komputer yang membuka Studio, jadi hanya bisa dipakai oleh Claude Code
yang juga berjalan **di komputer itu**: buka terminal di folder repository ini, jalankan `claude`
(atau `claude remote-control` agar bisa diakses dari aplikasi Claude), lalu pastikan Studio terbuka
dengan plugin MCP aktif. Sesi Claude Code di cloud tidak bisa menjangkau Studio di komputermu.

---

## Panduan Guru

### Siapa yang menjadi guru?
- **Pemilik game** otomatis menjadi guru.
- Guru lain: isi `Config.TeacherUserIds` (ID akun) atau `Config.TeacherNames` (username) di `ReplicatedStorage > QuizShared > Config`.
- Game milik **Grup**: anggota dengan rank ≥ `Config.GroupTeacherMinRank` (default 254).

### Panel Guru (tombol GURU di kiri layar)
| Tombol | Fungsi |
|---|---|
| **Mode** | Petualangan 4 Game / Lari & Pilih / Kuis Kilat / Lintasan Firewall / Pecahkan Sandi |
| **Topik** | Campuran atau per bab |
| **Soal/game, Waktu/soal** | 3–30 soal per game, 5–60 detik per soal |
| **Mulai otomatis ON/OFF** | OFF = sesi hanya mulai saat guru menekan Mulai |
| **Mulai / Kunci Jawaban / Hentikan** | Mengendalikan jalannya sesi (Kunci juga mengakhiri balapan Firewall) |
| **Daftar Siswa & Nilai** | Tabel siswa online: kelas, absen, nama, benar/soal, nilai (0-100), Poin Rank |
| **Cetak Rekap** | Mencetak rekap nilai lengkap ke **Developer Console (F9) → Server** untuk disalin ke Excel |

Rekap nilai juga otomatis tercetak di Output setiap akhir sesi, dengan format:
`Kelas | Absen | Nama | Benar/Soal | Nilai | Poin Sesi | Poin Rank`.

> Catatan: nama yang tampil ke pemain lain melewati **filter teks Roblox** (aturan wajib Roblox),
> jadi kadang sebagian nama bisa berubah menjadi `###`. Nama asli tetap tercatat di rekap Output.

### Saran alur di kelas (± 40 menit)
1. **5 menit**: matikan *Mulai otomatis*, siswa mendaftar lalu menjelajah **Zona Materi** & **Taman Pet**.
2. **25 menit**: tekan **Mulai** untuk satu sesi **Petualangan 4 Game** (topik Campuran atau bab yang baru dipelajari).
3. **10 menit**: buka **Daftar Siswa & Nilai**, bahas soal yang banyak salah, minta siswa membaca rapornya.

---

## Menambah / Mengubah Soal (`QuizShared > Questions`)

**Jawaban yang benar selalu ditulis PERTAMA**; urutan pilihan diacak otomatis.

```lua
-- Pilihan ganda (Lari & Pilih, Kuis Kilat, Lintasan Firewall)
{ topik = "perangkat", lv = 1, q = "Perangkat yang memancarkan WiFi adalah...",
	c = { "Access Point", "Monitor", "Printer", "Keyboard" },
	e = "Access Point memancarkan sinyal WiFi agar perangkat bisa terhubung tanpa kabel." },

-- Benar / Salah
{ topik = "keamanan", lv = 1, bs = true, q = "Password sebaiknya dibagikan ke teman dekat.", jawab = false,
	e = "Salah! Password bersifat rahasia." },

-- Isian (Pecahkan Sandi), di bagian Questions.Isian
{ topik = "internet", lv = 1, q = "Sistem penerjemah nama domain disingkat ...", jawab = { "DNS" },
	e = "DNS = Domain Name System." },

-- Kata teka-teki Caesar Cipher, di bagian Questions.CipherWords (huruf A-Z saja)
{ kata = "ROUTER", topik = "perangkat", petunjuk = "perangkat pemilih rute data" },
```

- `topik`: `konsep`, `topologi`, `perangkat`, `internet`, `koneksi`, `keamanan`
- `lv`: 1 = mudah, 2 = sedang, 3 = sulit
- `e`: penjelasan setelah jawaban diungkap. **Selalu isi**, karena bagian inilah yang membuat siswa belajar.

## Pengaturan Lain
- `QuizShared > Config`: urutan game Petualangan (`AdventureOrder`), bonus tamat (`CompletionBonus`),
  jeda antar-game (`GameBreakTime`), waktu tiap mode, poin & bonus, jumlah gerbang Firewall,
  pertanyaan kelas pada pendaftaran, nama & batas gelar, suara. Setiap baris diberi keterangan bahasa Indonesia.
- `QuizShared > PetCatalog`: nama pet & syarat Poin Rank.
- `QuizShared > Materi`: isi menu Materi & papan Zona Materi.
- Musik latar: cari audio di **Toolbox → Audio**, salin ID-nya, isi `Config.MusicId = "rbxassetid://ID"`.

## Menghias Pulau Sendiri
1. **View → Command Bar**, jalankan:
   ```lua
   require(game.ServerScriptService.QuizServer.MapBuilder).Build()
   ```
2. Folder **Workspace > ArenaKuis** dan terrain pulau akan muncul. Tambahkan hiasan sesukamu lalu simpan.
3. Jangan menghapus atau mengganti nama bagian penting: `KotakJawaban`, `KolamData`, `Podium`, `PanggungKilat`,
   `LintasanFirewall`. Jika ada yang hilang, pulau otomatis dibangun ulang saat Play.

---

## Struktur Proyek

```
default.project.json         # proyek Rojo
NetQuest-KuisJaringan.rbxlx  # file place siap dibuka di Roblox Studio
src/
├── shared/  → ReplicatedStorage.QuizShared
│   ├── Config.lua       # semua pengaturan game
│   ├── Questions.lua    # bank soal PG/BS/isian + Caesar Cipher
│   ├── Materi.lua       # ringkasan materi
│   └── PetCatalog.lua   # daftar pet + pembuat model pet chibi
├── server/  → ServerScriptService.QuizServer (Script)
│   ├── init.server.lua  # alur Petualangan 4 Game, poin total, panel guru, hadiah, rekap
│   ├── Core.lua         # state bersama & perhitungan skor
│   ├── Roster.lua       # pendaftaran siswa, papan nama, rekap nilai
│   ├── MapBuilder.lua   # pembangun pulau otomatis
│   ├── PlayerData.lua   # penyimpanan data (DataStore)
│   └── Modes/           # Kotak (Lari & Pilih), Kilat, Firewall, Sandi
└── client/  → StarterPlayerScripts.QuizClient (LocalScript)
    ├── init.client.lua  # tampilan layar semua game, hasil, panel guru
    ├── Registration.lua # formulir pendaftaran
    ├── Pets.lua         # pet pengikut, koleksi pet, jendela pet baru
    └── Ui.lua           # komponen UI (kartu, tombol, chip, bilah)
```

Kurikulum acuan: Capaian Pembelajaran Informatika Fase D, elemen Jaringan Komputer dan Internet (JKI).
