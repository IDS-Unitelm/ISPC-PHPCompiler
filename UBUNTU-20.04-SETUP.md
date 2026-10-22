# Setup per Ubuntu 20.04

Questo documento contiene le istruzioni e i dettagli tecnici per preparare un sistema Ubuntu 20.04 per la compilazione di PHP utilizzando questo script.

> [!NOTE]
> **Risoluzione Automatica**: Nelle versioni recenti dello script `php-compiler.sh`, il conflitto con `libxml2` di sury.org viene rilevato e **risolto automaticamente** durante lo step di installazione dipendenze (tramite rilevamento dinamico della versione Ubuntu ufficiale e downgrade APT, oppure compilazione isolata di fallback in `/opt/php-deps`). Non è più necessario eseguire comandi manuali prima di avviare lo script.

## ⚠️ Problema libxml2 con Repository sury.org

Ubuntu 20.04 con repository sury.org attivi ha spesso libxml2 versione 2.9.14, ma **non ha il pacchetto libxml2-dev corrispondente**. Questo causa errori durante la compilazione PHP.

### Sintomi del problema:

- libxml2 installata dalla repo sury.org (versione 2.9.14)
- libxml2-dev non installabile o in conflitto
- Errore durante ./configure: `Package requirements (libxml-2.0 >= 2.9.0) were not met`
- File `libxml-2.0.pc` non trovato

## 🔧 Soluzione: Downgrade Automatico o Manuale di libxml2

Il downgrade a libxml2 2.9.10 (versione Ubuntu standard) risolve il problema ed è **completamente sicuro** per tutte le versioni PHP.

### Verifica Stato Sistema

Prima di procedere, verifica lo stato attuale:

```bash
# Verifica versione Ubuntu
cat /etc/os-release | grep VERSION_ID

# Verifica PHP esistente
php --version
which php

# Verifica libxml2 installata
dpkg -l | grep libxml2
apt-cache policy libxml2

# Verifica repository sury.org
ls -la /etc/apt/sources.list.d/ | grep -i sury
apt-cache policy | grep -i sury
```

## 📋 Procedura Completa di Installazione

### 1. Downgrade libxml2

```bash
# Downgrade a versione Ubuntu standard (2.9.10)
apt-get install --allow-downgrades libxml2=2.9.10+dfsg-5ubuntu0.20.04.10 -y
```

**Nota**: Se hai repository sury.org attivi e libxml2 già a 2.9.10, questo comando non farà nulla. È comunque sicuro eseguirlo.

### 2. Installa Pacchetti Development

```bash
# Installa libxml2-dev e libxslt1-dev
apt-get install libxml2-dev libxslt1-dev -y
```

### 3. Verifica Installazione

```bash
# Verifica pacchetti installati
dpkg -l | grep libxml2

# Output atteso:
# ii  libxml2:amd64      2.9.10+dfsg-5ubuntu0.20.04.10  amd64  GNOME XML library
# ii  libxml2-dev:amd64  2.9.10+dfsg-5ubuntu0.20.04.10  amd64  Development files for the GNOME XML library

# Verifica pkg-config
pkg-config --modversion libxml-2.0

# Output atteso:
# 2.9.10
```

### 4. Clona Repository

```bash
cd /root
git clone https://github.com/TUO-USERNAME/ISPC-PHPCompiler.git ISPC-PHPCompiler
cd ISPC-PHPCompiler
```

### 5. Verifica File Locale

```bash
# Verifica che versions.sh esista nella repo
ls -la versions.sh

# Lo script darà priorità a questo file locale invece di scaricarlo da remoto
```

### 6. Esegui Script

```bash
# Rendi eseguibile (se necessario)
chmod +x php-compiler.sh

# Lancia lo script
./php-compiler.sh
```

### 7. Configurazione FPM

Quando richiesto, inserisci la porta FPM:

- **Porta consigliata**: `9082` (convenzione: 90 + versione PHP)
- Lo script verifica automaticamente che la porta non sia già in uso

## ✅ Compatibilità PHP

Il downgrade di libxml2 da 2.9.14 → 2.9.10 è **completamente sicuro** e non rompe nessuna versione PHP:

| Versione PHP | Requisito libxml2 | Compatibilità 2.9.10   |
| ------------ | ----------------- | ---------------------- |
| PHP 7.4      | >= 2.8.0          | ✅ OK                  |
| PHP 8.0      | >= 2.9.0          | ✅ OK                  |
| PHP 8.1      | >= 2.9.0          | ✅ OK                  |
| PHP 8.2      | >= 2.9.4          | ✅ OK (2.9.10 > 2.9.4) |
| PHP 8.3      | >= 2.9.0          | ✅ OK                  |
| PHP 8.4      | >= 2.9.0          | ✅ OK                  |

**Motivo**: La differenza tra 2.9.10 e 2.9.14 riguarda solo bugfix minori, senza breaking changes nell'API.

## 🚨 Diagnostica Problemi

### Errore: "Package requirements (libxml-2.0 >= 2.9.0) were not met"

**Causa**: libxml2-dev non installato o pkg-config non trova il file .pc

**Soluzione**:

```bash
# Verifica file .pc
find /usr -name "libxml-2.0.pc" 2>/dev/null

# Se non trova nulla, reinstalla libxml2-dev
apt-get install --reinstall libxml2-dev -y
```

### Errore: Conflitto versione durante apt-get install

**Causa**: Repository sury.org fornisce libxml2 2.9.14 ma non libxml2-dev

**Soluzione**:

```bash
# Forza downgrade
apt-get install --allow-downgrades libxml2=2.9.10+dfsg-5ubuntu0.20.04.10 -y

# Poi installa -dev
apt-get install libxml2-dev -y
```

### PHP Esistenti smettono di funzionare?

**NO**. Il downgrade è retrocompatibile. Tutti i PHP già installati (da apt o compilati) continueranno a funzionare normalmente.

## 📦 Post-Installazione

Dopo la compilazione completata:

```bash
# Verifica installazione
ls -la /opt/php82/

# Verifica binario
/opt/php82/bin/php --version

# Verifica servizio FPM
systemctl status php82-fpm.service

# Verifica porta in ascolto
netstat -tulnp | grep 9082

# Test PHP
echo "<?php phpinfo();" | /opt/php82/bin/php
```

## 🔗 Link Utili

- Repository originale: [SergiX44/ISPC-PHPCompiler](https://github.com/SergiX44/ISPC-PHPCompiler)
- Branch utilizzato: `bash-version`
- File versioni: [versions.sh](./versions.sh)

## 📝 Note

- **Tempo compilazione**: ~10-20 minuti (dipende dalla CPU)
- **Spazio necessario**: ~500MB in `/usr/local/src/php-build`
- **PHP 7.4 esistente**: Rimarrà intatto, l'installazione è in `/opt/php82/`
- **Servizio systemd**: Creato automaticamente come `php82-fpm.service`
- **Init script**: Disponibile in `/etc/init.d/php82-fpm`

---

**Ultimo aggiornamento**: 22 Maggio 2026
