# Open WebUI — Web-Frontend für Ollama

Open WebUI ist eine ChatGPT-ähnliche Web-Oberfläche, die Ollama als Backend nutzt.
Beide laufen im gemeinsamen `n8n_backend`-Netzwerk — kein Port-Publish nötig.

## Abhängigkeiten

| Voraussetzung | Warum |
|---------------|-------|
| Ollama läuft | Open WebUI verbindet sich beim Start zu `http://ollama:11434` |
| `n8n_backend`-Netzwerk | Container-Kommunikation zu Ollama |
| `.env` befüllt | Secret Key, Ollama-URL |

> **Reihenfolge:** Ollama **muss** vor Open WebUI gestartet sein.

## Konfiguration (`.env`)

```env
OPEN_WEBUI_SECRET_KEY=32-zeichen-zufaellig    # openssl rand -hex 32
OLLAMA_API_BASE_URL=http://ollama:11434
```

## Starten

```bash
# Sicherstellen, dass Ollama läuft:
docker ps | grep ollama

# Open WebUI starten:
docker compose -f staging/docker-stacks/open-webui/docker-compose.yml up -d

# Logs prüfen:
docker logs -f open-webui
```

## Zugriff

Kein direkter Port-Zugriff. Zugang über VPS-Traefik → WireGuard-Tunnel:
`https://chat.deine-domain.tld` (Traefik-Route muss auf VPS konfiguriert sein)

Vom VM-Host aus (für Tests):

```bash
curl http://$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' open-webui):8080
```

## Modelle

Modelle werden in Ollama verwaltet, nicht in Open WebUI:

```bash
# Neue Modelle laden (Ollama-Container):
docker exec -it ollama ollama pull llama3.2
docker exec -it ollama ollama pull mistral
docker exec ollama ollama list
```

Open WebUI zeigt alle verfügbaren Ollama-Modelle automatisch in der Dropdown-Liste.

## Persistenz

| Volume | Inhalt |
|--------|--------|
| `open-webui` | Nutzerprofile, Chat-Verläufe, Einstellungen |

## Troubleshooting

```bash
# Open WebUI kann Ollama nicht erreichen?
docker exec open-webui curl -s http://ollama:11434/api/tags
# → Sollte JSON mit Modell-Liste zurückgeben

# Netzwerk-Check:
docker network inspect n8n_backend | grep -E "open-webui|ollama"

# Logs:
docker logs -f open-webui
```
