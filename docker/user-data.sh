#!/bin/bash

set -e

# Variables - MODIFICAR SEGÚN TU CONFIGURACIÓN
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-088646600319}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_NAME="aws-ug-oaxaca"
IMAGE_TAG="${IMAGE_TAG:-latest}"
CONTAINER_NAME="umma-oaxaca"

# Logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo " Iniciando configuración de instancia EC2 - $(date)"

# Detectar el sistema operativo
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
else
    echo " No se pudo detectar el sistema operativo"
    exit 1
fi

echo "📦 Sistema operativo detectado: $OS $VER"

# Instalar Docker según el OS
install_docker() {
    case $OS in
        "amzn"|"al2023")
            echo " Instalando Docker en Amazon Linux..."
            # Amazon Linux 2023
            if command -v dnf &> /dev/null; then
                # Amazon Linux 2023
                dnf update -y
                dnf install -y docker
            else
                # Amazon Linux 2
                yum update -y
                yum install -y docker
            fi
            ;;
        "ubuntu")
            echo " Instalando Docker en Ubuntu..."
            apt-get update -y
            apt-get install -y \
                ca-certificates \
                curl \
                gnupg \
                lsb-release
            mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
                gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            echo \
              "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
              $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            apt-get update -y
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        *)
            echo " Sistema operativo no soportado: $OS"
            exit 1
            ;;
    esac
}

# Instalar Docker
install_docker

# Instalar AWS CLI si no está instalado
if ! command -v aws &> /dev/null; then
    echo " Instalando AWS CLI..."
    if [ "$OS" = "amzn" ] || [ "$OS" = "al2023" ]; then
        if command -v dnf &> /dev/null; then
            dnf install -y aws-cli
        else
            yum install -y aws-cli
        fi
    else
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip awscliv2.zip
        ./aws/install
        rm -rf aws awscliv2.zip
    fi
fi

# Iniciar y habilitar Docker
echo " Iniciando servicio Docker..."
systemctl start docker
systemctl enable docker

# Verificar que Docker está funcionando
if ! docker --version; then
    echo " Error: Docker no se instaló correctamente"
    exit 1
fi

echo " Docker instalado correctamente: $(docker --version)"

# Esperar a que la instancia obtenga su rol IAM (si se usa)
echo " Esperando a que el rol IAM esté disponible..."
sleep 10

# Autenticar con ECR usando el rol IAM de la instancia
echo " Autenticando con ECR..."
max_attempts=5
attempt=1

while [ $attempt -le $max_attempts ]; do
    if aws ecr get-login-password --region ${AWS_REGION} | \
       docker login --username AWS --password-stdin ${ECR_REGISTRY}; then
        echo " Autenticación exitosa con ECR"
        break
    else
        echo "  Intento $attempt/$max_attempts fallido. Reintentando en 10 segundos..."
        sleep 10
        attempt=$((attempt + 1))
    fi
done

if [ $attempt -gt $max_attempts ]; then
    echo " Error: No se pudo autenticar con ECR después de $max_attempts intentos"
    echo "  Verifica que el rol IAM de la instancia tiene los permisos necesarios"
    exit 1
fi

# Hacer pull de la imagen
echo " Descargando imagen desde ECR..."
max_pull_attempts=3
pull_attempt=1

while [ $pull_attempt -le $max_pull_attempts ]; do
    if docker pull ${ECR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}; then
        echo " Imagen descargada exitosamente"
        break
    else
        echo "  Intento de pull $pull_attempt/$max_pull_attempts fallido. Reintentando..."
        sleep 5
        pull_attempt=$((pull_attempt + 1))
    fi
done

if [ $pull_attempt -gt $max_pull_attempts ]; then
    echo " Error: No se pudo descargar la imagen después de $max_pull_attempts intentos"
    exit 1
fi

# Detener contenedor anterior si existe
echo " Deteniendo contenedor anterior si existe..."
docker stop ${CONTAINER_NAME} 2>/dev/null || true
docker rm ${CONTAINER_NAME} 2>/dev/null || true

# Ejecutar el contenedor
echo "🚀 Iniciando contenedor..."
docker run -d \
  --name ${CONTAINER_NAME} \
  -p 80:80 \
  --restart unless-stopped \
  ${ECR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}

# Verificar que el contenedor está corriendo
sleep 5
if docker ps | grep -q ${CONTAINER_NAME}; then
    echo " Contenedor iniciado correctamente"
    echo " Aplicación disponible en: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'IP_PUBLICA')"
else
    echo " Error: El contenedor no se inició correctamente"
    echo " Ver logs: docker logs ${CONTAINER_NAME}"
    exit 1
fi

echo " Configuración completada exitosamente - $(date)"