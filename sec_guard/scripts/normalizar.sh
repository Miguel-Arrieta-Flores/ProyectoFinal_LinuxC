#!/bin/bash

# Obtener la ruta absoluta del directorio donde vive este script (sec_guard/scripts)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Subir un nivel para apuntar siempre a la raíz del proyecto (sec_guard)
BASE_DIR="$(dirname "$SCRIPT_DIR")"

RAW_LOG="$BASE_DIR/capturas/telemetria_raw.log"
OUT_DIR="$BASE_DIR/preparados"
OUT_FILE="$OUT_DIR/mediciones_sec.txt"
ETIQUETA="AuditoriaCursoC"

# Validamos que exista el archivo de telemetria_raw.log
if [ ! -f "$RAW_LOG" ]; then
    echo "Error: El archivo de capturas '$RAW_LOG' no existe." >&2
    exit 1
fi

# Validamos que el directorio de salida exista
if [ ! -d "$OUT_DIR" ]; then
    echo "Error: El directorio '$OUT_DIR' no existe." >&2
    exit 1
fi

# Se extraen únicamente los campos CATEGORIA ($3) y VALOR ($4) de cada línea
# Se ignoran líneas en blanco en caso de existir
REGISTROS=$(awk 'NF >= 4 {print $3, $4}' "$RAW_LOG" 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "Error: Falló el procesamiento de texto sobre '$RAW_LOG'." >&2
    exit 1
fi

# Contamos exactamente cuántos registros válidos cumplen el patrón (CATEGORIA ENTERO)
if [ -z "$REGISTROS" ]; then
    TOTAL=0
else
    TOTAL=$(echo "$REGISTROS" | grep -c -E '^(DISCO|PROCESOS|PERMISOS) [0-9]+$')
fi

# Validamos que el total de registros esté dentro del intervalo permitido (0 a 200)
if [ "$TOTAL" -lt 0 ] || [ "$TOTAL" -gt 200 ]; then
    echo "Error: La cantidad de registros ($TOTAL) excede el límite permitido (0-200)." >&2
    exit 1
fi

# Se escribe el archivo normalizado y verificamos que se cree
{
    echo "$ETIQUETA"
    echo "$TOTAL"
    if [ "$TOTAL" -gt 0 ]; then
        echo "$REGISTROS"
    fi
} > "$OUT_FILE"

if [ $? -ne 0 ]; then
    echo "Error: No se pudo escribir el archivo normalizado en '$OUT_FILE'." >&2
    exit 1
fi

echo "Normalización completada con éxito: $TOTAL registros guardados en $OUT_FILE"
exit 0
