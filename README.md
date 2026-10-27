# Ubuntu-Autoinstall
Instalacion desatendida de ubuntu con subiquity ( cloud-init )

Primero elegimos la ISO a modificar ( en mi caso he elegido Ubuntu-26.04.1-live-server ). Montamos la ISO:

```bash
mkdir -p /tmp/ubuntu_mount                                                         # Donde se monta la ISO
mkdir -p /home/miguel7736/ubuntu-custom/ubuntu_server_iso                          # Donde copiarás los archivos de la ISO

sudo mount -o loop ubuntu-26.04.1-live-server.iso /tmp/ubuntu_mount                # Montamos la ISO
rsync -a /tmp/ubuntu_mount/ /home/miguel7736/ubuntu-custom/ubuntu_server_iso/      # Copiamos el contenido a la carpeta deseada con 'rsync -a' para no perder los enlaces simbólicos

sudo umount /tmp/ubuntu_mount                                                      # Desmonta la ISO
```

Despues de esto son necesarios 2 archivos, meta-data y user-data. Estos irán dentro de una carpeta llamada nocloud, estando esta en el directorio raíz de la ISO desempaquetada:

***¡DEBEN LLAMARSE OBLIGATORIAMENTE user-data y meta-data, SIN EXTENSION DE ARCHIVO, DE LO CONTRARIO SUIBIQUITY NO LO RECONOCERÁ Y PASARÁ A LA INSTALACIÓN INTERACTIVA!***

- meta-data --> simplemente crearlo y dejarlo vacío.
```bash
touch meta-data
```
- user-data --> es el archivo que orquesta la instalación. Un ejemplo seria:
  
```yaml  
#cloud-config
autoinstall:
  version: 1
  
  interactive-sections:
    - storage
    
  locale: es_ES.UTF-8
  keyboard:
    layout: es

  # Red
  network:
    version: 2
    ethernets:
      enp1s0:  # ID de tu interfaz de red
        dhcp4: false
        addresses:
          - 192.168.77.91/24  # IP asignada
        routes:
          - to: default
            via: 192.168.77.1  # Gateway predeterminado
        nameservers:  # Servidores DNS
          addresses:
            - 192.168.77.1
            - 192.168.77.149
            - 1.1.1.1

  proxy: ""

  # Creación de usuario por defecto
  identity:
    realname: "Miguel"
    username: "miguel7736"
    password: "TuContraseñaCifrada"    # Utulizando el comando 'openssl passwd -6 Tucontraseñaentextoplano'
    hostname: "miguel-portatil"

  # Selección e instalación de paquetes debian/ubuntu
  packages:
    - build-essential
    - make
    - gcc-16
    - g++-16
    - pipx
    - openjdk-21-jdk
    - curl
    - git

  # Instalación de paquetes Snap
  snaps:
    - name: android-studio
      classic: true
    - name: postman

  # Comandos que se ejecutan DENTRO del sistema instalado justo antes de reiniciar
  late-commands:
    # Copiar el script de configuración y darle permisos de ejecución
    - cp /cdrom/custom_files/setup.sh /target/tmp/setup.sh
    - [curtin, in-target, --, chmod, "+x", /tmp/setup.sh]
    
    # Ejecutar el script dentro del entorno instalado
    - [curtin, in-target, --, /tmp/setup.sh]
    
    # Limpiar el script temporal
    - rm -f /target/tmp/setup.sh
```

El comando "curtin in-target --" realiza los cambios en el SO destino, normalmente se refiere al directorio /target.

[curtin, in-target, --, /tmp/setup.sh] --> Este comando ejecuta un script post-instalación con privilegios de administrador. Muy util si quieres copiar archivos o pre-instalar aplicaciones.

Para copiar archivos es muy sencillo, simplemente crea una carpeta en la raiz de la ISO desempaquetada, por ejemplo , 'custom_files'. Después de añadir todo lo necesario para copiar en el script , utilizas el comando cp. Por ejemplo:

```bash
cp -r /cdrom/custom_files/Android /home/miguel7736/
```
donde /cdrom es donde está montada la ISO.

Sirve tanto para Ubuntu Desktop como para live-server, la unica diferencia es si quieres conectarte por ssh y la seguridad. En ese caso añadir lo siguiente:

```yaml 
  # SSH
  ssh:
    install-server: true
    allow-pw: false  # Deshabilita la autenticación por contraseña
    authorized-keys:
      - ssh-ed25519 Tu-clave-ssh
      - ssh-ed25519 Tu-otra-clave-ssh

    
  updates: security
```



Una vez tienes los 2 archivos pasamos a la configuración del kernel. La iso tiene que saber que debe ver el fichero user-data y realizar la instalación automática. 
Para ello modificamos el archivo boot/grub/grub.cfg. Debe quedar algo así:

```grub
set timeout=1

loadfont unicode

set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

menuentry "Try or Install Ubuntu Server (Autoinstall)" {
    set gfxpayload=keep
    linux  /casper/vmlinuz autoinstall "ds=nocloud;s=/cdrom/nocloud/" --- quiet splash
    initrd /casper/initrd
}
grub_platform
if [ "$grub_platform" = "efi" ]; then
menuentry 'Boot from next volume' {
    exit 1
}
menuentry 'UEFI Firmware Settings' {
    fwsetup
}
fi
```

"autoinstall" indica que se instalara de manera automática y "ds=nocloud;s=/cdrom/nocloud/" le dice donde encontrar los archivos user-data y meta-data.

Deberia quedar estructurado así:

```bash
ubuntu_iso/
├── boot/
│   └── grub/
│       └── grub.cfg
├── nocloud/
│   ├── user-data
│   └── meta-data
└── custom_files/
```

Por últmo queda empaquetar de nuevo la ISO. Para ello vamos a necesitar las siguientes aplicaciones:

```bash
sudo apt install xorriso isolinux
```

Nos situamos en la carpeta de la ISO a empaquetar:

```bash
cd /home/miguel7736/ubuntu-custom/ubuntu_server_iso 
```

Y escribimos el siguiente comando:

```bash
xorriso -as mkisofs -r \
  -V "UBUNTU_AUTOINSTALL" \
  -o /Tu/Ruta/al/iso/ubuntu-26-04-1-desatendido.iso \
  -J -l -b boot/grub/i386-pc/eltorito.img \
  -c boot.catalog \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  .
```  
