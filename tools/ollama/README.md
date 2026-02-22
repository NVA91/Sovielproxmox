# Ollama

LLM-Server mit GPU-Passthrough für lokale KI-Modelle.

## Voraussetzungen

1. NVIDIA Container Toolkit auf der VM installiert
2. Docker-Netzwerk `n8n_backend` existiert
3. `.env`-Datei im Repo-Root befüllt (aus `.env.example`)

### GPU-Test

```bash
docker run --rm --gpus all nvidia/cuda:12.0-base-ubuntu22.04 nvidia-smi
```

### Netzwerk erstellen (einmalig)

```bash
docker network create n8n_backend
```

## Start

```bash
docker compose up -d
```

## Modelle laden

```bash
# Interaktiv im Container
docker exec -it ollama ollama pull llama3.2
docker exec -it ollama ollama pull mistral

# Verfügbare Modelle anzeigen
docker exec -it ollama ollama list
```

## Zugriff

Kein direkter Port-Zugriff von außen — nur über das `n8n_backend`-Netzwerk:

- Intern (andere Container): `http://ollama:11434`
- Vom VM-Host aus (für Tests): `docker exec -it ollama curl http://localhost:11434/api/tags`

## Logs

```bash
docker logs -f ollama
```
