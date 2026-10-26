--[[
	BANK SOAL - Jaringan Komputer & Internet (Informatika Kelas 7 SMP)

	CARA MENAMBAH SOAL:
	1) Pilihan ganda (4 pilihan):
	   { topik = "konsep", lv = 1, q = "Pertanyaan?", c = { "JAWABAN BENAR", "salah", "salah", "salah" }, e = "Penjelasan." },
	   -> Jawaban BENAR selalu ditulis PERTAMA. Urutan pilihan diacak otomatis di dalam game.
	2) Benar / Salah:
	   { topik = "konsep", lv = 1, bs = true, q = "Pernyataan.", jawab = true, e = "Penjelasan." },
	   -> jawab = true jika pernyataan BENAR, false jika SALAH.

	topik : konsep / topologi / perangkat / internet / koneksi / keamanan
	lv    : tingkat kesulitan 1 (mudah), 2 (sedang), 3 (sulit). Soal diurutkan dari mudah ke sulit.
	e     : penjelasan singkat yang muncul setelah jawaban diungkap (penting untuk belajar!)
]]

local Questions = {}

Questions.List = {
	---------------------------------------------------------------
	-- KONSEP JARINGAN KOMPUTER
	---------------------------------------------------------------
	{ topik = "konsep", lv = 1, q = "Apa yang dimaksud dengan jaringan komputer?",
		c = { "Dua atau lebih perangkat yang terhubung untuk berbagi data", "Satu komputer yang memiliki banyak aplikasi", "Kumpulan kabel listrik di rumah", "Program untuk mengetik dokumen" },
		e = "Jaringan komputer adalah dua atau lebih perangkat yang saling terhubung sehingga bisa berbagi data dan sumber daya." },
	{ topik = "konsep", lv = 1, q = "Jaringan komputer di dalam satu lab komputer sekolah termasuk jenis...",
		c = { "LAN", "WAN", "MAN", "Internet" },
		e = "LAN (Local Area Network) mencakup area kecil seperti satu ruangan, gedung, atau sekolah." },
	{ topik = "konsep", lv = 1, q = "Menghubungkan HP ke earphone Bluetooth adalah contoh jaringan...",
		c = { "PAN", "LAN", "MAN", "WAN" },
		e = "PAN (Personal Area Network) adalah jaringan pribadi jarak sangat dekat, sekitar 10 meter." },
	{ topik = "konsep", lv = 2, q = "Jaringan yang mencakup satu kota, misalnya jaringan CCTV milik pemerintah kota, disebut...",
		c = { "MAN", "PAN", "LAN", "Peer-to-Peer" },
		e = "MAN (Metropolitan Area Network) mencakup wilayah satu kota." },
	{ topik = "konsep", lv = 2, q = "Jaringan dengan jangkauan paling LUAS adalah...",
		c = { "WAN", "MAN", "LAN", "PAN" },
		e = "Urutan dari yang paling sempit: PAN < LAN < MAN < WAN. WAN bisa mencakup antarnegara." },
	{ topik = "konsep", lv = 1, bs = true, q = "Internet adalah contoh jaringan WAN yang paling besar di dunia.", jawab = true,
		e = "Benar! Internet menghubungkan jaringan di seluruh dunia, sehingga termasuk WAN terbesar." },
	{ topik = "konsep", lv = 1, bs = true, q = "Salah satu manfaat jaringan komputer adalah satu printer bisa dipakai bersama oleh banyak komputer.", jawab = true,
		e = "Benar! Berbagi printer, file, dan koneksi internet adalah manfaat utama jaringan komputer." },
	{ topik = "konsep", lv = 2, q = "Jaringan di mana semua komputer memiliki kedudukan setara (tanpa server pusat) disebut...",
		c = { "Peer-to-Peer", "Client-Server", "Topologi Bus", "Router" },
		e = "Pada Peer-to-Peer semua komputer setara. Pada Client-Server ada server pusat yang melayani client." },
	{ topik = "konsep", lv = 2, bs = true, q = "Pada jaringan Client-Server, komputer yang melayani permintaan disebut client.", jawab = false,
		e = "Salah! Komputer yang MELAYANI disebut SERVER. Client adalah komputer yang MEMINTA layanan." },
	{ topik = "konsep", lv = 3, q = "Bank yang menghubungkan kantor cabangnya di Jakarta, Medan, dan Makassar menggunakan jaringan...",
		c = { "WAN", "LAN", "PAN", "MAN" },
		e = "Karena menghubungkan beberapa kota yang berjauhan (antarpulau), jaringannya adalah WAN." },
	{ topik = "konsep", lv = 3, q = "Berikut ini yang BUKAN manfaat jaringan komputer adalah...",
		c = { "Membuat komputer kebal dari virus", "Berbagi file dengan cepat", "Berbagi koneksi internet", "Berkomunikasi lewat email" },
		e = "Jaringan justru bisa menjadi jalan masuk virus. Karena itu keamanan jaringan tetap harus dijaga." },

	---------------------------------------------------------------
	-- TOPOLOGI JARINGAN
	---------------------------------------------------------------
	{ topik = "topologi", lv = 1, q = "Bentuk atau susunan hubungan antar perangkat dalam jaringan disebut...",
		c = { "Topologi", "Protokol", "Bandwidth", "Domain" },
		e = "Topologi adalah bentuk/susunan cara perangkat-perangkat dihubungkan dalam jaringan." },
	{ topik = "topologi", lv = 1, q = "Topologi di mana semua komputer terhubung ke satu titik pusat (switch/hub) adalah...",
		c = { "Star", "Bus", "Ring", "Mesh" },
		e = "Topologi Star (bintang) memiliki pusat berupa switch atau hub, bentuknya seperti bintang." },
	{ topik = "topologi", lv = 1, q = "Topologi yang memakai satu kabel utama (backbone) untuk semua komputer adalah...",
		c = { "Bus", "Star", "Tree", "Mesh" },
		e = "Topologi Bus memakai satu kabel utama. Ujung kabelnya dipasang terminator." },
	{ topik = "topologi", lv = 1, q = "Topologi yang bentuknya melingkar seperti cincin adalah...",
		c = { "Ring", "Star", "Bus", "Tree" },
		e = "Pada topologi Ring, komputer membentuk lingkaran dan data berputar dari satu komputer ke komputer berikutnya." },
	{ topik = "topologi", lv = 2, q = "Pada topologi Star, apa yang terjadi jika switch pusatnya rusak?",
		c = { "Seluruh jaringan terganggu", "Hanya satu komputer yang terganggu", "Jaringan menjadi lebih cepat", "Tidak terjadi apa-apa" },
		e = "Switch/hub adalah pusat topologi Star. Jika pusatnya rusak, semua komputer tidak bisa saling terhubung." },
	{ topik = "topologi", lv = 2, bs = true, q = "Pada topologi Star, jika satu kabel komputer putus, maka seluruh jaringan ikut mati.", jawab = false,
		e = "Salah! Pada topologi Star, kabel yang putus hanya mengganggu satu komputer itu saja." },
	{ topik = "topologi", lv = 2, bs = true, q = "Pada topologi Bus, jika kabel utama (backbone) putus maka jaringan akan terganggu.", jawab = true,
		e = "Benar! Semua komputer bergantung pada kabel utama, jadi kabel utama putus = jaringan terganggu." },
	{ topik = "topologi", lv = 2, q = "Topologi yang setiap komputernya terhubung langsung ke SEMUA komputer lain adalah...",
		c = { "Mesh", "Star", "Bus", "Ring" },
		e = "Topologi Mesh sangat andal karena banyak jalur cadangan, tetapi membutuhkan banyak kabel." },
	{ topik = "topologi", lv = 2, q = "Topologi gabungan beberapa topologi star yang bertingkat seperti cabang disebut...",
		c = { "Tree", "Ring", "Bus", "Mesh" },
		e = "Topologi Tree (pohon) tersusun bertingkat, cocok untuk gedung dengan banyak lantai/ruangan." },
	{ topik = "topologi", lv = 3, q = "Berapa jumlah kabel yang dibutuhkan untuk menghubungkan 4 komputer dengan topologi Mesh?",
		c = { "6", "4", "8", "12" },
		e = "Rumus Mesh: n x (n - 1) / 2 = 4 x 3 / 2 = 6 kabel." },
	{ topik = "topologi", lv = 3, q = "Berapa kabel yang dibutuhkan untuk menghubungkan 5 komputer dengan topologi Mesh?",
		c = { "10", "5", "20", "25" },
		e = "Rumus Mesh: n x (n - 1) / 2 = 5 x 4 / 2 = 10 kabel." },
	{ topik = "topologi", lv = 3, q = "Kekurangan utama topologi Mesh adalah...",
		c = { "Membutuhkan kabel yang sangat banyak", "Jika satu kabel putus semua mati", "Tidak bisa dipakai berbagi data", "Hanya bisa 2 komputer" },
		e = "Mesh paling andal, tetapi mahal dan rumit karena setiap komputer harus terhubung ke semua komputer lain." },

	---------------------------------------------------------------
	-- PERANGKAT JARINGAN
	---------------------------------------------------------------
	{ topik = "perangkat", lv = 1, q = "Perangkat yang menghubungkan dua jaringan berbeda dan menentukan jalur data adalah...",
		c = { "Router", "Hub", "Mouse", "Speaker" },
		e = "Router menghubungkan jaringan berbeda (misal jaringan rumah ke internet) dan memilih rute terbaik." },
	{ topik = "perangkat", lv = 1, q = "Konektor yang dipasang di ujung kabel UTP adalah...",
		c = { "RJ-45", "USB", "HDMI", "VGA" },
		e = "Kabel UTP menggunakan konektor RJ-45 untuk dipasang ke komputer, switch, atau router." },
	{ topik = "perangkat", lv = 1, q = "Kartu jaringan yang dipasang di komputer agar bisa terhubung ke jaringan disebut...",
		c = { "NIC (Network Interface Card)", "VGA Card", "Sound Card", "RAM" },
		e = "NIC atau LAN Card adalah kartu jaringan. Setiap NIC memiliki alamat fisik unik bernama MAC Address." },
	{ topik = "perangkat", lv = 2, q = "Apa perbedaan SWITCH dengan HUB?",
		c = { "Switch mengirim data hanya ke komputer tujuan", "Switch mengirim data ke semua komputer", "Hub lebih pintar daripada switch", "Switch tidak memakai kabel" },
		e = "Hub meneruskan data ke SEMUA port, sedangkan switch lebih pintar karena hanya mengirim ke port TUJUAN." },
	{ topik = "perangkat", lv = 2, q = "Modem adalah singkatan dari...",
		c = { "Modulator - Demodulator", "Modern Demo", "Mode Memori", "Monitor Demodulasi" },
		e = "Modem = Modulator-Demodulator, mengubah sinyal digital menjadi analog dan sebaliknya." },
	{ topik = "perangkat", lv = 2, q = "Perangkat yang memancarkan sinyal WiFi agar laptop dan HP bisa terhubung tanpa kabel adalah...",
		c = { "Access Point", "Hub", "Printer", "Kabel UTP" },
		e = "Access Point memancarkan sinyal WiFi. Router WiFi di rumah biasanya sudah memiliki fungsi access point." },
	{ topik = "perangkat", lv = 2, bs = true, q = "Repeater berfungsi untuk memperkuat sinyal agar jangkauan jaringan menjadi lebih jauh.", jawab = true,
		e = "Benar! Repeater menerima sinyal yang melemah lalu memancarkannya kembali agar lebih kuat." },
	{ topik = "perangkat", lv = 1, bs = true, q = "Mouse dan keyboard termasuk perangkat jaringan.", jawab = false,
		e = "Salah! Mouse dan keyboard adalah perangkat input. Contoh perangkat jaringan: router, switch, modem, NIC." },
	{ topik = "perangkat", lv = 3, q = "Alamat fisik unik yang tertanam pada setiap kartu jaringan (NIC) disebut...",
		c = { "MAC Address", "IP Address", "URL", "Password" },
		e = "MAC Address adalah alamat fisik dari pabrik. IP Address adalah alamat logis yang bisa berubah." },
	{ topik = "perangkat", lv = 3, q = "Di lab komputer, 30 komputer dihubungkan menjadi satu jaringan LAN. Perangkat pusat yang paling tepat adalah...",
		c = { "Switch", "Modem", "Repeater", "Proyektor" },
		e = "Switch menjadi pusat jaringan LAN (topologi star) dan mengirim data secara efisien ke komputer tujuan." },

	---------------------------------------------------------------
	-- INTERNET & CARA KERJANYA
	---------------------------------------------------------------
	{ topik = "internet", lv = 1, q = "Internet merupakan singkatan dari...",
		c = { "Interconnected Network", "International Network", "Interior Networking", "Intelligent Network" },
		e = "Internet = Interconnected Network, yaitu jaringan-jaringan komputer yang saling terhubung di seluruh dunia." },
	{ topik = "internet", lv = 1, q = "Aplikasi yang digunakan untuk membuka halaman website disebut...",
		c = { "Browser", "Antivirus", "Spreadsheet", "Kalkulator" },
		e = "Browser (contoh: Chrome, Firefox, Edge) adalah aplikasi untuk membuka dan menampilkan halaman web." },
	{ topik = "internet", lv = 1, q = "Perusahaan yang menyediakan layanan akses internet disebut...",
		c = { "ISP (Internet Service Provider)", "DNS", "Browser", "Hacker" },
		e = "ISP adalah penyedia jasa internet. Contohnya penyedia internet rumah dan operator seluler." },
	{ topik = "internet", lv = 2, q = "Internet berawal dari jaringan bernama...",
		c = { "ARPANET", "FACEBOOK", "WIFI-NET", "BLUETOOTH" },
		e = "Internet berawal dari ARPANET (1969), proyek Departemen Pertahanan Amerika Serikat." },
	{ topik = "internet", lv = 2, q = "Alamat unik setiap perangkat yang terhubung ke jaringan/internet disebut...",
		c = { "IP Address", "Email", "Username", "Wallpaper" },
		e = "IP Address adalah alamat unik perangkat, seperti alamat rumah agar data bisa sampai ke tujuan." },
	{ topik = "internet", lv = 2, q = "Manakah penulisan IP Address (IPv4) yang BENAR?",
		c = { "192.168.1.10", "192.168.300.1", "192.168.1", "192,168,1,10" },
		e = "IPv4 terdiri dari 4 angka (masing-masing 0-255) yang dipisah titik. 300 tidak valid karena lebih dari 255." },
	{ topik = "internet", lv = 2, q = "Sistem yang menerjemahkan nama domain (contoh: www.sekolah.sch.id) menjadi IP Address adalah...",
		c = { "DNS", "ISP", "HTML", "USB" },
		e = "DNS (Domain Name System) bekerja seperti buku telepon: mengubah nama domain menjadi IP Address." },
	{ topik = "internet", lv = 2, bs = true, q = "Website yang alamatnya diawali HTTPS lebih aman karena datanya dienkripsi.", jawab = true,
		e = "Benar! Huruf S pada HTTPS berarti Secure. Biasanya ditandai ikon gembok di browser." },
	{ topik = "internet", lv = 2, bs = true, q = "Data di internet dikirim sekaligus dalam satu potongan besar, tidak pernah dipecah.", jawab = false,
		e = "Salah! Data dipecah menjadi potongan kecil bernama PAKET, lalu disusun kembali di komputer tujuan." },
	{ topik = "internet", lv = 3, q = "Aturan atau tata cara komunikasi antar komputer di internet disebut...",
		c = { "Protokol", "Topologi", "Hardware", "Bandwidth" },
		e = "Protokol adalah aturan komunikasi. Protokol utama internet adalah TCP/IP; untuk web dipakai HTTP/HTTPS." },
	{ topik = "internet", lv = 3, q = "Domain .sch.id biasanya digunakan oleh website...",
		c = { "Sekolah", "Pemerintah", "Perusahaan dagang", "Militer" },
		e = ".sch.id = sekolah, .go.id = pemerintah, .ac.id = perguruan tinggi, .co.id = perusahaan." },
	{ topik = "internet", lv = 3, q = "Alamat lengkap sebuah halaman web, misalnya https://www.contoh.sch.id/profil, disebut...",
		c = { "URL", "IP Address", "MAC Address", "SSID" },
		e = "URL (Uniform Resource Locator) adalah alamat lengkap untuk membuka halaman web tertentu." },

	---------------------------------------------------------------
	-- KONEKSI KABEL & NIRKABEL
	---------------------------------------------------------------
	{ topik = "koneksi", lv = 1, q = "Berikut ini yang termasuk koneksi NIRKABEL (tanpa kabel) adalah...",
		c = { "WiFi", "Kabel UTP", "Fiber optic", "Kabel koaksial" },
		e = "Contoh koneksi nirkabel: WiFi, Bluetooth, dan jaringan seluler (4G/5G)." },
	{ topik = "koneksi", lv = 1, q = "Teknologi nirkabel jarak dekat untuk menghubungkan HP ke speaker atau earphone adalah...",
		c = { "Bluetooth", "Fiber optic", "Kabel UTP", "Satelit" },
		e = "Bluetooth adalah koneksi nirkabel jarak dekat, sekitar 10 meter." },
	{ topik = "koneksi", lv = 1, bs = true, q = "Koneksi kabel biasanya lebih stabil dibandingkan koneksi nirkabel.", jawab = true,
		e = "Benar! Kabel tidak mudah terganggu jarak dan penghalang, tetapi kurang fleksibel." },
	{ topik = "koneksi", lv = 2, q = "Kabel jaringan yang mengirimkan data menggunakan CAHAYA adalah...",
		c = { "Fiber optic (serat optik)", "Kabel UTP", "Kabel koaksial", "Kabel listrik" },
		e = "Fiber optic memakai cahaya sehingga sangat cepat dan bisa menjangkau jarak jauh, misalnya kabel bawah laut." },
	{ topik = "koneksi", lv = 2, q = "Nama jaringan WiFi yang muncul saat kita mencari WiFi di HP disebut...",
		c = { "SSID", "URL", "DNS", "RAM" },
		e = "SSID (Service Set Identifier) adalah nama jaringan WiFi." },
	{ topik = "koneksi", lv = 2, q = "Fitur HP yang membagikan koneksi internetnya ke perangkat lain disebut...",
		c = { "Hotspot / Tethering", "Mode Pesawat", "Screenshot", "Senter" },
		e = "Dengan hotspot/tethering, HP berfungsi seperti router WiFi kecil untuk perangkat lain." },
	{ topik = "koneksi", lv = 2, bs = true, q = "Sinyal WiFi bisa melemah jika terhalang tembok tebal atau jaraknya terlalu jauh.", jawab = true,
		e = "Benar! Gelombang radio WiFi bisa terganggu jarak dan penghalang seperti tembok." },
	{ topik = "koneksi", lv = 2, q = "Jaringan internet seluler 4G/5G di HP mendapatkan sinyal dari...",
		c = { "Menara BTS operator", "Kabel UTP", "Printer", "Flashdisk" },
		e = "HP menerima sinyal internet seluler dari menara BTS (Base Transceiver Station) milik operator." },
	{ topik = "koneksi", lv = 3, q = "Satuan untuk mengukur kecepatan transfer data internet adalah...",
		c = { "Mbps (megabit per second)", "Watt", "Kilogram", "Celcius" },
		e = "Kecepatan internet diukur dalam bps (bit per second). 1 Mbps = 1 juta bit per detik." },
	{ topik = "koneksi", lv = 3, q = "Berikut ini kekurangan koneksi NIRKABEL dibanding kabel adalah...",
		c = { "Mudah terganggu jarak dan penghalang", "Tidak bisa berpindah tempat", "Harus memasang kabel panjang", "Tidak bisa dipakai di HP" },
		e = "Nirkabel fleksibel (bisa berpindah), tetapi sinyalnya bisa terganggu jarak, penghalang, dan lebih rawan disadap." },
	{ topik = "koneksi", lv = 3, bs = true, q = "Kabel serat optik bawah laut menghubungkan internet antar pulau dan antar negara.", jawab = true,
		e = "Benar! Sebagian besar lalu lintas internet dunia melewati kabel serat optik bawah laut." },

	---------------------------------------------------------------
	-- KEAMANAN & PROTEKSI DATA
	---------------------------------------------------------------
	{ topik = "keamanan", lv = 1, q = "Manakah password yang paling KUAT?",
		c = { "B3l@jar!Jaringan7", "12345678", "password", "tanggallahir" },
		e = "Password kuat: panjang, campuran huruf besar, huruf kecil, angka, dan simbol, serta sulit ditebak." },
	{ topik = "keamanan", lv = 1, bs = true, q = "Kode OTP boleh diberikan kepada orang yang mengaku petugas bank lewat telepon.", jawab = false,
		e = "Salah! Kode OTP bersifat RAHASIA. Petugas resmi tidak pernah meminta kode OTP." },
	{ topik = "keamanan", lv = 1, q = "Penipuan lewat pesan atau link palsu untuk mencuri password disebut...",
		c = { "Phishing", "Browsing", "Download", "Streaming" },
		e = "Phishing (dari kata fishing = memancing) memancing korban agar memberikan data pribadinya." },
	{ topik = "keamanan", lv = 1, q = "Berikut ini yang termasuk DATA PRIBADI yang harus dijaga adalah...",
		c = { "Nomor NIK dan alamat rumah", "Nama ibu kota negara", "Rumus luas persegi", "Judul lagu kebangsaan" },
		e = "Data pribadi seperti NIK, alamat, tanggal lahir, dan password tidak boleh disebarkan sembarangan." },
	{ topik = "keamanan", lv = 2, q = "Proses mengubah data menjadi kode acak agar tidak bisa dibaca orang lain disebut...",
		c = { "Enkripsi", "Dekripsi", "Download", "Upload" },
		e = "Enkripsi mengubah data asli menjadi kode acak. Dekripsi mengembalikannya menjadi data asli." },
	{ topik = "keamanan", lv = 2, q = "Program jahat seperti virus, worm, dan trojan disebut...",
		c = { "Malware", "Firmware", "Freeware", "Hardware" },
		e = "Malware (malicious software) adalah perangkat lunak jahat. Lindungi perangkat dengan antivirus." },
	{ topik = "keamanan", lv = 3, q = "Dengan Caesar Cipher geser 1 huruf (A->B, B->C), kata 'ABC' dienkripsi menjadi...",
		c = { "BCD", "ZAB", "ABD", "CDE" },
		e = "Setiap huruf digeser 1: A->B, B->C, C->D. Jadi ABC menjadi BCD." },
	{ topik = "keamanan", lv = 3, q = "Dengan Caesar Cipher geser 1 huruf, kata 'HAI' dienkripsi menjadi...",
		c = { "IBJ", "GZH", "HAJ", "JCK" },
		e = "H->I, A->B, I->J. Jadi HAI menjadi IBJ. Untuk dekripsi, geser kembali 1 huruf ke kiri." },
	{ topik = "keamanan", lv = 2, q = "Fitur keamanan yang meminta kode tambahan (misal dari SMS) selain password disebut...",
		c = { "Verifikasi 2 langkah (2FA)", "Mode gelap", "Auto rotate", "Zoom" },
		e = "Verifikasi 2 langkah membuat akun tetap aman walaupun password diketahui orang lain." },
	{ topik = "keamanan", lv = 2, bs = true, q = "Menyimpan file di cloud storage memungkinkan file diakses dari perangkat lain melalui internet.", jawab = true,
		e = "Benar! Cloud storage (contoh: Google Drive) menyimpan data di server internet sehingga bisa diakses di mana saja." },
	{ topik = "keamanan", lv = 3, q = "Saat memakai WiFi publik di kafe, tindakan yang paling AMAN adalah...",
		c = { "Tidak login ke akun bank atau akun penting", "Membagikan password ke teman", "Mematikan antivirus", "Mengklik semua link yang muncul" },
		e = "WiFi publik rawan disadap. Hindari login akun penting atau transaksi keuangan di WiFi publik." },
	{ topik = "keamanan", lv = 3, bs = true, q = "Menggunakan satu password yang sama untuk semua akun adalah kebiasaan yang aman.", jawab = false,
		e = "Salah! Jika satu akun bocor, semua akun lain ikut terancam. Gunakan password berbeda di setiap akun." },
}

