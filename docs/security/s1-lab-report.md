# S1 Lab Report — Local Storage Security

- **Date:** 2026-09-09
- **Sprint:** S1 (Day 4)
- **Author:** Naseer
- **Device:** Android emulator, API 34 (release-mode APK)
- **Related:** ADR-0002, DATA_CLASSIFICATION.md §4.1/§4.2, threat_register.md T-011
- **Scope:** verify that the SQLCipher DB and hardware-backed KeyStore
  actually protect data at rest under the threat model in ADR-0002.

---

## Lab 1 — DB is not readable as plain SQLite

**Hypothesis:** without the key from KeyStore, `fieldproof.db` is not a
valid SQLite database.

**Commands:**
adb exec-out "run-as com.fieldproof.fieldproof_mobile
cat /data/data/com.fieldproof.fieldproof_mobile/databases/fieldproof.db" > /tmp/stolen.db

sqlite3 /tmp/stolen.db ".tables"
**Result:**
Error: file is not a database
Verdict: PASS

//Lab 2 — No plaintext schema or values in the file
**Hypothesis:** SQLCipher encrypts both the schema and the row data, so
searching the raw bytes for known column names yields nothing.
**Commands:**
strings /tmp/stolen.db | grep -iE "attendance|check_in|signature|idempotency" | head
strings /tmp/stolen.db | grep -ci "sqlite" || echo 0
**Result:**
total 40
drwxrwx--x 2 u0_a234 u0_a234 4096 2026-09-15 17:18 .
drwx------ 8 u0_a234 u0_a234 4096 2026-09-15 17:18 ..
-rw-rw---- 1 u0_a234 u0_a234  536 2026-09-15 17:18 FlutterSecureKeyStorage.xml
-rw-rw---- 1 u0_a234 u0_a234  277 2026-09-15 17:18 FlutterSecureStorage.xml
-rw-rw---- 1 u0_a234 u0_a234  240 2026-09-15 17:18 FlutterSecureStorageConfiguration:FlutterSecureStorage.xml
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <string name="VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg_fp_db_key_v1">VD5+bVJOnPkBpwBcpom1WvIVXG21OjJfmyIja5wunyvrDbiun9E2hG2o/GRQ9D1T+iZGd/9TLz5g&#10;JQihqpP/9nmXJgkSCCJD&#10;  </string>
</map>
Verdict: PASS 
