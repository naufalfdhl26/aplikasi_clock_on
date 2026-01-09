class AttendanceSummary {
  final int hadir;
  final int cuti;
  final int izin;
  final int alpha;

  AttendanceSummary({
    required this.hadir,
    required this.cuti,
    required this.izin,
    required this.alpha,
  });

  factory AttendanceSummary.empty() =>
      AttendanceSummary(hadir: 0, cuti: 0, izin: 0, alpha: 0);
}
