# Crash diagnosis: spotifydl (PID 87663)

Date: Wed 2026-08-19, 07:39:11 +06 — Omarchy machine (hostname `omarchy`)

## What crashed

`spotifydl embedded https://open.spotify.com/playlist/3ymBnAz3AzGJrTh1pyDnRQ?si=38d825cc780549d3`

The tool was downloading a Spotify playlist in parallel (dozens of tokio worker
threads; ~30 MP3s landing in `~/Music/Spotify/`). One worker thread
(`tokio-rt-worker`, TID 87670) panicked and aborted the whole process.

- Signal: SIGABRT (6), si_code SI_TKILL
- Binary: /usr/bin/spotifydl (package `spotifydl 1.0.0-1`, github.com/bjn7/spotifydl)
- Built with Rust `panic = "abort"` (confirmed via `library/panic_abort` string in binary)

## Mechanism (proven from the core dump)

Panic message embedded in core:

```
thread 'tokio-rt-worker' (87670) panicked at src/download.rs:104:70:
called `Result::unwrap()` on an `Err` value: error sending request for url
  (https://i.scdn.co/image/ab67616d00001e02af9a38064dc3cc873ad7bf72)
Caused by:
    0: client error (Connect)
    1: received fatal alert: InternalError
```

- While fetching an **album-cover image** from Spotify's CDN, the request failed.
  `received fatal alert: InternalError` (TLS alert 80) means the TLS handshake
  failed — server- or network-side, not local misconfiguration.
- spotifydl unwraps that network Result (`src/download.rs:104`), and with
  `panic=abort` a recoverable network failure becomes a hard SIGABRT that kills
  the entire batch.

## Ruled out

- Not resource exhaustion: 6.8 GiB available, swap unused, no OOM kills in journal.
- One-off crash: no prior `spotifydl` coredumps in `coredumpctl list`.
- Not an Omarchy bug: the cause sits entirely inside the third-party `spotifydl`
  application. Correct upstream for a report: https://github.com/bjn7/spotifydl

## Data loss

None. All fully-downloaded MP3s are intact. A few in-flight downloads were
interrupted, leaving **0-byte placeholder files** in `~/Music/Spotify/` (e.g.
`passion - Speed Up - silent anthem.mp3`, `algo mudou dentro de mim - JHONS
REDGOLIO QUERIDA.mp3`). Delete them; a re-run re-downloads.

## Recurrence

Likely — every time a CDN request fails mid-download, the `unwrap()` panics and
`panic=abort` kills the process. Workaround: re-run spotifydl after a transient
network blip.

## Notes

- Core was extracted to a fresh mktemp path for gdb symbolization and deleted
  afterwards; debuginfod did not resolve symbols (no debug package). The panic
  message was recovered by searching the core with `strings`.
- Panic message not in the journal (process ran from a terminal, output went to
  the terminal, not the journal).