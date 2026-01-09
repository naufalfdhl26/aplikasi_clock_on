# Report Screen Debug Guide

**Status**: Masih menunjukkan 0 - ini adalah guide untuk diagnose masalah

## Langkah 1: Lihat Console Logs

Saat membuka report screen, ada banyak debug logs yang akan dicetak.

### Apa yang harus dilihat:

```
=== REPORT SCREEN LOAD DATA ===
📅 Loading data for: 2026-01
📦 Raw response length: ...
📦 Total items in response: ...
📊 Total attendance records parsed: ...
```

**Jika `Total attendance records parsed: 0`** → Ada problem dengan data di database atau parsing

### Debug Output yang Mungkin:

#### Scenario 1: Ada data tapi tidak filtering dengan benar
```
📊 Total attendance records parsed: 10
📅 Filtering for year: 2026, month: 1
✅ Filtered attendance records: 0  ← PROBLEM!
```
**Penyebab**: Date format berbeda atau employee ID tidak match

#### Scenario 2: Tidak ada data sama sekali
```
❌ No attendance response from API
```
**Penyebab**: Database kosong atau API error

#### Scenario 3: Data ada tapi employee tidak match
```
✅ Filtered attendance records: 5
...
👥 Sample employees: 3
   [0] ID: "EMP001", Name: Budi
   ...
   [0] ID: "EMP001", Status: present, Date: 2026-01-01
   ...
❌ Employee ABC (emp001): No attendance records
```
**Penyebab**: Employee ID format berbeda (case sensitivity atau format)

---

## Langkah 2: Cek Raw Database Data

Jika logs menunjukkan data ada, tapi filtered menjadi 0, cek:

### A. Attendance Record Sample
Lihat di console output:
```
📝 Sample parsed records:
   [0] Employee: "EMP001", Status: present, Date: 2026-01-01
```

**Check**:
- ✅ Employee ID format (uppercase/lowercase)
- ✅ Date format harus ISO (2026-01-01)
- ✅ Status harus: present/hadir, absent, cuti, izin

### B. Employee ID Matching
Lihat di console:
```
👤 Sample employees:
   [0] ID: "EMP001", Name: Budi, Division: IT
```

**Pastikan**:
- Employee ID di attendance = Employee ID di employee table
- Casenya sama (EMP001 vs emp001)

---

## Langkah 3: Verify Data di Database

### Pakai script test_attendance_data.dart

```bash
dart test_attendance_data.dart
```

Output akan menunjukkan:
```
🔍 Testing Attendance Data Sync...

📋 Test 1: Fetching attendance records...
📊 Total attendance records parsed: 10

📝 First 3 records:
   [0] ID: abc123
       Employee ID: "EMP001"
       Date: 2026-01-01
       Status: present

👥 Test 2: Fetching employee records...
👥 Total employees parsed: 5

📝 First 3 employees:
   [0] ID: "EMP001"
       Name: Budi
       Division: IT

🔗 Test 3: Checking Employee-Attendance ID Matching...
✅ Budi (EMP001): 3 records
❌ Andi (EMP002): No attendance records

📊 Summary: 1/5 employees have matching attendance records
```

**Apa yang harus dicek**:
1. ✅ Total attendance records > 0 (data ada)
2. ✅ Total employees > 0 (employee ada)
3. ✅ Employee IDs match antara records (gunakan Summary)
4. ✅ Bulan/tahun ada di dalam data

---

## Skenario Perbaikan

### If: Attendance Records = 0 tapi di database ada

**Kemungkinan**:
1. API tidak return data → Check connection
2. Response format berbeda → Check raw response
3. JSON parsing error → Check console error

**Solusi**:
- Cek network connectivity
- Pastikan data di database ada (pakai curl/Postman)
- Check API endpoint yang digunakan

### If: Attendance ada, Employee ada, tapi tidak match

**Kemungkinan**:
1. Employee ID format berbeda
2. Case sensitivity (EMP001 vs emp001)

**Solusi**:
- Kode sudah handle case-insensitive
- Lihat exact IDs di console output
- Jika tetap tidak match → ada yang salah saat insert

### If: Total ada, tapi Statistics tetap 0

**Kemungkinan**:
1. Status field tidak di-recognize
2. Date filtering salah

**Solusi**:
- Check status values (hadir, present, etc)
- Verify month/year dipilih dengan benar
- Check console logs untuk "Sample parsed records"

---

## Quick Checklist

- [ ] Run app dan buka Report Screen
- [ ] Lihat console output (perlu enable debug logs)
- [ ] Check jika ada error messages
- [ ] Run `dart test_attendance_data.dart`
- [ ] Compare hasil test dengan report screen
- [ ] Check bulan/tahun yang dipilih
- [ ] Verify employee IDs match

---

## Informasi untuk Developer

**Files yang di-update**:
- `lib/data/models/attendance_model.dart` - Better null/type handling
- `lib/data/services/admin_report_service.dart` - More debug logging
- `lib/main_screens/admin/admin_report_screen.dart` - Better error handling

**Key improvements**:
- Case-insensitive employee ID matching
- Better date parsing with fallback
- Detailed debug logging di setiap step
- Safe type casting
