#!/usr/bin/env bash

# Path to local custom PNG icons in your spice repo
ICON_DIR="$HOME/spice/applications/icons"

# ==============================================================================
# AI & LLM Services
# ==============================================================================
omarchy-webapp-install "Claude" "https://claude.ai/" ""
omarchy-webapp-install "DeepSeek" "https://chat.deepseek.com/" ""
omarchy-webapp-install "Gemini" "https://gemini.google.com/app" ""
omarchy-webapp-install "Grok" "https://grok.com/" ""
omarchy-webapp-install "Notebook LLM" "https://notebooklm.google.com/" "$ICON_DIR/notebook-llm.png"
omarchy-webapp-install "Vive" "https://chat.mistral.ai/chat" ""

# ==============================================================================
# Economics & Education
# ==============================================================================
omarchy-webapp-install "EconGraphs" "https://www.econgraphs.org/" ""
omarchy-webapp-install "Macro Econ" "https://saylordotorg.github.io/text_macroeconomics-theory-through-applications/" "$ICON_DIR/macro-econ.png"
omarchy-webapp-install "Micro Econ" "https://saylordotorg.github.io/text_microeconomics-theory-through-applications/index.html" "$ICON_DIR/micro-econ.png"
omarchy-webapp-install "OpenCourseWare (MIT)" "https://ocw.mit.edu/" ""

# ==============================================================================
# Office & Productivity
# ==============================================================================
omarchy-webapp-install "Excel" "https://excel.cloud.microsoft/" ""
omarchy-webapp-install "MS Word" "https://word.cloud.microsoft/" ""
omarchy-webapp-install "GitHub" "https://github.com/abr60/spice" ""

# ==============================================================================
# Social & Communication
# ==============================================================================
omarchy-webapp-install "Facebook" "https://www.facebook.com/" "$ICON_DIR/facebook.png"
omarchy-webapp-install "Messenger" "https://www.facebook.com/messages/e2ee/t/7674688255962884" "$ICON_DIR/messenger.png"
omarchy-webapp-install "Reddit" "https://www.reddit.com/" "$ICON_DIR/reddit.png"

# ==============================================================================
# Media & Entertainment
# ==============================================================================
omarchy-webapp-install "Wallhaven" "https://wallhaven.cc/" ""
omarchy-webapp-install "YT Music" "https://music.youtube.com/" ""

# ==============================================================================
# Media Servers & Downloads (self-hosted *arr stack)
# ==============================================================================
omarchy-webapp-install "Jellyfin" "http://localhost:8096/" "$ICON_DIR/jellyfin.png"
omarchy-webapp-install "Radarr" "http://localhost:7878/" ""
omarchy-webapp-install "Sonarr" "http://localhost:8989/" ""
omarchy-webapp-install "qBittorrent" "http://localhost:8080/" "$ICON_DIR/qbittorrent.png"
omarchy-webapp-install "Prowlarr" "http://localhost:9696/" ""

# ==============================================================================
# Omarchy & Plugins
# ==============================================================================
omarchy-webapp-install "Omarchy Plugins" "https://omarchyplugins.com/" ""