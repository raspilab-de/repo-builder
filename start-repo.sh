#!/bin/bash
set -e

REPO_DIR=/repo
REBUILD_DELAY=20
DEB_MAX_AGE_DAYS=14

#  Alte .deb-Dateien bereinigen
echo "Entferne veraltete Pakete (älter als $DEB_MAX_AGE_DAYS Tage)..."
find "$REPO_DIR" -type f -name '*.deb' -mtime +$DEB_MAX_AGE_DAYS -exec rm -v {} \;

# Erstinitialisierung
/usr/local/bin/generate_deb_repo.sh

# Debounce-Logik
trigger_rebuild() {
    if [ -f /tmp/rebuild.lock ]; then
        # Schon geplant → nicht doppelt starten
        return
    fi

    touch /tmp/rebuild.lock
    echo "Rebuild in $REBUILD_DELAY Sekunden geplant..."
    (
        sleep "$REBUILD_DELAY"
        echo "Starte Rebuild..."
        /usr/local/bin/generate_deb_repo.sh
        rm -f /tmp/rebuild.lock
    ) &
}

# Watchdog: auf neue .deb-Dateien achten
echo "Beobachte Änderungen an .deb-Dateien unter $REPO_DIR..."
inotifywait -m -e create -e modify -e delete -r --format '%w%f' "$REPO_DIR" --exclude 'Packages(\..+)?|Release(\..+)?|apt-ftparchive.conf' |
while read changed_file; do
    [[ "$changed_file" == *.deb ]] && trigger_rebuild
done &

# Webserver starten
echo "Starte HTTP-Server..."
cd /www-root
exec python3 -m http.server 8000
