# 🛡️ sec_guard — Sistema Integral de Auditoría de Seguridad en Linux y C

Proyecto final de administración de sistemas Linux y programación en C. `sec_guard` automatiza la extracción y normalización de registros estáticos de seguridad, captura métricas del sistema en tiempo real, gestiona ciclos de vida de procesos en segundo plano y procesa los datos mediante un motor estadístico escrito en C estándar (`C99`).

---

## 📁 Estructura de Directorios

El proyecto sigue la jerarquía reflejada en el árbol de trabajo (`sec_guard/`):

```text
sec_guard/
├── capturas/
│   ├── estaticos/
│   │   ├── net_traffic.log           # Volcado de tráfico de red (tcpdump)
│   │   ├── paquete_auditoria.tar.gz  # Archivo comprimido con insumos base
│   │   ├── secure.log                # Bitácora de eventos de autenticación y usuarios
│   │   └── sshd_config               # Configuración del demonio SSH
│   └── telemetria_raw.log            # Registro acumulativo de métricas en vivo
├── ejecutar.sh                       # Script orquestador principal del flujo completo
├── enlace_pruebas -> evidencias/pruebas/ # Enlace simbólico hacia evidencias de prueba
├── evidencias/
│   ├── link_record.txt               # Verificación de inodos y enlaces (duros y simbólicos)
│   ├── permissions.txt               # Registro de auditoría y ajuste de permisos
│   └── pruebas/
│       ├── admin_process.txt         # Documentación automatizada de señales (STOP/CONT/TERM)
│       ├── hardlink.txt              # Enlace duro de prueba vinculado a archivo original
│       └── prueba_doc_nuevo.txt      # Archivo base para pruebas de enlaces e inodos
├── fuentes/
│   ├── sec_engine                    # Binario compilado del analizador en C
│   └── sec_engine.c                  # Código fuente del motor de análisis estadístico
├── preparados/
│   ├── conexiones_syn.txt            # Pares IP:Puerto origen/destino filtrados (Flags [S])
│   ├── mediciones_sec.txt            # Dataset normalizado listo para consumo en C
│   ├── sshd_activo.txt               # Directivas activas de SSH sin comentarios ni líneas vacías
│   └── usuarios_creados.txt          # Reporte normalizado de altas de usuario (UID/GID)
├── resultados/
│   └── informe_seguridad.txt         # Reporte final generado por el programa en C
└── scripts/
    ├── capturar.sh                   # Recolección y validación de métricas en vivo
    └── normalizar.sh                 # Limpieza y formateo de mediciones_sec.txt
```

---

## ⚙️ Instrucciones de Compilación y Ejecución

Todos los scripts cuentan con resolución dinámica de rutas (`BASH_SOURCE[0]`), por lo que pueden invocarse desde la raíz `sec_guard/` o desde cualquier ruta externa sin romper referencias relativas.

### 1. Ejecución automatizada (Flujo completo)
Otorga permisos de ejecución (si aún no los tienen) y ejecuta el orquestador principal desde la raíz del proyecto:

```bash
chmod +x ejecutar.sh scripts/capturar.sh scripts/normalizar.sh
./ejecutar.sh
```
Este comando realiza automáticamente: limpieza preventiva, validación y extracción de `paquete_auditoria.tar.gz`, procesamiento de logs estáticos, captura y normalización de métricas en vivo, compilación estricta en C, ejecución del motor de análisis y documentación de procesos en segundo plano.

### 2. Ejecución manual paso a paso (Opcional)

* **Capturar métricas actuales del sistema:**
  ```bash
  ./scripts/capturar.sh
  ```
* **Normalizar el historial de capturas:**
  ```bash
  ./scripts/normalizar.sh
  ```
* **Compilar el motor de análisis en C manualmente:**
  ```bash
  gcc -Wall -Wextra -Werror -pedantic -std=c99 fuentes/sec_engine.c -o fuentes/sec_engine
  ```
* **Ejecutar el analizador sobre los datos preparados:**
  ```bash
  ./fuentes/sec_engine preparados/mediciones_sec.txt resultados/informe_seguridad.txt
  ```

---

## 📄 Descripción de Archivos Principales

