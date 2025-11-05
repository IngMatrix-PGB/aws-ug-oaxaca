# ☁️ AWS User Group Oaxaca – PoC: Infrastructure as Code

> 🚀 Despliegue automatizado de una aplicación web en AWS usando Terraform, Docker y CI/CD.

---

## 🧩 Arquitectura General

               ┌────────────────────────────┐
               │        GitHub Actions       │
               │   (CI/CD Workflow Trigger)  │
               └──────────────┬──────────────┘
                              │
                              ▼
               ┌────────────────────────────┐
               │       Docker Build         │
               │  Imagen → Amazon ECR       │
               └──────────────┬──────────────┘
                              │  (Push)
                              ▼
               ┌────────────────────────────┐
               │        Amazon ECR          │
               │ Registro Privado de Imagen │
               └──────────────┬──────────────┘
                              │  (Pull)
                              ▼
      ┌──────────────────────────────────────────────┐
      │                AWS EC2 (Host)                │
      │  - Instancia creada por Terraform            │
      │  - Rol IAM con permisos para ECR             │
      │  - Docker Run → Contenedor NGINX             │
      └──────────────┬───────────────────────────────┘
                     │
                     ▼
           ┌────────────────────────────┐
           │   🌍 Aplicación Web (HTTP)  │
           │ “AWS User Group Oaxaca PoC” │
           └──────────────┬──────────────┘
                          │
                          ▼
                 👩‍💻 Usuario Final



1. **GitHub Actions** ejecuta el pipeline CI/CD al hacer push.  
2. **Docker** construye la imagen y la publica en **Amazon ECR**.  
3. **Terraform** crea toda la infraestructura (VPC, EC2, IAM, SG).  
4. La **instancia EC2** obtiene la imagen, ejecuta el contenedor y expone Nginx.  
5. El usuario accede vía IP pública (`http://<ec2-public-ip>`).  

---

## 🧱 Tecnologías Usadas

**Terraform** • **Docker** • **AWS ECR** • **EC2** • **GitHub Actions** • **Nginx**

---

## 👨‍💻 Autor

**Pablo Galeana Bailey**  
AWS User Group Oaxaca 🇲🇽  
> “Infra desplegada, contenedor corriendo... misión cumplida ☁️🚀”
