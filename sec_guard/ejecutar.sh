#!/bin/bash

# Obtener la ruta absoluta donde está guardado este script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Buscamos la carpeta sec_guard/
if [ "$(basename "$SCRIPT_DIR")" = "sec_guard" ]; then
    BASE_DIR="$SCRIPT_DIR"
elif [ "$(basename "$(dirname "$SCRIPT_DIR")")" = "sec_guard" ]; then
    BASE_DIR="$(dirname "$SCRIPT_DIR")"
else
    echo "Error crítico: No se pudo localizar el directorio raíz 'sec_guard'." >&2
    exit 1
fi

# Se definen las rutas del proyecto
TAR_FILE="$BASE_DIR/capturas/estaticos/paquete_auditoria.tar.gz"
ESTATICOS_DIR="$BASE_DIR/capturas/estaticos"
PREP_DIR="$BASE_DIR/preparados"
RES_DIR="$BASE_DIR/resultados"
INFORME="$RES_DIR/informe_seguridad.txt"
MEDICIONES="$PREP_DIR/mediciones_sec.txt"
CAPTURAR_SH="$BASE_DIR/scripts/capturar.sh"
NORMALIZAR_SH="$BASE_DIR/scripts/normalizar.sh"
SRC_C="$BASE_DIR/fuentes/sec_engine.c"
BIN_C="$BASE_DIR/fuentes/sec_engine"

echo "=================================================="
echo "   INICIANDO ORQUESTADOR DE AUDITORÍA SEC_GUARD   "
echo "=================================================="

# ------------------------------------------------------------------------------
# FASE 1: LIMPIEZA PREVENTIVA
# Elimina resultados, preparados y el binario previo para evitar falsos positivos
# ------------------------------------------------------------------------------
echo "[1/5] Ejecutando limpieza preventiva de artefactos previos..."
rm -f "$INFORME" "$MEDICIONES" \
      "$PREP_DIR/sshd_activo.txt" \
      "$PREP_DIR/usuarios_creados.txt" \
      "$PREP_DIR/conexiones_syn.txt" \
      "$BIN_C"

if [ $? -ne 0 ]; then
    echo "Error crítico: No se pudieron limpiar los archivos residuales." >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# FASE 2: VALIDACIÓN, EXTRACCIÓN Y PROCESAMIENTO DE
# ------------------------------------------------------------------------------
echo "[2/5] Validando y extrayendo paquete de auditoría..."

if [ ! -f "$TAR_FILE" ]; then
    echo "Error crítico: No se encuentra el archivo '$TAR_FILE'." >&2
    exit 1
fi

# Verificar integridad estructural antes de extraer
tar -tzf "$TAR_FILE" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Error crítico: El archivo '$TAR_FILE' está corrupto o no es un .tar.gz válido." >&2
    exit 1
fi

# Extraer contenido
tar -xzf "$TAR_FILE" -C "$ESTATICOS_DIR"
if [ $? -ne 0 ]; then
    echo "Error crítico: Falló la extracción de '$TAR_FILE'." >&2
    exit 1
fi

# Validar existencia de los 3 insumos esperados
if [ ! -f "$ESTATICOS_DIR/sshd_config" ] || [ ! -f "$ESTATICOS_DIR/secure.log" ] || [ ! -f "$ESTATICOS_DIR/net_traffic.log" ]; then
    echo "Error crítico: Faltan archivos requeridos tras la extracción (sshd_config, secure.log o net_traffic.log)." >&2
    exit 1
fi

# Procesar sshd_config -> preparados/sshd_activo.txt
sed -E -e 's/^#?Port [0-9]+/Port 8080/' -e 's/^#?(HostKey .*)/\1/' "$ESTATICOS_DIR/sshd_config" | grep -v -E '^[[:space:]]*#' | grep -v -E '^[[:space:]]*$' > "$PREP_DIR/sshd_activo.txt"
if [ $? -ne 0 ]; then
    echo "Error crítico: Falló el procesamiento de sshd_config." >&2
    exit 1
fi

# Procesar secure.log -> preparados/usuarios_creados.txt
grep "new user:" "$ESTATICOS_DIR/secure.log" | cut -d ']' -f 1 --complement | awk -F'[=,] *' '{print "Usuario:" $2 " UID:"$4" GID:"$6}' > "$PREP_DIR/usuarios_creados.txt"
if [ $? -ne 0 ]; then
    echo "Error crítico: Falló el procesamiento de secure.log." >&2
    exit 1
fi

# Procesar net_traffic.log -> preparados/conexiones_syn.txt
grep "Flags \[S\]" "$ESTATICOS_DIR/net_traffic.log" | sed -E 's/\.([0-9]+)( >|:)/:\1\2/g' | awk '{sub(/:$/, "", $4); print "Origen="$2 " -> Destino="$4}' > "$PREP_DIR/conexiones_syn.txt"
if [ $? -ne 0 ]; then
    echo "Error crítico: Falló el procesamiento de net_traffic.log." >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# FASE 3: CAPTURA Y NORMALIZACIÓN
# ------------------------------------------------------------------------------
echo "[3/5] Ejecutando captura y normalización de métricas..."

if [ ! -x "$CAPTURAR_SH" ]; then
    echo "Error crítico: '$CAPTURAR_SH' no existe o no tiene permisos de ejecución." >&2
    exit 1
fi

"$CAPTURAR_SH"
if [ $? -ne 0 ]; then
    echo "Error crítico: Falló la ejecución de capturar.sh. Abortando flujo." >&2
    exit 1
fi

if [ ! -x "$NORMALIZAR_SH" ]; then
    echo "Error crítico: '$NORMALIZAR_SH' no existe o no tiene permisos de ejecución." >&2
    exit 1
fi

"$NORMALIZAR_SH"
if [ $? -ne 0 ]; then
    echo "Error crítico: Falló la ejecución de normalizar.sh. Abortando flujo." >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# FASE 4: COMPILACIÓN CONTROLADA DEL MOTOR EN C
# ------------------------------------------------------------------------------
echo "[4/5] Compilando analizador en C con banderas de rigor..."

if [ ! -f "$SRC_C" ]; then
    echo "Error crítico: No se encuentra el código fuente '$SRC_C'." >&2
    exit 1
fi

gcc -Wall -Wextra -pedantic -std=c99 "$SRC_C" -o "$BIN_C"
if [ $? -ne 0 ]; then
    echo "Error crítico: La compilación de sec_engine.c arrojó errores. Abortando sin ejecutar." >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# FASE 5: EJECUCIÓN DEL ANALIZADOR Y GENERACIÓN DEL INFORME
# ------------------------------------------------------------------------------
echo "[5/5] Ejecutando sec_engine para generar informe final..."

"$BIN_C" "$MEDICIONES" "$INFORME"
if [ $? -ne 0 ]; then
    echo "Error crítico: sec_engine detectó una anomalía durante el análisis y abortó." >&2
    exit 1
fi

if [ ! -f "$INFORME" ]; then
    echo "Error crítico: El proceso finalizó pero no se generó '$INFORME'." >&2
    exit 1
fi

echo "=================================================="
echo "          COMPLETADO EXITOSAMENTE             "
echo "   Informe disponible en: $BASE_DIR/resultados/informe_seguridad.txt"
echo "=================================================="
exit 0
