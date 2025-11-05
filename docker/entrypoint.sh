#!/bin/sh
set -e

# Entrypoint script para el contenedor de AWS User Group Oaxaca Demo
# Este script se ejecuta antes de iniciar nginx

echo " Iniciando AWS User Group Oaxaca - PoC Demo"
echo " $(date)"
echo " Contenedor iniciado correctamente"

# Verificar que el archivo HTML existe
if [ ! -f /usr/share/nginx/html/index.html ]; then
    echo " Error: index.html no encontrado"
    exit 1
fi

echo " Archivos verificados"
echo " Iniciando servidor Nginx..."

# Ejecutar el comando pasado como argumento (nginx)
exec "$@"