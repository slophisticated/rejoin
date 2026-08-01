# Rejoin Engine

## Project Overview

Rejoin Engine adalah aplikasi automation berbasis Lua yang berjalan di Termux (Android).

Tujuan utama project ini adalah mengelola beberapa instance Roblox secara otomatis, termasuk proses launch, monitoring, recovery, dan auto rejoin.

Project ini dirancang modular agar mudah dikembangkan dan dipelihara.

---

# Platform

- Android 10+
- Termux
- Lua 5.3
- Root (Magisk / KernelSU)
- Tanpa Server
- Semua data disimpan secara lokal

---

# Core Features

## Multi Instance

Mendukung lebih dari satu Roblox package.

Contoh:

- com.roblox.client
- com.roblox.clone1
- com.roblox.clone2

Setiap instance memiliki:

- Name
- Package Name
- Private Server URL

---

## AutoExecute

AutoExecute bersifat global.

Semua instance menggunakan script AutoExecute yang sama.

---

## Private Server

Private Server disimpan per instance.

Contoh:

Main
↓

Private Server A

Clone
↓

Private Server B

---

## Monitor

Monitor menggunakan satu loop.

Flow:

Loop

↓

Check Instance 1

↓

Check Instance 2

↓

Check Instance 3

↓

Sleep

↓

Ulang

Jika salah satu instance gagal, recovery hanya dilakukan pada instance tersebut.

Instance lain tetap diproses.

---

## Recovery

Recovery terdiri dari:

- Force Stop
- Launch APK
- Inject AutoExecute
- Open Private Server
- Continue Monitoring

Jika recovery gagal:

- Tulis log
- Lanjut ke instance berikutnya

Recovery akan dicoba kembali pada loop berikutnya.

---

# Setup Wizard

Wizard hanya muncul saat:

- Config belum ada
- User melakukan Reset Config

Wizard menawarkan dua metode:

1. Auto Detect Package
2. Manual Input

---

## Auto Detect

Melakukan scan package Roblox yang terinstall.

User dapat memilih package mana yang ingin diimport.

---

## Manual

User memasukkan:

- Package Name
- Instance Name
- Private Server

Lalu dapat menambah instance lagi.

---

# Menu

Main Menu

- Start
- Instances
- Settings
- Logs
- About
- Exit

---

# Instances Menu

- List Instance
- Add Instance
- Edit Instance
- Delete Instance

---

# Settings

Global Setting

- AutoExecute
- Monitor Interval
- Recovery Delay
- Debug Mode

---

# Logs

Menampilkan seluruh aktivitas aplikasi.

Contoh:

Launch

Recovery

Join

Error

Success

---

# Storage

Semua konfigurasi disimpan secara lokal.

Tidak menggunakan backend.

Tidak menggunakan database online.

---

# Architecture Goal

Project harus modular.

Tidak boleh ada file yang menangani banyak tanggung jawab sekaligus.