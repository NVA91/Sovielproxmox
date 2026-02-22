# Authelia — Lokale Instanz (optional)

> **Hinweis:** Die primäre Authelia-Instanz läuft auf dem **VPS** und ist für alle
> externen Zugriffe zuständig. Diese lokale Instanz ist nur dann nötig, wenn
> VM-interne Dienste eine eigene Auth-Ebene benötigen.

## Wann sinnvoll?

- Wenn n8n oder Open WebUI VM-intern hinter einer eigenen Auth laufen sollen
  (ohne VPS-Authelia zu belasten)
- Als Fallback wenn VPS nicht erreichbar ist (Tunnel-Ausfall)

## Abhängigkeiten

- Docker-Netzwerk `n8n_backend` muss existieren
- Redis ist in der Compose-Datei enthalten (kein externes Redis nötig)
- Kein Port-Publish — nur intern via `n8n_backend` erreichbar (`http://authelia-local:9091`)

## Setup

### 1. Konfigurationsdatei erstellen

```bash
cp config/configuration.yml.example config/configuration.yml
nano config/configuration.yml   # Domain, SMTP, etc. anpassen
```

### 2. Nutzerdatenbank anlegen

```bash
cat > config/users_database.yml << 'EOF'
users:
  admin:
    displayname: "Admin"
    # Passwort-Hash generieren: docker run authelia/authelia:latest authelia hash-password 'deinpasswort'
    password: "$argon2id$v=19$m=65536,t=3,p=4$HASH_HIER"
    email: admin@deine-domain.tld
    groups:
      - admins
      - users
EOF
chmod 600 config/users_database.yml
```

### 3. Starten

```bash
docker compose up -d

# Logs prüfen:
docker logs -f authelia-local
```

## Wichtige Pfade im Container

| Pfad | Inhalt |
|------|--------|
| `/config/configuration.yml` | Hauptkonfiguration |
| `/config/users_database.yml` | Nutzerverwaltung (file backend) |
| `/data/db.sqlite3` | Authelia-Datenbank (Sessions, TOTP, etc.) |
| `/data/notification.txt` | Benachrichtigungen (falls kein SMTP) |

## Troubleshooting

```bash
# Container-Status
docker ps | grep authelia

# Detaillierte Logs
docker logs authelia-local 2>&1 | tail -50

# Konfiguration validieren
docker exec authelia-local authelia validate-config
```

## Sicherheitshinweise

- `config/configuration.yml` enthält keine Secrets (die kommen aus `.env`)
- `config/users_database.yml` enthält Passwort-Hashes — **nicht ins Repo** (in `.gitignore`)
- Alle Secrets (JWT_SECRET, SESSION_SECRET, STORAGE_ENCRYPTION_KEY) in `.env` eintragen
