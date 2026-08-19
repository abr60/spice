# Proton VPN

An Omarchy Quattro shell plugin for Proton VPN. Connect by country, city, or specific
server, jump to the fastest server, manage Proton VPN settings, and sign in — all from
the bar, without touching the terminal.

Built on top of the official [Proton VPN Linux CLI](https://protonvpn.com/support/linux-cli).

## Features

- Bar icon showing the real Proton VPN mark, dimmed when disconnected
- One-click connect to the fastest server
- Search and pick a country, then a city, then a specific server — each pick just
  updates the selection, nothing connects until you press **Connect**
- Free-tier servers are labeled inline (`US-FREE#120 · Free — 83% load`)
- Live connection stats: uptime, tunnel IP, download/upload rate and totals
- Settings page (gear icon) for NetShield, Kill Switch, VPN Accelerator, Moderate NAT,
  Port Forwarding, IPv6, Anonymous Crash Reports, and Custom DNS
- Sign in without CLI knowledge: enter your email, and a terminal opens running
  `protonvpn signin` for you to enter your password (and 2FA, if any) — it closes
  itself once you're done
- Sign out (with confirmation) from the settings page

## Requirements

- The official Proton VPN CLI: `sudo pacman -S proton-vpn-cli` (Arch/Omarchy)
- `jq`, `nmcli`, and `ip` (all standard on Omarchy)
- **Cannot run alongside the Proton VPN GUI app.** If `proton-vpn-gtk-app` is
  installed, remove it first: `sudo pacman -Rns proton-vpn-gtk-app`

## Install

```sh
omarchy plugin add https://github.com/nameless312/protonvpn-plugin-omarchy.git --enable
```

## Usage

Click the Proton VPN icon in the bar to open the panel:

- Not signed in? Enter your email and press **Log In** — finish signing in in the
  terminal that opens.
- **Fastest** connects immediately to the best available server.
- Pick a country, city, and/or specific server, then press **Connect**.
- Click the gear icon for VPN settings and sign out.

## Configure

```sh
omarchy bar move io.github.nameless312.protonvpn --section right
```

## Remove

```sh
omarchy plugin remove io.github.nameless312.protonvpn
```
