// SIAKAD Mini - Studi kasus: Sistem Informasi Akademik Kampus
// Fitur: Dashboard, Pengisian KRS (state + validasi interaksi), Presensi.
// Tidak butuh package eksternal. Cukup ganti isi lib/main.dart dengan file ini.

import 'package:flutter/material.dart';

void main() => runApp(const SiakadApp());

// ======================================================================
// MODEL
// ======================================================================
class Course {
  final String id;
  final String nama;
  final String dosen;
  final int sks;
  final bool wajib;
  final String hari;
  final String mulai; // format "HH:mm"
  final String selesai;

  const Course({
    required this.id,
    required this.nama,
    required this.dosen,
    required this.sks,
    required this.wajib,
    required this.hari,
    required this.mulai,
    required this.selesai,
  });

  static int _menit(String jam) {
    final p = jam.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  bool bentrokDengan(Course o) =>
      hari == o.hari &&
      _menit(mulai) < _menit(o.selesai) &&
      _menit(o.mulai) < _menit(selesai);

  String get jadwal => '$hari, $mulai - $selesai';
}

enum KrsStatus { draft, mengirim, diajukan }

enum FilterKategori { semua, wajib, pilihan }

// ======================================================================
// STATE (ChangeNotifier)
// ======================================================================
class KrsController extends ChangeNotifier {
  static const int maxSks = 24;
  static const int totalPertemuan = 16;

  final List<Course> semua = const [
    Course(id: 'IF301', nama: 'Pemrograman Mobile', dosen: 'Dr. Andi Wijaya', sks: 3, wajib: true, hari: 'Senin', mulai: '08:00', selesai: '10:30'),
    Course(id: 'IF302', nama: 'Basis Data Lanjut', dosen: 'Ir. Siti Rahma, M.T.', sks: 3, wajib: true, hari: 'Senin', mulai: '10:00', selesai: '12:30'),
    Course(id: 'IF303', nama: 'Jaringan Komputer', dosen: 'Budi Santoso, M.Kom.', sks: 3, wajib: true, hari: 'Selasa', mulai: '08:00', selesai: '10:30'),
    Course(id: 'IF304', nama: 'Kecerdasan Buatan', dosen: 'Dr. Rina Kusuma', sks: 3, wajib: true, hari: 'Rabu', mulai: '08:00', selesai: '10:30'),
    Course(id: 'IF305', nama: 'Rekayasa Perangkat Lunak', dosen: 'Prof. Hendra Gunawan', sks: 3, wajib: true, hari: 'Kamis', mulai: '08:00', selesai: '10:30'),
    Course(id: 'IF306', nama: 'Etika Profesi', dosen: 'Dewi Lestari, M.Hum.', sks: 2, wajib: true, hari: 'Jumat', mulai: '08:00', selesai: '09:40'),
    Course(id: 'IF351', nama: 'Data Mining', dosen: 'Dr. Fajar Nugroho', sks: 3, wajib: false, hari: 'Selasa', mulai: '09:00', selesai: '11:30'),
    Course(id: 'IF352', nama: 'UI/UX Design', dosen: 'Maya Putri, M.Ds.', sks: 2, wajib: false, hari: 'Rabu', mulai: '13:00', selesai: '14:40'),
    Course(id: 'IF353', nama: 'Cloud Computing', dosen: 'Agus Prasetyo, M.T.', sks: 3, wajib: false, hari: 'Kamis', mulai: '13:00', selesai: '15:30'),
    Course(id: 'IF354', nama: 'Keamanan Informasi', dosen: 'Linda Hartono, M.Sc.', sks: 2, wajib: false, hari: 'Jumat', mulai: '13:00', selesai: '14:40'),
  ];

  final Set<String> _dipilih = {};
  final Map<String, int> _hadir = {};
  final Set<String> _absenHariIni = {};

  String _query = '';
  FilterKategori _filter = FilterKategori.semua;
  KrsStatus _status = KrsStatus.draft;

  // ---- getter ----
  KrsStatus get status => _status;
  FilterKategori get filter => _filter;
  bool get terkunci => _status != KrsStatus.draft;

  List<Course> get terpilih =>
      semua.where((c) => _dipilih.contains(c.id)).toList();

  int get totalSks => terpilih.fold(0, (s, c) => s + c.sks);

  List<Course> get terfilter => semua.where((c) {
        final cocokQuery = c.nama.toLowerCase().contains(_query.toLowerCase()) ||
            c.dosen.toLowerCase().contains(_query.toLowerCase());
        final cocokFilter = switch (_filter) {
          FilterKategori.semua => true,
          FilterKategori.wajib => c.wajib,
          FilterKategori.pilihan => !c.wajib,
        };
        return cocokQuery && cocokFilter;
      }).toList();

  bool dipilih(Course c) => _dipilih.contains(c.id);
  int jumlahHadir(Course c) => _hadir[c.id] ?? 0;
  bool sudahAbsen(Course c) => _absenHariIni.contains(c.id);

  // ---- aksi ----
  void setQuery(String q) {
    _query = q;
    notifyListeners();
  }

