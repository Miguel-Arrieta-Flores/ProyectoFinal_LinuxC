#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_TAG_LEN 31

/* Estructura de la medicion con nombre y valor */
typedef struct {
    char categoria[16];
    int valor;
} Medicion;

/* Estructura para las mediciones de la categoria */
typedef struct {
    int cantidad;
    long suma;
    int minimo;
    int maximo;
    double promedio;
    int alertas;
} StatsCategoria;

/* Funcion encargada de revisar que el valor se encuentre en su respectivo rango */
int validar_intervalo(const char *cat, int val) {
    if (strcmp(cat, "DISCO") == 0) return (val >= 0 && val <= 100);
    if (strcmp(cat, "PROCESOS") == 0) return (val >= 0 && val <= 2000);
    if (strcmp(cat, "PERMISOS") == 0) return (val >= 0 && val <= 200);
    return 0;
}

/* Funcion que realiza las mediciones de la categoria */
void procesar_estadisticas(Medicion *meds, int total, const char *cat, StatsCategoria *st, int umbral_alerta) {
    st->cantidad = 0; st->suma = 0; st->alertas = 0;
    int primero = 1;

    for (int i = 0; i < total; i++) {
        if (strcmp(meds[i].categoria, cat) == 0) {
            st->cantidad++;
            st->suma += meds[i].valor;

            if (primero) {
                st->minimo = meds[i].valor;
                st->maximo = meds[i].valor;
                primero = 0;
            } else {
                if (meds[i].valor < st->minimo) st->minimo = meds[i].valor;
                if (meds[i].valor > st->maximo) st->maximo = meds[i].valor;
            }

            if (strcmp(cat, "PERMISOS") == 0) {
                if (meds[i].valor > 0) st->alertas++;
            } else {
                if (meds[i].valor >= umbral_alerta) st->alertas++;
            }
        }
    }
    st->promedio = (st->cantidad > 0) ? ((double)st->suma / st->cantidad) : 0.0;
}

/* Funcion que se encarga de escribir las mediciones de la categoria dada en el archivo */
void escribir_bloque_informe(FILE *f, const char *cat_nombre, StatsCategoria *st) {
    fprintf(f, "Categoria %s\n", cat_nombre);
    if (st->cantidad == 0) {
        fprintf(f, "Sin datos\n");
        return;
    }
    fprintf(f, "Cantidad: %d\n", st->cantidad);
    fprintf(f, "Suma: %ld\n", st->suma);
    fprintf(f, "Minimo: %d\n", st->minimo);
    fprintf(f, "Maximo: %d\n", st->maximo);
    fprintf(f, "Promedio: %.2f\n", st->promedio);
    fprintf(f, "Alertas: %d\n", st->alertas);
    fprintf(f, "-----------------------------------------\n");
}


int main(int argc, char *argv[]) {
    if (argc < 3) {
        fprintf(stderr, "Uso: %s <archivo_entrada> <archivo_salida>\n", argv[0]);
        return 1;
    }

    FILE *fin = fopen(argv[1], "r");
    if (!fin) {
        perror("Error al abrir archivo de entrada");
        return 1;
    }

    char etiqueta[MAX_TAG_LEN + 1];
    int cantidad_declarada = 0;

    if (fscanf(fin, "%31s", etiqueta) != 1 || fscanf(fin, "%d", &cantidad_declarada) != 1) {
        fprintf(stderr, "Error: Formato de cabecera invalido.\n");
        fclose(fin);
        return 1;
    }
    
    /* Verificamos que la cantidad de registros se encuentre dentro del rango */
    if (cantidad_declarada < 0 || cantidad_declarada > 200) {
        fprintf(stderr, "Error: Cantidad de registros fuera de rango (0-200).\n");
        fclose(fin);
        return 1;
    }
   

    Medicion *mediciones = NULL;
    if (cantidad_declarada > 0) {
        mediciones = malloc(sizeof(Medicion) * cantidad_declarada);
        if (!mediciones) {
            fprintf(stderr, "Error: Memoria insuficiente.\n");
            fclose(fin);
            return 1;
        }
    }
    
    /* Validamos que las mediciones esten en su respectivo rango */
    int leidos = 0;
    while (leidos < cantidad_declarada && fscanf(fin, "%15s %d", mediciones[leidos].categoria, &mediciones[leidos].valor) == 2) {
        if (!validar_intervalo(mediciones[leidos].categoria, mediciones[leidos].valor)) {
            fprintf(stderr, "Error: Valor fuera de rango en registro %d.\n", leidos + 1);
            free(mediciones);
            fclose(fin);
            return 1;
        }
        leidos++;
    }

    /* Verificar si hay discordancia de datos */
    char extra_cat[16]; int extra_val;
    if (leidos != cantidad_declarada || fscanf(fin, "%15s %d", extra_cat, &extra_val) == 2) {
        fprintf(stderr, "Error: La cantidad de registros no coincide con la cabecera.\n");
        free(mediciones);
        fclose(fin);
        return 1;
    }
    fclose(fin);

    /* Calculo de estadísticas por categoría */
    StatsCategoria st_disco = {0}, st_procesos = {0}, st_permisos = {0};
    procesar_estadisticas(mediciones, leidos, "DISCO", &st_disco, 80);
    procesar_estadisticas(mediciones, leidos, "PROCESOS", &st_procesos, 30);
    procesar_estadisticas(mediciones, leidos, "PERMISOS", &st_permisos, 1);

    /* Se guarda la informacion del informe  en el archivo de salida */
    FILE *fout = fopen(argv[2], "w");
    if (!fout) {
        perror("Error al crear archivo de salida");
        free(mediciones);
        return 1;
    }

    fprintf(fout, "INFORME DE MONITOREO\n");
    fprintf(fout, "Etiqueta: %s\nRegistros: %d\n", etiqueta, cantidad_declarada);
    fprintf(fout, "-----------------------------------------\n");

    escribir_bloque_informe(fout, "DISCO", &st_disco);
    escribir_bloque_informe(fout, "PROCESOS", &st_procesos);
    escribir_bloque_informe(fout, "PERMISOS", &st_permisos);

    int total_alertas = st_disco.alertas + st_procesos.alertas + st_permisos.alertas;
    fprintf(fout, "Observaciones que cumplen condiciones de alerta: %d.\n", total_alertas);
    
    fclose(fout);
    free(mediciones);
    return 0;
}