local function shuffle(list)
	for i = #list, 2, -1 do
		local j = math.random(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- Mengambil sejumlah soal untuk satu ronde, diurutkan dari mudah ke sulit.
function Questions.Pick(topicId, count)
	local pool = {}
	for _, q in ipairs(Questions.List) do
		if topicId == "campuran" or q.topik == topicId then
			table.insert(pool, q)
		end
	end
	shuffle(pool)

	local picked = {}
	if topicId == "campuran" then
		-- ambil bergiliran dari tiap topik agar materinya merata
		local byTopic, order = {}, {}
		for _, q in ipairs(pool) do
			if not byTopic[q.topik] then
				byTopic[q.topik] = {}
				table.insert(order, q.topik)
			end
			table.insert(byTopic[q.topik], q)
		end
		local added = true
		while #picked < count and added do
			added = false
			for _, topic in ipairs(order) do
				local q = table.remove(byTopic[topic])
				if q and #picked < count then
					table.insert(picked, q)
					added = true
				end
			end
		end
	else
		for i = 1, math.min(count, #pool) do
			picked[i] = pool[i]
		end
	end

	-- urutkan dari mudah ke sulit (tetap acak di level yang sama)
	local rank = {}
	for i, q in ipairs(picked) do
		rank[q] = (q.lv or 1) * 1000 + i
	end
	table.sort(picked, function(a, b)
		return rank[a] < rank[b]
	end)
	return picked
end

-- Menyiapkan soal untuk ditampilkan: mengacak pilihan & memetakan ke kotak (pad) 1-4.
-- Hasil: { text, kind = "PG"/"BS", options = { {pad, letter, text, color} }, correctPad, explanation, topic }
function Questions.Prepare(q, Config)
	local prepared = {
		text = q.q,
		explanation = q.e or "",
		topic = q.topik,
		level = q.lv or 1,
		options = {},
	}
	if q.bs then
		prepared.kind = "BS"
		prepared.options = {
			{ pad = 2, letter = "✔", text = "BENAR", color = Config.TrueColor },
			{ pad = 3, letter = "✖", text = "SALAH", color = Config.FalseColor },
		}
		prepared.correctPad = q.jawab and 2 or 3
	else
		prepared.kind = "PG"
		local order = shuffle({ 1, 2, 3, 4 })
		for pad = 1, 4 do
			local choiceIndex = order[pad]
			table.insert(prepared.options, {
				pad = pad,
				letter = Config.PadLetters[pad],
				text = q.c[choiceIndex],
				color = Config.PadColors[pad],
			})
			if choiceIndex == 1 then
				prepared.correctPad = pad
			end
		end
	end
	return prepared
end

function Questions.CountByTopic()
	local counts = {}
	for _, q in ipairs(Questions.List) do
		counts[q.topik] = (counts[q.topik] or 0) + 1
	end
	return counts
end

return Questions
