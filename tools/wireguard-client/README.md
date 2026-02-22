# WireGuard Client

VPN-Verbindung vom VM-Host zum VPS (Tunnel-Endpunkt).

## Nativ vs. Dockerisiert

### Empfehlung: Nativ (direkt auf der VM)

Wenn WireGuard nativ installiert ist, läuft es stabiler und
hat weniger Overhead als die Docker-Variante.

```bash
# Status prüfen
wg show

# Verbindung testen (Ping zum VPS im Tunnel)
ping 10.8.0.1

# Interface neu starten
sudo systemctl restart wg-quick@wg0
```

Die Konfigurationsdatei liegt unter `/etc/wireguard/wg0.conf`.
Vorlage: `wg0.conf.example` in diesem Verzeichnis.

### Alternative: Dockerisiert (linuxserver/wireguard)

Nur nutzen, falls WireGuard nicht nativ installiert werden kann.

```bash
# Echte Config bereitstellen (einmalig, NICHT aus Repo!)
sudo cp /pfad/zur/echten/wg0.conf /etc/wireguard/wg0.conf
sudo chmod 600 /etc/wireguard/wg0.conf

# Container starten
docker compose up -d

# Tunnel-Status prüfen
docker exec wireguard-client wg show
```

## Konfiguration erstellen

```bash
# Schlüsselpaar generieren
wg genkey | tee privatekey | wg pubkey > publickey

# Private Key (nur lokal speichern!)
cat privatekey

# Public Key (an VPS-Admin weitergeben)
cat publickey
```

## Troubleshooting

```bash
# Logs
docker logs -f wireguard-client        # oder: journalctl -u wg-quick@wg0 -f

# Verbindungstest
ping 10.8.0.1                           # VPS-Tunnel-IP

# Route prüfen
ip route show
```
