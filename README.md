# Rasa Deportes — Catálogo de Equipos Deportivos

Aplicación web para gestión y exhibición pública de catálogo de productos deportivos. Incluye tienda pública con búsqueda y filtros, y un panel de administración completo.

---

## Índice

1. [Stack tecnológico](#stack-tecnológico)
2. [Estructura del proyecto](#estructura-del-proyecto)
3. [Requisitos previos](#requisitos-previos)
4. [Instalación y desarrollo local](#instalación-y-desarrollo-local)
5. [Variables de entorno](#variables-de-entorno)
6. [Docker — entorno completo](#docker--entorno-completo)
7. [Despliegue en producción (VPS Ubuntu)](#despliegue-en-producción-vps-ubuntu)
8. [Gestión de la base de datos](#gestión-de-la-base-de-datos)
9. [Operaciones del día a día](#operaciones-del-día-a-día)
10. [Solución de problemas](#solución-de-problemas)

---

## Stack tecnológico

| Capa | Tecnología |
|---|---|
| Backend | Spring Boot 4.0.5 / Spring Framework 7 / Jakarta EE 10 |
| Persistencia | Spring Data JPA + Hibernate 7 + MySQL 8.4 |
| Migraciones DB | Flyway |
| Vistas | Thymeleaf 3 + Layout Dialect |
| Seguridad | Spring Security 6 (CSRF, BCrypt, form login) |
| UI pública | CSS personalizado, Google Fonts Outfit |
| UI admin | Mantis Dashboard (Bootstrap 5, Tabler Icons) |
| Build | Maven 3 (wrapper incluido) |
| Contenedores | Docker + Docker Compose |
| Servidor web | Nginx (reverse proxy) |
| SSL | Let's Encrypt + Certbot |
| Java runtime | Eclipse Temurin 17 (JRE Alpine) |

---

## Estructura del proyecto

```
rasaapp/
├── src/
│   └── main/
│       ├── java/com/rasadeportes/rasaapp/
│       │   ├── config/          # Security, Web, DataInitializer
│       │   ├── controller/      # Controllers (público + dashboard)
│       │   ├── model/           # Entidades JPA
│       │   ├── repository/      # Spring Data repos
│       │   └── services/        # Lógica de negocio
│       └── resources/
│           ├── static/
│           │   ├── css/         # public-base.css, catalogo.css, detalle.css
│           │   └── mantis/      # Assets del dashboard Mantis
│           ├── templates/
│           │   ├── publico/     # catalogo.html, detalle.html
│           │   ├── layout/      # base.html, sidebar.html (dashboard)
│           │   ├── producto/    # CRUD productos
│           │   ├── categoria/   # CRUD categorías
│           │   ├── variantes/   # CRUD variantes
│           │   └── imagenes/    # Gestión de imágenes
│           ├── db/migration/    # V1__schema_inicial.sql (Flyway)
│           ├── application.properties       # Config base (sin credenciales)
│           ├── application-dev.properties   # Perfil desarrollo
│           ├── application-prod.properties  # Perfil producción
│           └── logback-spring.xml           # Configuración de logs
├── deploy/
│   ├── install.sh       # Instalación completa en Ubuntu VPS
│   ├── update.sh        # Actualización con rollback automático
│   ├── backup.sh        # Backup de MySQL con rotación
│   ├── nginx.conf       # Configuración de Nginx (plantilla)
│   └── rasaapp.service  # Unidad systemd
├── Dockerfile           # Build multi-etapa (deps → builder → runtime JRE)
├── docker-compose.yml   # MySQL 8.4 + Spring Boot + volúmenes + healthchecks
├── .env.example         # Plantilla de variables de entorno
└── .dockerignore
```

**Rutas públicas:**

| URL | Descripción |
|---|---|
| `/` | Redirect al catálogo |
| `/catalogo` | Catálogo público con búsqueda y filtros |
| `/catalogo/producto/{id}` | Detalle de producto |

**Rutas del panel (requieren login):**

| URL | Descripción |
|---|---|
| `/login` | Pantalla de acceso |
| `/dashboard/productos` | Listado y gestión de productos |
| `/dashboard/categorias` | Gestión de categorías |

---

## Requisitos previos

### Para desarrollo local

- Java 17+ — [Instalar con SDKMAN](https://sdkman.io/): `sdk install java 17.0.12-tem`
- MySQL 8.4
- Maven 3.9+ (o usar el wrapper `./mvnw` incluido)

### Para Docker

- Docker 24+ — [docker.com/get-docker](https://docs.docker.com/get-docker/)
- Docker Compose plugin (`docker compose`, incluido con Docker Desktop)

Verificar instalación:
```bash
docker --version         # Docker version 24.x+
docker compose version   # Docker Compose version v2.x+
```

---

## Instalación y desarrollo local

### 1. Clonar el repositorio

```bash
git clone https://github.com/tu-usuario/rasaapp.git
cd rasaapp
```

### 2. Configurar MySQL local

Crea la base de datos y el usuario:

```sql
CREATE DATABASE rasadb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- Si usas el usuario root sin contraseña (desarrollo), no se necesita nada más.
-- Para usar un usuario específico:
CREATE USER 'rasauser'@'localhost' IDENTIFIED BY 'tu_contraseña';
GRANT ALL PRIVILEGES ON rasadb.* TO 'rasauser'@'localhost';
FLUSH PRIVILEGES;
```

### 3. Configurar el perfil de desarrollo

El perfil `dev` usa `application-dev.properties`, que apunta a `localhost:3306/rasadb` con usuario `root` y sin contraseña por defecto. Si tu instalación local es diferente, edita ese archivo:

```
# src/main/resources/application-dev.properties
spring.datasource.url=jdbc:mysql://localhost:3306/rasadb?...
spring.datasource.username=root
spring.datasource.password=
```

> No pongas las credenciales de producción aquí. Este archivo puede estar en el repositorio.

### 4. Arrancar la aplicación

```bash
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev
```

La aplicación arranca en `http://localhost:8080`.

El perfil `dev` tiene `ddl-auto=update` y Flyway desactivado, así que Hibernate crea las tablas automáticamente en el primer arranque.

**Credenciales de acceso por defecto (perfil dev):**

| Campo | Valor |
|---|---|
| Usuario | `admin` |
| Contraseña | `admin123` |

> Estos valores se configuran en `application-dev.properties` con `app.admin.username` y `app.admin.password`.

### 5. Compilar el proyecto

```bash
./mvnw package -DskipTests
# El JAR queda en: target/rasaapp-0.0.1-SNAPSHOT.jar
```

---

## Variables de entorno

El archivo `.env` contiene todas las credenciales sensibles. **Nunca se sube al repositorio.**

```bash
cp .env.example .env
nano .env   # o tu editor preferido
```

### Referencia completa

| Variable | Descripción | Ejemplo |
|---|---|---|
| `SPRING_PROFILES_ACTIVE` | Perfil activo de Spring | `prod` |
| `APP_PORT` | Puerto expuesto en el host | `8080` |
| `DB_NAME` | Nombre de la base de datos | `rasadb` |
| `DB_USER` | Usuario de MySQL | `rasauser` |
| `DB_PASS` | Contraseña del usuario de MySQL | `s3cr3t_pass` |
| `DB_ROOT_PASS` | Contraseña del usuario root (para backups y healthcheck) | `r00t_s3cr3t` |
| `ADMIN_USERNAME` | Usuario del panel de administración | `admin` |
| `ADMIN_PASSWORD` | Contraseña del panel de administración | `Admin@2025!` |

### Buenas prácticas para contraseñas

- Mínimo 16 caracteres
- Combinación de mayúsculas, minúsculas, números y símbolos
- Generador rápido: `openssl rand -base64 24`

```bash
# Ejemplo de generación de contraseñas seguras
openssl rand -base64 24   # → Copia el resultado como DB_PASS
openssl rand -base64 24   # → Copia el resultado como DB_ROOT_PASS
openssl rand -base64 24   # → Copia el resultado como ADMIN_PASSWORD
```

---

## Docker — entorno completo

Esta es la forma recomendada de levantar el proyecto completo (app + MySQL) sin instalar nada localmente salvo Docker.

### Levantar el entorno

```bash
# 1. Copiar y completar el .env
cp .env.example .env
nano .env

# 2. Levantar todo con un solo comando
docker compose up -d

# 3. Ver logs en tiempo real
docker compose logs -f app
```

El primer arranque tarda ~2–3 minutos porque:
1. Docker descarga las imágenes base
2. Maven descarga las dependencias (se cachean en capas)
3. Spring Boot compila y arranca
4. Flyway ejecuta `V1__schema_inicial.sql` y crea las tablas
5. `DataInitializer` crea el usuario admin

### Verificar el estado

```bash
# Estado de los contenedores
docker compose ps

# Health check de la aplicación
curl http://localhost:8080/actuator/health
# Respuesta esperada: {"status":"UP"}

# Logs de MySQL
docker compose logs db

# Logs de la app
docker compose logs app
```

### Detener el entorno

```bash
docker compose down           # Detiene los contenedores (preserva volúmenes y datos)
docker compose down -v        # Detiene Y elimina todos los datos (⚠ irreversible)
```

### Rebuild después de cambios en el código

```bash
docker compose build --no-cache app
docker compose up -d
```

### Estructura de Docker Compose

```
                     ┌─────────────────────────────────┐
                     │         docker network           │
                     │           rasanet                │
                     │                                  │
  :8080 (host) ──────┤──▶ app (rasaapp)  :8080         │
                     │         │                        │
                     │         ▼                        │
                     │    db (rasaapp_db) :3306         │
                     │                                  │
                     └─────────────────────────────────┘
                     
  Volúmenes: mysql_data · uploads_data · logs_data
```

**Health checks configurados:**
- `db`: `mysqladmin ping` cada 10s, 10 reintentos
- `app`: `GET /actuator/health` cada 30s, 5 reintentos
- `app` espera que `db` esté saludable antes de arrancar (`depends_on: condition: service_healthy`)

---

## Despliegue en producción (VPS Ubuntu)

### Requisitos del servidor

- Ubuntu 22.04 LTS o 24.04 LTS
- 1 vCPU / 1 GB RAM mínimo (recomendado 2 vCPU / 2 GB)
- Acceso root por SSH
- Dominio apuntando al servidor (registros A para `@` y `www`)

**Verificar que el DNS esté propagado antes de continuar:**
```bash
# Desde tu máquina local
nslookup rasadeportes.com
# Debe devolver la IP del VPS
```

### Paso 1 — Subir el proyecto al servidor

**Opción A — Git (recomendado):**
```bash
# Primero sube el código a GitHub/GitLab, luego en el servidor:
ssh root@IP_DEL_VPS
git clone https://github.com/tu-usuario/rasaapp.git /tmp/rasaapp
cd /tmp/rasaapp
```

**Opción B — rsync (si no usas Git):**
```bash
# Desde tu máquina local
rsync -avz \
  --exclude='.git' \
  --exclude='target/' \
  --exclude='.env' \
  --exclude='uploads/' \
  . usuario@IP_DEL_VPS:/tmp/rasaapp/
```

### Paso 2 — Ejecutar el instalador

```bash
# En el servidor, desde el directorio del proyecto
cd /tmp/rasaapp
sudo bash deploy/install.sh
```

El script solicita de forma interactiva:

```
[?] Dominio principal del sitio (sin www): rasadeportes.com
[?] Email para Let's Encrypt (notificaciones de renovación): tu@email.com
[?] Directorio de instalación [/opt/rasaapp]:
[?] Usuario del sistema para la app [rasaapp]:
```

A continuación hace automáticamente:

1. Actualiza el sistema (`apt upgrade`)
2. Instala Docker (repositorio oficial)
3. Instala Nginx
4. Instala Certbot + plugin de Nginx
5. Crea usuario del sistema `rasaapp` sin privilegios
6. Copia el proyecto a `/opt/rasaapp`
7. Genera el `.env` desde `.env.example` y te pide que lo edites
8. Configura el firewall (UFW: puertos 22, 80, 443)
9. Configura Nginx para HTTP (necesario para la validación de Let's Encrypt)
10. Obtiene el certificado SSL con Let's Encrypt
11. Reemplaza Nginx con la configuración HTTPS completa
12. Crea e instala el servicio `rasaapp.service` en systemd
13. Configura backup automático diario a las 02:00 (cron)
14. Configura logrotate para los logs de la app
15. Habilita la renovación automática del certificado SSL
16. Arranca la aplicación y verifica el health check

### Paso 3 — Verificar la instalación

```bash
# Estado del servicio
systemctl status rasaapp

# Health check de la app
curl https://rasadeportes.com/actuator/health

# Certificado SSL
curl -I https://rasadeportes.com
# Buscar: HTTP/2 200

# Estado de los contenedores
docker compose -C /opt/rasaapp ps
```

### Configuración de Nginx

El archivo `/etc/nginx/sites-available/rasaapp` se genera a partir de `deploy/nginx.conf`. Incluye:

- Redirección automática HTTP → HTTPS
- HTTP/2
- Cabeceras de seguridad (HSTS, X-Frame-Options, CSP, etc.)
- Gzip para texto, CSS, JS, SVG
- Cache de 1 año para activos estáticos (JS, CSS, fuentes)
- Cache de 7 días para imágenes de productos (`/uploads/`)
- Acceso al `/actuator/` bloqueado desde internet
- Soporte para uploads de hasta 10 MB

Para modificar la configuración de Nginx:
```bash
sudo nano /etc/nginx/sites-available/rasaapp
sudo nginx -t             # Verificar sintaxis
sudo systemctl reload nginx
```

### Renovación del certificado SSL

Certbot instala un timer de systemd que renueva el certificado automáticamente:

```bash
# Ver estado del timer
systemctl status certbot.timer

# Probar renovación (modo dry-run, no cambia nada)
sudo certbot renew --dry-run

# Renovar manualmente si es necesario
sudo certbot renew
```

---

## Gestión de la base de datos

### Migraciones con Flyway

En producción, Flyway gestiona el schema automáticamente al arrancar la aplicación. Los archivos de migración están en:

```
src/main/resources/db/migration/
  V1__schema_inicial.sql    ← crea todas las tablas e índices
```

Para agregar cambios al schema en producción:
1. Crea un nuevo archivo `V2__descripcion.sql` en el directorio de migraciones
2. Despliega la nueva versión con `update.sh`
3. Flyway aplica automáticamente las migraciones pendientes al arrancar

> **Regla de Flyway:** los archivos de migración ya aplicados **nunca** se modifican. Los cambios siempre van en versiones nuevas.

### Backup manual

```bash
# Ejecutar desde el servidor
bash /opt/rasaapp/deploy/backup.sh
```

Los backups se guardan en `/opt/rasaapp/backups/` con el formato `rasadb_YYYYMMDD_HHMMSS.sql.gz`.

**Rotación automática:**
- Backups diarios: se conservan los últimos **30 días**
- Backups semanales (domingo): se conservan las últimas **12 semanas**

### Restaurar un backup

```bash
# Localizar el backup
ls -lh /opt/rasaapp/backups/

# Restaurar (reemplaza todos los datos actuales)
gunzip -c /opt/rasaapp/backups/rasadb_20250101_020000.sql.gz \
  | docker exec -i rasaapp_db \
    mysql -uroot -p${DB_ROOT_PASS} rasadb
```

### Acceso directo a MySQL

```bash
# Consola MySQL interactiva
docker exec -it rasaapp_db mysql -uroot -p${DB_ROOT_PASS} rasadb

# Consulta rápida
docker exec rasaapp_db \
  mysql -uroot -p${DB_ROOT_PASS} rasadb -e "SELECT COUNT(*) FROM productos;"
```

---

## Operaciones del día a día

### Actualizar la aplicación

```bash
cd /opt/rasaapp

# Con git (código subido al repositorio)
bash deploy/update.sh

# Sin git (archivos subidos manualmente con rsync/scp)
bash deploy/update.sh --no-pull
```

El script de actualización:
1. Hace `git pull` (salvo `--no-pull`)
2. Guarda la imagen actual como `rasaapp-app:rollback-TIMESTAMP`
3. Construye la nueva imagen
4. Reinicia solo el contenedor `app` (MySQL no se toca)
5. Verifica el health check durante 150 segundos
6. Si falla: restaura automáticamente la imagen anterior y reinicia

### Ver logs

```bash
# Logs de la app en tiempo real
docker compose -C /opt/rasaapp logs -f app

# Logs de MySQL
docker compose -C /opt/rasaapp logs -f db

# Logs de Nginx
tail -f /var/log/nginx/rasaapp_access.log
tail -f /var/log/nginx/rasaapp_error.log

# Logs del servicio systemd
journalctl -u rasaapp -f
```

### Reiniciar servicios

```bash
# Reiniciar solo la app (MySQL no se toca)
docker compose -C /opt/rasaapp restart app

# Reiniciar todo el stack
systemctl restart rasaapp

# Reiniciar Nginx
systemctl restart nginx
```

### Cambiar la contraseña del admin

1. Edita `/opt/rasaapp/.env` y cambia `ADMIN_PASSWORD`
2. Borra el usuario actual en MySQL (DataInitializer lo recreará):
   ```bash
   docker exec rasaapp_db \
     mysql -uroot -p${DB_ROOT_PASS} rasadb \
     -e "DELETE FROM usuarios WHERE username='${ADMIN_USERNAME}';"
   ```
3. Reinicia la app:
   ```bash
   docker compose -C /opt/rasaapp restart app
   ```

---

## Solución de problemas

### La app no arranca — `Connection refused` a MySQL

**Síntoma:** La app arranca antes de que MySQL esté listo.

```bash
docker compose logs app | grep "Communications link failure"
```

**Causa:** MySQL tardó más de lo esperado en arrancar.

**Solución:**
```bash
# Ver estado del healthcheck de MySQL
docker inspect rasaapp_db | grep -A 10 '"Health"'

# Esperar a que MySQL esté listo y reiniciar la app
docker compose restart app
```

---

### Error 502 Bad Gateway en Nginx

**Causa más común:** La app de Spring Boot no está corriendo o arrancó en un puerto distinto.

```bash
# Verificar que la app responde
curl http://localhost:8080/actuator/health

# Si no responde, ver logs
docker compose logs app | tail -50

# Reiniciar la app
docker compose -C /opt/rasaapp restart app
```

---

### Certificado SSL no se renueva

```bash
# Ver estado del timer
systemctl status certbot.timer

# Ver logs de renovación
journalctl -u certbot -n 50

# Renovar manualmente
sudo certbot renew --force-renewal
sudo systemctl reload nginx
```

---

### Flyway falla al arrancar en producción

**Síntoma:** `FlywayException: Validate failed` o `checksum mismatch`.

**Causa:** Se modificó un archivo de migración ya aplicado.

**Solución:** Nunca modifiques V1, V2, etc. ya aplicados. Crea una nueva versión:

```sql
-- src/main/resources/db/migration/V2__nombre_del_cambio.sql
ALTER TABLE productos ADD COLUMN codigo VARCHAR(50);
```

Si estás en desarrollo y quieres limpiar:
```bash
# Solo en dev — elimina el schema_history y vuelve a aplicar todo
docker exec rasaapp_db \
  mysql -uroot -p${DB_ROOT_PASS} rasadb \
  -e "DROP TABLE IF EXISTS flyway_schema_history;"
docker compose restart app
```

---

### Las imágenes subidas no aparecen

**Causa:** El volumen de uploads no está montado correctamente.

```bash
# Verificar que el volumen existe
docker volume ls | grep uploads

# Verificar que la app puede escribir en /app/uploads
docker exec rasaapp ls -la /app/uploads

# Ver logs de error al subir imagen
docker compose logs app | grep "Error guardando imagen"
```

---

### La app consume demasiada memoria

El JVM está configurado para usar máximo el 75% de la RAM del contenedor (`-XX:MaxRAMPercentage=75.0`). Si el contenedor tiene 512 MB, el heap máximo es ~384 MB.

```bash
# Ver uso de memoria del contenedor
docker stats rasaapp --no-stream

# Ver uso de memoria del JVM
docker exec rasaapp sh -c 'cat /proc/1/status | grep VmRSS'
```

Para aumentar la memoria del contenedor, agrega al servicio `app` en `docker-compose.yml`:
```yaml
deploy:
  resources:
    limits:
      memory: 1G
```

---

### Port 8080 ya está en uso

```bash
# Ver qué proceso usa el puerto
sudo lsof -i :8080

# Si es otro proceso, matarlo
sudo kill -9 <PID>

# O cambiar el puerto en .env
APP_PORT=9090
docker compose up -d
```

---

### Disco lleno por logs o backups

```bash
# Ver uso de disco
df -h

# Ver qué ocupa más espacio en /opt/rasaapp
du -sh /opt/rasaapp/*

# Limpiar backups manualmente (conservar los últimos 7)
ls -t /opt/rasaapp/backups/rasadb_*.sql.gz | tail -n +8 | xargs rm -f

# Limpiar logs de Docker
docker system prune --volumes -f

# Limpiar imágenes Docker sin usar
docker image prune -a -f
```

---

### Verificación rápida del sistema completo

```bash
echo "=== Docker ==="
docker compose -C /opt/rasaapp ps

echo "=== App Health ==="
curl -s https://rasadeportes.com/actuator/health

echo "=== SSL ==="
echo | openssl s_client -connect rasadeportes.com:443 2>/dev/null \
  | openssl x509 -noout -dates

echo "=== Nginx ==="
systemctl is-active nginx

echo "=== Disco ==="
df -h /opt/rasaapp

echo "=== Último backup ==="
ls -lht /opt/rasaapp/backups/ | head -3
```
