# ✅ Refined "Fail-Proof" Custom ROM Installation Guide — Redmi Note 11 (spes)

> **Device:** Redmi Note 11 — codename **spes** (spesn = NFC variant) · Snapdragon 680 · 4GB RAM
> **Last verified:** 2026-09-02 · OrangeFox R12.0 · crDroid 9.34 (A13) · NikGapps A13 · KernelSU

---

## 1️⃣ Preparation

```
adb devices
adb reboot bootloader
```

- ✅ Verify the bootloader is **unlocked** (fastboot: `fastboot oem device-info` or check for "unlocked" state).
- 🗄️ **Back up your data first** — see Section 9. This is the step nobody skips twice.

---

## 2️⃣ Boot into Recovery (Temporary OrangeFox)

> Use **OrangeFox R12.0** — the FINAL build for spes (maintainer JassiV007 retired, no more updates).
> Download: orangefox.download → spes → R12.0 Stable.

```
# extract recovery.img from OrangeFox-R12.0-spes.zip, then:
fastboot boot recovery.img
```

> ⚠️ This only boots OrangeFox **temporarily**. It doesn't flash anything yet.
>
> (take the recovery.img from orangefox.zip, place it somewhere easy, `cd` there before running the command)

**To make OrangeFox permanent** (optional): flash `OrangeFox-R12.0-spes.zip` from storage after booting into it.

To push it to your phone:

```
adb push OrangeFox-R12.0-spes.zip /sdcard/
```

Then flash it from OrangeFox.

---

## 3️⃣ Clean Wipe (Very Important)

Inside OrangeFox:

- Wipe **Dalvik**
- Wipe **Cache**
- **Format Data** → type `yes`

🚨 **CRITICAL STEP:**
 After formatting, go to:

> Reboot → Recovery

Wait for OrangeFox to fully reload before continuing.

---

## 4️⃣ Flash Order — Firmware → ROM → GApps (THE key step)

> ⚠️ **spes has NO separate recovery partition** (recovery lives inside the `boot` ramdisk).
> If you want OrangeFox to stay permanent, keep **"ReFlash OrangeFox after installing a ROM" CHECKED**
> during the ROM install — otherwise crDroid's payload overwrites `boot` and replaces recovery.

Push all three ZIPs to the phone first (easier than sideloading one by one):

```
adb push firmware.zip /sdcard/
adb push rom.zip /sdcard/
adb push gapps.zip /sdcard/
```

Then in OrangeFox → **Install**, in this exact order (**no reboot between them**):

1. **① Firmware first** — *required when moving from MIUI to a custom ROM*
   - e.g. `fw_spes_miui_SPESGlobal_OS1.0.8.0.TGCMIXM_953c1be1f4_13.0.zip`
2. **② ROM**
   - e.g. `crDroidAndroid-13.0-20251124-spes-v9.34.zip` (A13 — the sweet spot for 4GB; see Gotchas)
3. **③ GApps** — immediately after the ROM, still **no reboot**
   - **Must match the ROM's Android version** — A13 ROM needs NikGapps A13, NOT A15/A16 GApps!
   - e.g. `NikGapps-crdroid-official-arm64-13-20260223-signed.zip`

---

## 5️⃣ Post-Flash: Format Data AGAIN

After flashing GApps:

- **Wipe → Format Data → type `yes`**

(Prevents FBE/encryption conflicts on first boot. Do this AFTER the ROM + GApps, not before.)

---

## 6️⃣ Reboot to System

- **Reboot → System**
- First boot takes several minutes — you'll see the crDroid logo, then the Google Setup Wizard (if GApps installed).

---

## 7️⃣ Root

### ✅ KernelSU (recommended for crDroid 9.34)
- KernelSU-**Next** is **built into crDroid's kernel** (GreenForce). No boot patching needed.
- Just install the **KernelSU Manager APK** after first boot and activate root.

### 🔹 Magisk (fallback, for other ROMs / stock)
> ⚠️ spes has **NO `init_boot` partition** — Magisk patches **`boot`**, NOT init_boot!

1. Extract the ROM ZIP on your PC.
2. Locate `boot.img` (extract from `payload.bin` if not visible).
3. Transfer `boot.img` to your phone → patch it in the **Magisk app**.
4. Transfer the patched file back, then:

```
fastboot flash boot magisk_patched-30600_6cLee.img
```

---

## 8️⃣ Restore Apps (WhatsApp / Signal root-copy method)

> Vanilla / no-GApps ROM = **no Google Drive restore** for WhatsApp — root file copy is the only reliable path.

1. Install the **exact same APK versions** you backed up.
2. **Run each app once** (creates its data dir), then force-stop.
3. Copy the backed-up data dirs in (root):

```
adb push ./WhatsApp /data/local/tmp/   # from your backup folder
adb shell su -c 'cp -a /data/local/tmp/WhatsApp /data/user/0/com.whatsapp/'
adb shell su -c 'chown -R 10488:10488 /data/user/0/com.whatsapp'
```

```
adb push ./Signal /data/local/tmp/
adb shell su -c 'cp -a /data/local/tmp/Signal /data/user/0/org.thoughtcrime.securesms/'
adb shell su -c 'chown -R 10490:10490 /data/user/0/org.thoughtcrime.securesms'
```

4. Relaunch the apps — chats and media should be back.
5. **Critical WhatsApp DBs:** `msgstore.db` (chats) + `axolotl.db` (encryption keys) — without axolotl.db the chats are unreadable.

---

## 9️⃣ spes Gotchas (learned the hard way)

| Gotcha | Detail |
|---|---|
| 🔧 No separate recovery partition | Recovery lives in `boot` ramdisk — flashing recovery replaces the kernel |
| ⚠️ No `init_boot` partition | Magisk patches `boot` (like older devices) |
| 🎮 A13 = sweet spot for 4GB | crDroid 9.x ≈ 1.8GB free RAM, keeps PUBG + multitasking alive; A15/A16 ROMs are heavier and drop apps |
| 🎥 Video recording | WORKS on A13 (OMX encoders). **Broken on ALL A15/A16 ROMs** for spes (maintainer confirmed unfixable) |
| 🦊 OrangeFox R12.0 = final | JassiV007 stopped maintaining spes — keep a copy of the zip + recovery.img on your PC |
| 🔑 Firmware matters | Always flash current MIUI firmware zip BEFORE the ROM when coming from MIUI |
| 🔄 Keep "ReFlash OrangeFox" checked | If you want permanent OrangeFox — spes has no recovery partition to fall back to |