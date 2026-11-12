#!/bin/bash

# Obtener la ruta absoluta del directorio donde vive este script (sec_guard/scripts)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Subir un nivel para apuntar siempre a la raíz del proyecto (sec_guard)
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# USAMOS $BASE_DIR en lugar de rutas relativas sueltas
RAW_LOG="$BASE_DIR/capturas/telemetria_raw.log"
FECHA_HORA=$(date "+%Y-%m-%d %H:%M:%S")

# VerificaMOS que el directorio capturas exista en la raíz del proyecto
if [ ! -d "$BASE_DIR/capturas" ]; then
    echo "Error: El directorio '$BASE_DIR/capturas' no existe." >&2
    exit 1
fi

# CAPTURA DE DISCO
DISCO_VAL=$(df -P "$HOME" 2>/dev/null | tail -n 1 | awk '{print $5}' | tr -d '%')
# Validamos que el comando haya tenido éxito, que la variable no esté vacía y sea un entero entre 0 y 100
if [ -z "$DISCO_VAL" ] || ! [[ "$DISCO_VAL" =~ ^[0-9]+$ ]] || [ "$DISCO_VAL" -lt 0 ] || [ "$DISCO_VAL" -gt 100 ]; then
    echo "Error: Falló la captura de DISCO o el valor obtenido ('$DISCO_VAL') es inválido." >&2
    exit 1
fi

# CAPTURA DE PROCESOS
PROCESOS_VAL=$(ps -u "$USER" --no-headers 2>/dev/null | wc -l)
# Validamos que sea un entero válido entre 0 y 2000
if [ -z "$PROCESOS_VAL" ] || ! [[ "$PROCESOS_VAL" =~ ^[0-9]+$ ]] || [ "$PROCESOS_VAL" -lt 0 ] || [ "$PROCESOS_VAL" -gt 2000 ]; then
    echo "Error: Falló la captura de PROCESOS o el valor obtenido ('$PROCESOS_VAL') es inválido." >&2
    exit 1
fi

# CAPTURA DE PERMISOS
PERMISOS_VAL=$(find "$BASE_DIR" -type f \( -perm -020 -o -perm -002 \) 2>/dev/null | wc -l)
# Validamos que sea un entero válido entre 0 y 200
if [ -z "$PERMISOS_VAL" ] || ! [[ "$PERMISOS_VAL" =~ ^[0-9]+$ ]] || [ "$PERMISOS_VAL" -lt 0 ] || [ "$PERMISOS_VAL" -gt 200 ]; then
    echo "Error: Falló la captura de PERMISOS o el valor obtenido ('$PERMISOS_VAL') es inválido." >&2
    exit 1
fi

# GUARDADO EN EL REGISTRO
{
    echo "$FECHA_HORA DISCO $DISCO_VAL"
    echo "$FECHA_HORA PROCESOS $PROCESOS_VAL"
    echo "$FECHA_HORA PERMISOS $PERMISOS_VAL"
} >> "$RAW_LOG"

if [ $? -ne 0 ]; then
    echo "Error: No se pudo escribir en el archivo $RAW_LOG." >&2
    exit 1
fi

echo "Captura realizada con éxito ($FECHA_HORA): DISCO=$DISCO_VAL%, PROCESOS=$PROCESOS_VAL, PERMISOS=$PERMISOS_VAL"
exit 0
