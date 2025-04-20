FROM python:3.11-slim

# Tools installieren
RUN apt-get update && apt-get install -y \
    dpkg-dev apt-utils xz-utils bzip2 lzma inotify-tools \
    && rm -rf /var/lib/apt/lists/*

# Arbeitsverzeichnis im Container
WORKDIR /repo

# Skript in Container kopieren
COPY start-repo.sh /usr/local/bin/start-repo.sh
COPY generate_deb_repo.sh /usr/local/bin/generate_deb_repo.sh

RUN chmod +x /usr/local/bin/start-repo.sh /usr/local/bin/generate_deb_repo.sh

# Startbefehl: Repository generieren und Webserver starten
CMD ["/usr/local/bin/start-repo.sh"]
