#!/usr/bin/env python3
"""Capture Noctalia GUI preferences, keeping weather location on this machine."""

from pathlib import Path
import re
import tomllib


HEADER = '''{{- $settings := dict -}}
{{- $path := joinPath .chezmoi.destDir ".local/state/noctalia/settings.toml" -}}
{{- if stat $path -}}
{{- $settings = include $path | fromToml -}}
{{- end -}}
'''
LOCATION = '''{{ if hasKey $settings "location" -}}
[location]
{{ index $settings "location" | toToml }}
{{ end -}}
'''


def main():
    home = Path.home()
    current = home / ".local/state/noctalia/settings.toml"
    text = current.read_text()
    settings = tomllib.loads(text)
    if "{{" in text or "}}" in text:
        raise SystemExit("Settings contain template delimiters; review them manually.")

    # Noctalia writes this top-level table with numeric coordinates. Do not
    # copy these values into Git; the template reads the destination's table.
    pattern = r"(?ms)^\[location\]\n.*?(?=^\[|\Z)"
    without_location, count = re.subn(pattern, "", text)
    if count > 1 or ("location" in settings and count != 1):
        raise SystemExit("Unexpected location table format; no source file changed.")
    if "location" in tomllib.loads(without_location):
        raise SystemExit("Location was not fully removed; no source file changed.")

    if count:
        text = re.sub(pattern, lambda _: LOCATION, text)
    else:
        text = text.rstrip() + "\n\n" + LOCATION
    text = HEADER + text.replace(str(home), "{{ .chezmoi.homeDir }}")

    root = Path(__file__).resolve().parents[1]
    target = root / "private_dot_local/state/noctalia/settings.toml.tmpl"
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_suffix(".tmp")
    temporary.write_text(text)
    temporary.replace(target)
    print("Captured Noctalia preferences; weather location remains local.")
    print("Review with: chezmoi diff; chezmoi git diff")


if __name__ == "__main__":
    main()