* **`ejecutar.sh`**: Orquestador central con validación explícita de códigos de retorno (`$?`). Verifica integridad de paquetes comprimidos, permisos de ejecución y errores de compilación antes de avanzar entre fases.
* **`scripts/capturar.sh`**: Extrae la ocupación de disco del sistema de archivos de `$HOME` (`df -P`), cuenta los procesos activos del usuario (`ps`) y audita archivos regulares con permisos de escritura para grupo u otros (`find ... -perm -020 -o -perm -002`).
* **`scripts/normalizar.sh`**: Filtra `capturas/telemetria_raw.log` mediante `awk` para extraer únicamente `CATEGORIA VALOR`, anteponiendo la etiqueta `AuditoriaCursoC` y el conteo total de registros.
* **`fuentes/sec_engine.c`**: Programa en C que valida la cabecera del archivo de entrada, reserva/estructura registros por categoría (`DISCO`, `PROCESOS`, `PERMISOS`), calcula promedios y conteo de alertas según umbrales de seguridad, y emite `resultados/informe_seguridad.txt`.
* **`evidencias/pruebas/admin_process.txt`**: Bitácora generada automáticamente que documenta el PID, las señales enviadas (`SIGSTOP`, `SIGCONT`, `SIGTERM`) y la verificación de estados (`S` $\rightarrow$ `T` $\rightarrow$ `S` $\rightarrow$ finalizado) de un proceso auxiliar de bajo impacto.

---

## 💡 Respuestas Breves a las Preguntas de Cada Etapa

### Etapa 1: Arquitectura, Enlaces e Inodos
* **¿Qué diferencia existe a nivel de inodo y persistencia entre un enlace duro (*hard link*) y un enlace simbólico (*soft link*)?**
  Un enlace duro apunta directamente al mismo número de inodo y bloques de datos en disco que el archivo original; si el archivo original se borra o mueve dentro de la misma partición, los datos siguen accesibles. En cambio, un enlace simbólico posee su propio inodo y almacena únicamente la ruta textual hacia el destino; si el objetivo original se elimina o cambia de ubicación, el enlace simbólico queda roto (*dangling link*).

### Etapa 2: Extracción y Normalización de Logs
* **¿Por qué se utiliza `tar -tzf` antes de descomprimir `paquete_auditoria.tar.gz`?**
  Permite inspeccionar y validar la integridad estructural del archivo comprimido sin extraer nada en disco, evitando sobreescribir o corromper archivos existentes si el paquete está dañado.
* **¿Cómo se separan las direcciones IP (IPv4 e IPv6) de sus puertos en `net_traffic.log` sin alterar los octetos internos?**
  Mediante `sed -E 's/\.([0-9]+)( >|:)/:\1\2/g'`, que identifica exclusivamente el último punto seguido de dígitos justo antes de los delimitadores de dirección (` >` o `:`) y lo reemplaza por dos puntos (`:`), preservando intactos tanto los cuatro octetos IPv4 como los bloques hexadecimales IPv6.

### Etapa 3: Telemetría, Permisos y Motor en C
* **¿Por qué `find` agrupa `-perm -020 -o -perm -002` entre paréntesis escapados `\( ... \)`?**
  Para evaluar ambas condiciones de permisos (escritura para grupo `020` **o** escritura para otros `002`) sobre cada archivo regular (`-type f`) como una sola unidad lógica, garantizando que un archivo con ambos permisos activos se contabilice una sola vez.
* **¿Por qué se pasan las estructuras por referencia (`&st_disco`) hacia las funciones en C?**
  Para pasar la dirección de memoria real de la estructura (`StatsCategoria *`) en lugar de una copia por valor, permitiendo modificar directamente sus acumuladores internos (`suma`, `conteo`, `alertas`) mediante el operador flecha (`->`) y optimizando el uso de memoria.

### Etapa 4: Orquestación, Tolerancia a Fallos y Procesos
* **¿Cómo garantiza el orquestador que no se generen falsos positivos tras un error de permisos o compilación?**
  Al inicio de cada corrida ejecuta una limpieza preventiva (`rm -f`) que elimina informes previos, archivos preparados y el binario compilado `fuentes/sec_engine`. Posteriormente valida cada paso (`if [ ! -x ... ]`, `if ! gcc ...`) abortando con `exit 1` ante cualquier fallo, lo que impide que sobrevivan resultados o ejecutables de ejecuciones anteriores.
* **¿Qué estados atraviesa el proceso auxiliar en segundo plano durante la prueba de señales?**
  Al lanzarse en segundo plano (`sleep 600 &`) inicia en estado **`S`** (*Interruptible Sleep*); al recibir `SIGSTOP` pasa a estado **`T`** (*Stopped*); al recibir `SIGCONT` reanuda su ejecución volviendo a **`S`**; y finalmente con `SIGTERM` libera sus recursos y desaparece de la tabla de procesos.