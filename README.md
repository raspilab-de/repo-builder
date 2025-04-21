# Yocto APT-Repository Builder

Dieses Repository stellt Skripte und Konfigurationsdateien bereit, mit denen aus Yocto-erzeugten Debian-Paketen ein vollständig Debian-kompatibles APT-Repository aufgebaut werden kann. Dabei werden:

- alle .deb-Pakete aus einem Yocto-Output-Verzeichnis (`REPO_BASE`) in einen Pool (`pool/main`) verlinkt
- pro Architektur individuelle Paketindizes (`Packages`, `Packages.gz`, `Packages.bz2`, `Packages.xz`, `Packages.lzma`) erzeugt
- für jede Architektur ein Verzeichnis unter `dists/stable/main/binary-<arch>` aufgebaut
- eine zentrale `Release`-Datei generiert

Optional steht eine Docker-Umgebung zur Verfügung, die das Repo lokal per HTTP-Server bereitstellt und automatische Rebuilds bei Paketänderungen unterstützt.

## Features

- Debian-konformes Layout unter `dists/` und `pool/`
- Automatisches Mapping Yocto‑Architekturen → Debian-Architekturen (z. B. `cortexa72` → `arm64`)
- Architektur-spezifische Indizes (nur passende Pakete in jeder `Packages`-Datei)
- Unterstützung mehrerer Distributionen (Variable `DIST`, z. B. `stable`, `testing`)
- Optionale Docker-Integration mit Inotify-basiertem Watchdog und Healthcheck

## Voraussetzungen

- Unix-ähnliches Betriebssystem (Linux)
- Bash-Shell
- `dpkg-scanpackages` und `apt-ftparchive` (z. B. über `apt-get install dpkg-dev apt-utils`)
- Verzeichnisstruktur:
  - Yocto-Pakete in `REPO_BASE/<arch>/*.deb`
  - Schreibrechte im Webroot `WEBROOT`

## Skripte

### generate_deb_repo.sh

Erzeugt das APT-Repository unter `WEBROOT`:

1. Leert `dists/<DIST>` und `pool/<COMPONENT>`
2. Verlinkt aktuelle `.deb`-Pakete in `pool/main`
3. Ermittelt vorhandene Architekturen aus Dateinamen
4. Erzeugt pro Architektur einen eigenen Index im `dists/<DIST>/<COMPONENT>/binary-<arch>`
5. Komprimiert die Indizes (gz, bz2, xz, lzma)
6. Generiert die zentrale `Release`-Datei

Konfiguration über Variablen am Skriptanfang:

```bash
REPO_BASE=/repo          # Ort der Yocto-pool-Ordner
WEBROOT=/www-root        # Ziel-Repository
DIST=stable              # Distribution (Suite)
COMPONENT=main           # Component
```

### start-repo.sh und rebuild-repo.sh (optional)

- `start-repo.sh`: Initialisiert das Repository, startet `inotifywait`-Watchdog und den HTTP-Server
- `rebuild-repo.sh`: Führt Nur-Repo-Erstellung ohne Watchdog aus (zur manuellen Verwendung)

## Docker-Integration (Beispiel)

In `Dockerfile` und `docker-compose.yml` wird:

- Ein Python-HTTP-Server als Webserver verwendet
- `inotify-tools` installiert, um Änderungen im Yocto-Pool zu erkennen
- Healthcheck definiert, der auf die Root-URL zugreift
- Volume-Mounts für `REPO_BASE` und `WEBROOT` gesetzt

## Nutzung

Manuell:

```bash
# Repository neu erstellen
./generate_deb_repo.sh

# Anschließend:
cd $WEBROOT
python3 -m http.server 8000
```

Mit Docker Compose:

```bash
docker-compose up -d
# Healthcheck: docker ps zeigt (healthy)
```

Auf dem Zielsystem (Raspberry Pi):

```bash
echo 'deb [trusted=yes] http://<host>:8000 stable main' \
  > /etc/apt/sources.list.d/raspilab.list
apt update
apt install <paket>
```

## Lizenz

MIT License. Siehe LICENSE im Repository.

## Mitwirken

Beiträge, Fehlerberichte und Wünsche sind jederzeit willkommen. Bitte einen Merge-Request oder Issue eröffnen.
