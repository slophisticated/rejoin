# Coding Standard

## General Rules

- Satu file hanya memiliki satu tanggung jawab.
- Jangan hardcode konfigurasi.
- Semua akses Android harus melalui utils/android.lua.
- Semua perintah shell harus melalui utils/shell.lua.
- Jangan langsung menggunakan os.execute() di module lain.
- Semua log menggunakan Logger.
- Semua state menggunakan State Manager.
- Semua konfigurasi melalui Config Manager.

---

## Naming

Function

camelCase

launchAPK()

checkInstance()

startMonitor()

Variable

camelCase

restartDelay

monitorInterval

Class / Module

PascalCase

Logger

Config

Android

InstanceManager

RecoveryManager