  void setFilter(FilterKategori f) {
    _filter = f;
    notifyListeners();
  }

  /// Mengembalikan pesan error bila gagal, null bila berhasil.
  String? toggle(Course c) {
    if (terkunci) return 'KRS sudah diajukan. Batalkan pengajuan untuk mengubah.';
    if (_dipilih.contains(c.id)) {
      _dipilih.remove(c.id);
      notifyListeners();
      return null;
    }
    for (final o in terpilih) {
      if (c.bentrokDengan(o)) return 'Jadwal bentrok dengan "${o.nama}" (${o.jadwal}).';
    }
    if (totalSks + c.sks > maxSks) {
      return 'Melebihi batas maksimum $maxSks SKS.';
    }
    _dipilih.add(c.id);
    notifyListeners();
    return null;
  }

  Future<void> ajukan() async {
    _status = KrsStatus.mengirim;
    notifyListeners();
    await Future.delayed(const Duration(seconds: 2)); // simulasi request ke server
    _status = KrsStatus.diajukan;
    notifyListeners();
  }

  void batalkanPengajuan() {
    _status = KrsStatus.draft;
    _hadir.clear();
    _absenHariIni.clear();
    notifyListeners();
  }

  void absen(Course c) {
    if (_status != KrsStatus.diajukan || _absenHariIni.contains(c.id)) return;
    _absenHariIni.add(c.id);
    _hadir[c.id] = jumlahHadir(c) + 1;
    notifyListeners();
  }
}

// ======================================================================
// APP ROOT (state tema: terang/gelap)
// ======================================================================
class SiakadApp extends StatefulWidget {
  const SiakadApp({super.key});

  @override
  State<SiakadApp> createState() => _SiakadAppState();
}

class _SiakadAppState extends State<SiakadApp> {
  final KrsController _ctrl = KrsController();
  ThemeMode _mode = ThemeMode.light;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggleTema() => setState(() {
        _mode = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
      });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIAKAD Mini',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1B5E20),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1B5E20),
        brightness: Brightness.dark,
      ),
      home: HomeShell(
        ctrl: _ctrl,
        gelap: _mode == ThemeMode.dark,
        onToggleTema: _toggleTema,
      ),
    );
  }
}

// ======================================================================
// SHELL: Bottom navigation
// ======================================================================
class HomeShell extends StatefulWidget {
  final KrsController ctrl;
  final bool gelap;
  final VoidCallback onToggleTema;

  const HomeShell({
    super.key,
    required this.ctrl,
    required this.gelap,
    required this.onToggleTema,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _judul = ['Beranda', 'Pengisian KRS', 'Presensi'];

  @override
  Widget build(BuildContext context) {
    final halaman = [
      DashboardPage(ctrl: widget.ctrl, keKrs: () => setState(() => _index = 1)),
      KrsPage(ctrl: widget.ctrl),
      PresensiPage(ctrl: widget.ctrl),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_judul[_index]),
        actions: [
          IconButton(
            tooltip: widget.gelap ? 'Mode terang' : 'Mode gelap',
            icon: Icon(widget.gelap ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTema,
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: halaman),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.edit_note_outlined), selectedIcon: Icon(Icons.edit_note), label: 'KRS'),
          NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: 'Presensi'),
        ],
      ),
    );
  }
}

// ======================================================================
// HALAMAN 1: DASHBOARD
// ======================================================================
class DashboardPage extends StatelessWidget {
  final KrsController ctrl;
  final VoidCallback keKrs;

