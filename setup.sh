#!/bin/bash
set -x # Muestra cada comando antes de ejecutarlo en el log
exec > /var/log/setup-script-exec.log 2>&1 # Guarda la traza completa

# 1. Esperar a que la red responda antes de continuar
until ping -c 1 archive.ubuntu.com >/dev/null 2>&1; do
    echo "Esperando conexión a Internet..."
    sleep 2
done

# 2. Actualizar e instalar paquetes con reintento si falla
apt update -y || true
apt upgrade -y || true
apt install -y make python3-venv pipx ufw openjdk-21-jdk curl git mysql-server || true

# 3. Crear carpetas
mkdir -p /home/miguel7736/MINECRAFT/SERVER

# 4. Entorno Python
python3 -m venv /home/miguel7736/MINECRAFT/BOT_MINECRAFT/python_env
/home/miguel7736/MINECRAFT/BOT_MINECRAFT/python_env/bin/pip install --upgrade pip || true
/home/miguel7736/MINECRAFT/BOT_MINECRAFT/python_env/bin/pip install discord.py mcstatus asyncio-dgram mcrcon || true

# 5. Servicios Systemd
chmod 644 /etc/systemd/system/*.service || true
chown root:root /etc/systemd/system/*.service || true
systemctl daemon-reload
systemctl enable mysql.service activar-wol.service dinero.service || true

# 6. MySQL
/usr/sbin/mysqld --user=mysql --daemonize

# 3. Esperar a que el archivo de socket esté disponible
echo "Esperando a que el socket de MySQL responda..."
while [ ! -S /var/run/mysqld/mysqld.sock ]; do
    sleep 1
done

mysql -e "CREATE DATABASE IF NOT EXISTS CONTI;"
mysql -e "CREATE DATABASE IF NOT EXISTS DINERO;"
mysql -e "CREATE DATABASE IF NOT EXISTS LOL;"

if [ -f /home/miguel7736/BBDDs/CONTI.sql ]; then
    mysql CONTI < /home/miguel7736/BBDDs/CONTI.sql
fi
if [ -f /home/miguel7736/BBDDs/DINERO.sql ]; then
    mysql DINERO < /home/miguel7736/BBDDs/DINERO.sql
fi
if [ -f /home/miguel7736/BBDDs/LOL.sql ]; then
    mysql LOL < /home/miguel7736/BBDDs/LOL.sql
fi

mysql -e "CREATE USER IF NOT EXISTS 'rootApi'@'localhost' IDENTIFIED BY 'Lamomia6760_';"
mysql -e "GRANT ALL PRIVILEGES ON CONTI.* TO 'rootApi'@'localhost';"
mysql -e "GRANT ALL PRIVILEGES ON DINERO.* TO 'rootApi'@'localhost';"
mysql -e "CREATE USER IF NOT EXISTS 'rootLol'@'localhost' IDENTIFIED BY 'Lamomia6760_';"
mysql -e "GRANT ALL PRIVILEGES ON LOL.* TO 'rootLol'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

sed -i 's/bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf

# 7. SSH

cat << 'EOF' >> /etc/ssh/sshd_config

# Configuración personalizada de seguridad
Port 2222
PasswordAuthentication no
MaxAuthTries 3
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys .ssh/authorized_keys2
EOF

# 8. Firewall

ufw allow 25565/tcp comment 'Minecraft Server'
ufw allow 25575/tcp comment 'Minecraft RCON'
ufw allow 2222/tcp  comment 'SSH Custom Port'
ufw allow 3306/tcp  comment 'MySQL Server'
ufw allow 8080/tcp  comment 'App Port 8080'
ufw allow 8081/tcp  comment 'App Port 8081'
ufw allow 8082/tcp  comment 'App Port 8082'

ufw --force enable

# 9. Sudoers y Permisos
echo "miguel7736 ALL=(ALL) NOPASSWD: /bin/systemctl, /sbin/reboot, /sbin/shutdown" > /etc/sudoers.d/miguel7736
chmod 0440 /etc/sudoers.d/miguel7736
chown root:root /etc/sudoers.d/miguel7736
chown -R miguel7736:miguel7736 /home/miguel7736
chmod -R u+rwX /home/miguel7736
