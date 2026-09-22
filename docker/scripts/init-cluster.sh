#!/usr/bin/env bash
# =========================================================================
# Inicialización automatizada de la infraestructura de geocodificación (POSIX)
# =========================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_DIR="${ROOT_DIR}/data"
ENV_FILE="${ROOT_DIR}/.env"

# 1. Comprobación de Docker
if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR TÉCNICO: 'docker' no se encuentra disponible en el PATH." >&2
    exit 1
fi

# 2. Configuración de variables
if [ ! -f "${ENV_FILE}" ]; then
    cp "${ROOT_DIR}/.env.example" "${ENV_FILE}"
    echo "[WARN] Generado archivo .env a partir de plantilla."
fi

# Cargar variables
set -a
source "${ENV_FILE}"
set +a

mkdir -p "${DATA_DIR}"
TARGET_PBF="${DATA_DIR}/${PBF_FILENAME}"

# 3. Descarga de datos
if [ ! -f "${TARGET_PBF}" ]; then
    echo "[INFO] Descargando extracto cartográfico desde ${OSM_PBF_URL}..."
    curl -L "${OSM_PBF_URL}" -o "${TARGET_PBF}"
    echo "[OK] Descarga completada."
else
    echo "[OK] Archivo binario PBF localizado en: ${TARGET_PBF}"
fi

# 4. Orquestación del contenedor
cd "${ROOT_DIR}"
docker compose up -d
echo "[OK] Contenedor desplegado. Monitoree el log de indexación mediante:"
echo "docker compose logs -f nominatim-engine"