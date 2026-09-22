# Módulo de Infraestructura Geoespacial Local (Nominatim + PostGIS)

Este módulo provee la definición de infraestructura contenerizada para desplegar un motor de geocodificación inversa local de alta velocidad, eliminando dependencias de APIs externas y evitando bloqueos por *rate limiting* (HTTP 403 Forbidden).

## Requerimientos de Hardware

| Recurso | Mínimo (Entorno Pruebas) | Recomendado (Producción / Lotes Masivos) |
| :--- | :--- | :--- |
| **RAM** | 8 GB | 16 GB - 64 GB |
| **Almacenamiento** | 10 GB (SSD/NVMe) | 25 GB (SSD NVMe) |
| **CPU** | 4 núcleos | 8+ núcleos |
| **Virtualización**| WSL 2 (Windows) / KVM (Linux)| WSL 2 con `.wslconfig` optimizado |

## Inicialización Rápida

### En Windows (PowerShell)
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
.\scripts\init-cluster.ps1