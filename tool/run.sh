#!/usr/bin/env bash
set -euo pipefail

config="config/supabase.json"
if [[ ! -f "$config" ]]; then
  echo "Configuration Supabase absente: $config" >&2
  echo "Copie config/supabase.example.json vers $config puis renseigne tes valeurs." >&2
  exit 1
fi

if [[ $# -gt 0 ]]; then
  exec flutter run -d "$1" --dart-define-from-file="$config"
fi

exec flutter run --dart-define-from-file="$config"
