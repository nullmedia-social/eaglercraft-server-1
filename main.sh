#!/bin/bash

# --- CONFIGURATION ---
setserver="true"
syncweb="true"
syncjars="true"
srvname="Your Minecraft Server"
srvmotd="Minecraft Server"
emergbukkit="false"

# --- INTERNAL VARIABLES ---
eagurl="https://raw.githubusercontent.com/LAX1DUDE/eaglercraft/main/stable-download/stable-download_repl.zip"
WORKDIR="/workspaces/$(basename "$PWD")"
NGINX_PID="/tmp/nginx/nginx.pid"
NGINX_ERR="/tmp/nginx/error.log"

# --- SETUP ---
echo "[*] Ensuring dependencies are installed..."
sudo apt-get update -y
sudo apt-get install -y openjdk-8-jdk curl unzip nginx

echo "[*] Killing any old server processes..."
pkill -f java || true
pkill -f nginx || true
rm -rf /tmp/*

if [ ! -f "updated.yet" ]; then
  syncweb="true"
  syncjars="true"
fi

echo "[*] Checking update site..."
status_code=$(curl -L --write-out %{http_code} --silent --output /dev/null "$eagurl")

if [[ "$status_code" -ne 200 ]] ; then
  syncweb="false"
  syncjars="false"
  echo "[!] Site is down, skipping updates..."
else
  echo "[*] Downloading new package..."
  curl -L -o stable-download.zip "$eagurl"
  mkdir /tmp/new
  unzip stable-download.zip -d /tmp/new
  rm -rf stable-download.zip

  mkdir -p web java/bungee_command java/bukkit_command

  if [ "$syncweb" = "true" ]; then
    echo "[*] Updating web folder..."
    rm -rf web/*
    cp -r /tmp/new/web/. ./web/
    cp web/index.html web/index.html.ORIG
  fi

  if [ "$syncjars" = "true" ]; then
    echo "[*] Updating BungeeCord..."
    if [ -f "updated.yet" ]; then
      rm -f java/bungee_command/bungee-dist.jar
      cp /tmp/new/java/bungee_command/bungee-dist.jar ./java/bungee_command/
    else
      rm -rf java/bungee_command/*
      cp -r /tmp/new/java/bungee_command/. ./java/bungee_command/
      sed -i 's/host: 0\.0\.0\.0:[0-9]\+/host: 0.0.0.0:25565/' java/bungee_command/config.yml
    fi

    echo "[*] Updating Bukkit..."
    if [ "$emergbukkit" = "true" ]; then
      rm -rf java/bukkit_command/*
      cp -r /tmp/new/java/bukkit_command/. ./java/bukkit_command/
    else
      rm -f java/bukkit_command/craftbukkit-1.5.2-R1.0.jar
      cp /tmp/new/java/bukkit_command/craftbukkit-1.5.2-R1.0.jar ./java/bukkit_command/
    fi
  fi

  rm -rf /tmp/new old
fi

if [ ! -f "updated.yet" ]; then
  touch updated.yet
fi

echo "[*] Starting BungeeCord..."
cd java/bungee_command
java -Xmx32M -Xms32M -jar bungee-dist.jar > /dev/null 2>&1 &
cd -

if [ "$setserver" = "true" -a "$syncweb" = "true" ]; then
  echo "[*] Configuring website..."
  rm web/index.html
  cp web/index.html.ORIG web/index.html
  sed -i 's/https:\/\/g\.eags\.us\/eaglercraft/https:\/\/gnome\.vercel\.app/' web/index.html
  sed -i 's/alert/console.log/' web/index.html
  sed -i "s/\"CgAACQAHc2VydmVycwoAAAABCAACaXAAIHdzKHMpOi8vIChhZGRyZXNzIGhlcmUpOihwb3J0KSAvCAAEbmFtZQAIdGVtcGxhdGUBAAtoaWRlQWRkcmVzcwEIAApmb3JjZWRNT1REABl0aGlzIGlzIG5vdCBhIHJlYWwgc2VydmVyAAA=\"/btoa(atob(\"CgAACQAHc2VydmVycwoAAAABCAAKZm9yY2VkTU9URABtb3RkaGVyZQEAC2hpZGVBZGRyZXNzAQgAAmlwAGlwaGVyZQgABG5hbWUAbmFtZWhlcmUAAA==\").replace(\"motdhere\",String.fromCharCode(\`$srvname\`.length)+\`$srvname\`).replace(\"namehere\",String.fromCharCode(\`$srvmotd\`.length)+\`$srvmotd\`).replace(\"iphere\",String.fromCharCode((\"ws\"+location.protocol.slice(4)+\"\/\/\"+location.host+\"\/server\").length)+(\"ws\"+location.protocol.slice(4)+\"\/\/\"+location.host+\"\/server\")))/" web/index.html
fi

echo "[*] Starting Nginx..."
mkdir -p /tmp/nginx
rm -f nginx.conf
sed "s/eaglercraft-server/$(basename "$PWD")/" nginx_template.conf > nginx.conf
nginx -c "$WORKDIR/nginx.conf" -g "daemon off; pid $NGINX_PID;" -p /tmp/nginx -e $NGINX_ERR > /tmp/nginx/output.log 2>&1 &

echo "[*] Starting Bukkit..."
cd java/bukkit_command
java -Xmx512M -Xms512M -jar craftbukkit-1.5.2-R1.0.jar
cd -

echo "[*] Cleaning up..."
nginx -s stop -c "$WORKDIR/nginx.conf" -g "daemon off; pid $NGINX_PID;" -p /tmp/nginx -e $NGINX_ERR || true
pkill -f java || true
pkill -f nginx || true

echo "[✓] Done!"