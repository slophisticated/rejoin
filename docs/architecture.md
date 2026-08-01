# Architecture

Rejoin Engine menggunakan Modular Architecture.

Semua module memiliki satu tanggung jawab.

---

Project Structure

rejoin/

main.lua

core/

managers/

utils/

config/

data/

assets/

docs/

---

Core

Logger

Config

State

Menu

---

Managers

Instance Manager

APK Manager

Monitor Manager

Recovery Manager

AutoExecute Manager

---

Utils

Shell

Android

JSON

File

Timer

---

Flow

Program Start

↓

Load Config

↓

Load Logger

↓

Load State

↓

Dashboard

↓

Start

↓

Monitor

↓

Recovery

↓

Exit

---

Monitor

Loop

↓

Instance 1

↓

Instance 2

↓

Instance 3

↓

Sleep

↓

Repeat

---

Recovery

Force Stop

↓

Launch

↓

Inject

↓

Join Private Server

↓

Continue