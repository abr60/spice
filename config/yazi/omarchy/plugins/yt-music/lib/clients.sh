# shellcheck shell=bash

# Shared managed CLIamp client selection for runtime helpers.

cliamp_managed_clients_json() {
  local clients_json="${1:-[]}"

  jq -c '
    [
      .[]
      | select(
          .class | contains("music.youtube.com")
        )
    ]
  ' <<<"$clients_json"
}
