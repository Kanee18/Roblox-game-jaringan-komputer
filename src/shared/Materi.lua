--[[
	RINGKASAN MATERI untuk papan "Zona Materi" di lobi.
	Siswa bisa membaca papan ini saat jeda sebelum kuis dimulai.
	Setiap topik: judul + daftar poin singkat (usahakan maksimal 7 poin agar terbaca).
]]

return {
	konsep = {
		"Jaringan komputer = 2 perangkat atau lebih yang saling terhubung untuk berbagi data dan sumber daya.",
		"Manfaat: berbagi file, printer, dan koneksi internet, serta berkomunikasi (chat, email, video call).",
		"PAN (Personal Area Network): jangkauan sangat dekat ±10 m, contoh HP ke earphone Bluetooth.",
		"LAN (Local Area Network): dalam satu ruangan/gedung, contoh lab komputer sekolah.",
		"MAN (Metropolitan Area Network): mencakup satu kota.",
		"WAN (Wide Area Network): antarkota, antarnegara, bahkan antarbenua. Internet adalah WAN terbesar.",
		"Client-Server: ada komputer pusat (server) yang melayani. Peer-to-Peer: semua komputer setara.",
	},
	topologi = {
		"Topologi = bentuk atau susunan cara perangkat dihubungkan dalam jaringan.",
		"BUS: semua komputer di satu kabel utama (backbone). Kabel utama putus = jaringan mati.",
		"STAR (bintang): semua terhubung ke pusat (switch/hub). Paling banyak dipakai.",
		"RING (cincin): komputer membentuk lingkaran, data berputar dari satu komputer ke komputer berikutnya.",
		"MESH: setiap komputer terhubung ke semua komputer lain. Paling andal tapi butuh banyak kabel.",
		"Rumus kabel mesh: n x (n - 1) / 2. Contoh 4 komputer = 4 x 3 / 2 = 6 kabel.",
		"TREE (pohon): gabungan beberapa topologi star yang bertingkat seperti cabang pohon.",
	},
	perangkat = {
		"NIC (Network Interface Card): kartu jaringan di komputer; setiap NIC punya MAC Address unik.",
		"Kabel UTP + konektor RJ-45: kabel jaringan yang paling umum di LAN.",
		"HUB: meneruskan data ke SEMUA komputer yang terhubung.",
		"SWITCH: lebih pintar dari hub, mengirim data HANYA ke komputer tujuan.",
		"ROUTER: menghubungkan jaringan yang berbeda dan memilih jalur (rute) terbaik untuk data.",
		"MODEM: Modulator-Demodulator, mengubah sinyal digital <-> analog agar bisa terhubung ke internet.",
		"ACCESS POINT: memancarkan sinyal WiFi. REPEATER: memperkuat sinyal agar jangkauan lebih jauh.",
	},
	internet = {
		"Internet = Interconnected Network, jaringan komputer global yang menghubungkan seluruh dunia.",
		"Berawal dari ARPANET (1969), proyek Departemen Pertahanan Amerika Serikat.",
		"ISP (Internet Service Provider) = perusahaan penyedia layanan akses internet.",
		"IP Address = alamat unik perangkat di jaringan. Contoh IPv4: 192.168.1.10 (4 angka 0-255).",
		"DNS = penerjemah nama domain (www.contoh.sch.id) menjadi IP Address, seperti buku telepon.",
		"Data dikirim dalam potongan kecil bernama PAKET. Aturan komunikasinya disebut PROTOKOL (TCP/IP).",
		"HTTPS = HTTP yang aman (terenkripsi), ditandai ikon gembok. Browser = aplikasi untuk membuka web.",
	},
	koneksi = {
		"KABEL: UTP (umum di LAN), koaksial, dan serat optik (fiber optic).",
		"Fiber optic mengirim data dengan CAHAYA: sangat cepat dan jarak jauh, dipakai kabel bawah laut.",
		"WiFi: nirkabel memakai gelombang radio dari router/access point. Nama jaringan WiFi = SSID.",
		"Bluetooth: nirkabel jarak dekat (±10 m), untuk earphone, speaker, atau kirim file.",
		"Seluler (4G/5G): internet dari menara BTS operator. Hotspot/tethering = HP membagi internet.",
		"Kabel: stabil & cepat, tapi kurang fleksibel. Nirkabel: fleksibel, tapi bisa terganggu jarak/penghalang.",
		"Kecepatan internet diukur dalam bps (bit per second), misalnya Mbps (megabit per detik).",
	},
	keamanan = {
		"Data pribadi (NIK, alamat, tanggal lahir, password, kode OTP) jangan dibagikan sembarangan!",
		"Password kuat: minimal 8 karakter, campuran huruf besar, kecil, angka, dan simbol.",
		"ENKRIPSI: mengubah data menjadi kode acak agar tak terbaca tanpa kunci. DEKRIPSI = kebalikannya.",
		"Caesar Cipher: enkripsi dengan menggeser huruf. Geser 1: A->B, B->C, jadi ABC -> BCD.",
		"PHISHING: penipuan lewat pesan/link palsu untuk mencuri data. MALWARE: virus, worm, trojan, ransomware.",
		"Aktifkan verifikasi 2 langkah (2FA). Hati-hati login akun penting di WiFi publik.",
		"Cloud storage (contoh Google Drive) = simpan data di internet, bisa diakses dari mana saja.",
	},
}