  const DashboardPage({super.key, required this.ctrl, required this.keKrs});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        final (label, warna, ikon) = switch (ctrl.status) {
          KrsStatus.draft => ('Belum diajukan', cs.tertiary, Icons.pending_actions),
          KrsStatus.mengirim => ('Mengirim...', cs.secondary, Icons.sync),
          KrsStatus.diajukan => ('Sudah diajukan', cs.primary, Icons.verified),
        };

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: cs.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: cs.primary,
                      child: Icon(Icons.person, size: 32, color: cs.onPrimary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Halo, Ahmad Fauzi 👋',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 4),
                          const Text('NIM 2210511001 • Teknik Informatika'),
                          const Text('Semester 5 • IPK 3,67'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: keKrs,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(ikon, color: warna, size: 36),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Status KRS Semester Ganjil 2026/2027',
                                style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 4),
                            Text(label,
                                style: TextStyle(color: warna, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('${ctrl.terpilih.length} mata kuliah • ${ctrl.totalSks}/${KrsController.maxSks} SKS'),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Jadwal Kuliah Saya', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (ctrl.terpilih.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Belum ada mata kuliah. Buka menu KRS untuk memilih.'),
                ),
              )
            else
              ...ctrl.terpilih.map(
                (c) => Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text(c.hari.substring(0, 3))),
                    title: Text(c.nama),
                    subtitle: Text('${c.mulai} - ${c.selesai} • ${c.dosen}'),
                    trailing: Text('${c.sks} SKS'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ======================================================================
// HALAMAN 2: KRS (interaksi utama)
// ======================================================================
class KrsPage extends StatelessWidget {
  final KrsController ctrl;

  const KrsPage({super.key, required this.ctrl});

  void _snack(BuildContext context, String pesan, {bool error = false}) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(pesan),
        backgroundColor: error ? cs.error : null,
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _konfirmasiAjukan(BuildContext context) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.help_outline),
        title: const Text('Ajukan KRS?'),
        content: Text(
          'Anda memilih ${ctrl.terpilih.length} mata kuliah dengan total ${ctrl.totalSks} SKS. '
          'Setelah diajukan, pilihan tidak dapat diubah kecuali dibatalkan.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Periksa lagi')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, ajukan')),
        ],
      ),
    );
    if (ya != true) return;
    await ctrl.ajukan();
    if (context.mounted) _snack(context, 'KRS berhasil diajukan ke Dosen Wali ✅');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        final penuh = ctrl.totalSks >= KrsController.maxSks;
        final data = ctrl.terfilter;

        return Column(
          children: [
            // ---- Ringkasan SKS ----
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Beban studi'),
                      Text(
                        '${ctrl.totalSks} / ${KrsController.maxSks} SKS',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: penuh ? cs.error : cs.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: ctrl.totalSks / KrsController.maxSks,
                      color: penuh ? cs.error : cs.primary,
                    ),
                  ),
                ],
              ),
            ),
            // ---- Pencarian ----
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                onChanged: ctrl.setQuery,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Cari mata kuliah atau dosen...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
            ),
            // ---- Filter ----
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  for (final f in FilterKategori.values) ...[
                    ChoiceChip(
                      label: Text(switch (f) {
                        FilterKategori.semua => 'Semua',
                        FilterKategori.wajib => 'Wajib',
                        FilterKategori.pilihan => 'Pilihan',
                      }),
                      selected: ctrl.filter == f,
                      onSelected: (_) => ctrl.setFilter(f),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            if (ctrl.terkunci)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline, size: 18),
                    SizedBox(width: 8),
                    Expanded(child: Text('KRS terkunci karena sudah diajukan.')),
                  ],
                ),
              ),
            // ---- Daftar Mata Kuliah ----
            Expanded(
              child: data.isEmpty
                  ? const Center(child: Text('Mata kuliah tidak ditemukan.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: data.length,
                      itemBuilder: (context, i) {
                        final c = data[i];
                        final dipilih = ctrl.dipilih(c);
                        return Card(
                          color: dipilih ? cs.primaryContainer : null,
                          child: CheckboxListTile(
                            value: dipilih,
                            onChanged: (_) {
                              final err = ctrl.toggle(c);
                              if (err != null) _snack(context, err, error: true);
                            },
                            title: Text('${c.nama} (${c.sks} SKS)'),
                            subtitle: Text('${c.id} • ${c.jadwal}\n${c.dosen}'),
                            isThreeLine: true,
                            secondary: Chip(
                              label: Text(c.wajib ? 'Wajib' : 'Pilihan'),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            // ---- Tombol aksi ----
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: switch (ctrl.status) {
                    KrsStatus.draft => FilledButton.icon(
                        onPressed: ctrl.terpilih.isEmpty ? null : () => _konfirmasiAjukan(context),
                        icon: const Icon(Icons.send),
                        label: const Text('Ajukan KRS'),
                      ),
                    KrsStatus.mengirim => const FilledButton(
                        onPressed: null,
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    KrsStatus.diajukan => OutlinedButton.icon(
                        onPressed: () {
                          ctrl.batalkanPengajuan();
                          _snack(context, 'Pengajuan dibatalkan. Anda dapat mengubah KRS.');
                        },
                        icon: const Icon(Icons.undo),
                        label: const Text('Batalkan Pengajuan'),
                      ),
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ======================================================================
// HALAMAN 3: PRESENSI
// ======================================================================
class PresensiPage extends StatelessWidget {
  final KrsController ctrl;

  const PresensiPage({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        if (ctrl.status != KrsStatus.diajukan) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_clock, size: 64),
                  SizedBox(height: 12),
                  Text(
                    'Presensi aktif setelah KRS diajukan.\nSilakan selesaikan KRS terlebih dahulu.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: ctrl.terpilih.map((c) {
            final hadir = ctrl.jumlahHadir(c);
            final persen = hadir / KrsController.totalPertemuan;
            final sudah = ctrl.sudahAbsen(c);

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.nama, style: Theme.of(context).textTheme.titleMedium),
                    Text(c.jadwal),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(value: persen, minHeight: 8),
                        ),
                        const SizedBox(width: 12),
                        Text('$hadir/${KrsController.totalPertemuan}'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: sudah
                            ? null
                            : () {
                                ctrl.absen(c);
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(SnackBar(
                                    content: Text('Presensi ${c.nama} tercatat.'),
                                    behavior: SnackBarBehavior.floating,
                                  ));
                              },
                        style: sudah
                            ? FilledButton.styleFrom(disabledBackgroundColor: cs.primaryContainer)
                            : null,
                        icon: Icon(sudah ? Icons.check_circle : Icons.how_to_reg),
                        label: Text(sudah ? 'Sudah Hadir' : 'Hadir Hari Ini'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}