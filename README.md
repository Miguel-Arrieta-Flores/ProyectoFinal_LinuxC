# 🛡️ sec_guard — Sistema Integral de Auditoría de Seguridad en Linux y C

Proyecto final de administración de sistemas Linux y programación en C. `sec_guard` automatiza la extracción y normalización de registros estáticos de seguridad, captura métricas del sistema en tiempo real, gestiona ciclos de vida de procesos en segundo plano y procesa los datos mediante un motor estadístico escrito en C.

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
│   ├── permissions.txt               # Registro de auditoría y ajuste de permisos
│   └── pruebas/
│       ├── admin_process.txt         # Documentación automatizada de señales (STOP/CONT/TERM)
│       ├── hardlink.txt              # Enlace duro de prueba vinculado a archivo original
│       ├── prueba_doc_nuevo.txt      # Archivo base para pruebas de enlaces e inodos
│       └── link_record.txt           # Verificación de inodos y enlaces (duros y simbólicos)
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

## 💡 Respuestas a las preguntas de Cada Etapa
### Etapa 1

* **¿Por qué los permisos adecuados para un directorio pueden ser distintos de los de un archivo?**
En un directorio, el permiso x (ejecución) permite atravesarlo y acceder a sus inodos. En un archivo de datos, x no es necesario y representa un riesgo de seguridad al permitir su ejecución como binario.

* **¿Qué diferencia existe entre el archivo original y su enlace duro?**
Ninguna a nivel de sistema de archivos; ambos son entradas de directorio independientes que apuntan al mismo número de inodo y comparten bloques de datos en disco.

* **¿Cuál es la utilidad de establecer enlaces simbólicos en el desarrollo?**
Crean accesos directos o abstracciones de rutas dinámicas a archivos/directorios sin duplicar datos ni alterar la estructura original.

* **¿Qué información de los metadatos permite reconocer cambios en un archivo?**
El tamaño, las marcas de tiempo (mtime para modificación de contenido, ctime para cambios de inodo/permisos) y el código de verificación o inodo.

### Etapa 2

* **¿Qué transformación necesita la salida de cada utilería para convertirse en un registro normalizado?**
Filtrar encabezados y texto secundario con awk/sed para aislar únicamente el valor entero numérico y concatenarle su etiqueta de categoría (DISCO, PROCESOS, PERMISOS).

* **¿Por qué un valor cero puede ser válido y no debe confundirse con una captura fallida?**
Porque 0 representa un estado real del sistema (ej. 0 archivos con permisos inseguros). Una captura fallida se distingue por un código de salida distinto de cero ($? != 0) o por una salida nula en la utilería.

* **¿Cómo comprobarán que la cantidad del encabezado corresponde a los registros conservados?**
Contando las líneas del cuerpo del archivo con grep -c o awk y comparando dinámicamente ese entero contra el valor declarado en la línea 2 de mediciones_sec.txt.

* **¿Por qué el orden de sed es determinante al habilitar directivas y eliminar comentarios?**
Porque si se eliminan los comentarios primero (/^\s*#/d), las directivas comentadas que debían ser modificadas o habilitadas se perderían antes de poder ser procesadas.

* **¿Qué estrategia se empleó para aislar el puerto sin limitar los cuatro octetos de la IP?**
Utilizar expresiones regulares con delimitadores de campo (tratar los dos puntos : como separadores) para aislar limpiamente los campos de dirección IP y puerto.

### Etapa 3

* **¿Qué diferencia existe entre almacenar una medición y almacenar el resumen de una categoría?**
Una medición almacena un evento individual en memoria (categoría y valor). El resumen es una estructura agregada que consolida métricas acumuladas (suma, min, max, promedio, alertas).

* **¿Cómo evitarán una división entre cero o utilizar un mínimo no inicializado?**
Evaluando si cantidad > 0 antes de calcular el promedio, e inicializando los valores minimo y maximo directamente con el valor del primer registro válido procesado.

* **Si ocurre un error después de reservar memoria y abrir un archivo, ¿qué recursos deben liberarse?**
Se debe cerrar el descriptor de archivo con fclose() y liberar los bloques de memoria dinámica asignados con free().

### Etapa 4

* **¿Cómo decide el script si puede continuar después de ejecutar el programa C?**
Verificando el código de salida devuelto por el proceso hijo mediante la condición $? -eq 0 o el mecanismo de interrupción automática set -e.

* **¿Cómo se distinguirá un informe nuevo de uno conservado de una ejecución anterior?**
Mediante la eliminación preventiva del archivo informe al inicio del script orquestador y la inclusión de marcas de tiempo en el flujo de ejecución.

* **¿Qué evidencia demuestra que el informe se obtuvo mediante el flujo completo y no manualmente?**
La coherencia exacta de inodos, la actualización de marcas de tiempo en preparados/mediciones_sec.txt y los registros paso a paso en la salida estándar durante la ejecución del script orquestador.
