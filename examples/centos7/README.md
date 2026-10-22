# Configurazione PHP-FPM e php.ini per CentOS 7 (Apache)

Questa directory contiene i file di configurazione di riferimento per un'installazione di PHP personalizzata (es. PHP 8.2 compilato in `/opt/php82`) su **CentOS 7** con server web **Apache (httpd)**.

I percorsi standard dei file sul server sono:
- Pool PHP-FPM: `/opt/php82/etc/php-fpm.d/www.conf`
- Configurazione PHP: `/opt/php82/lib/php.ini`

---

## 1. Modifiche essenziali in `www.conf`

Il file `www.conf` definisce il pool di worker FPM. Per farlo funzionare con Apache su CentOS 7 tramite UNIX socket, applicare i seguenti interventi minimi:

### 1.1 Utente e Gruppo del pool
In CentOS 7 Apache gira con utente e gruppo `apache` (a differenza di Debian/Ubuntu dove è `www-data` o `nobody` di default in PHP compilato da sorgenti):

```ini
user = apache
group = apache
```

### 1.2 Ascolto tramite Socket UNIX (invece di TCP)
L'utilizzo di un socket UNIX offre prestazioni migliori rispetto al socket TCP (evita l'overhead della rete di loopback).

Disabilitare la riga TCP (o commentarla) e impostare il path del socket:

```ini
; listen = 127.0.0.1:9082
listen = /opt/php82/var/run/php8.2-fpm.sock
```

> **Importante:** Verificare che la cartella `/opt/php82/var/run/` esista e abbia i permessi corretti:
> ```bash
> mkdir -p /opt/php82/var/run
> chown -R apache:apache /opt/php82/var/run
> ```

### 1.3 Permessi e Ownership del Socket UNIX
Se non si impostano esplicitamente owner e group del socket, Apache riceverà un errore `503 Service Unavailable` o `Permission Denied` tentando di connettersi:

```ini
listen.owner = apache
listen.group = apache
listen.mode = 0660
```

---

## 2. Modifiche minime consigliate in `php.ini`

Nel file `/opt/php82/lib/php.ini`, i parametri essenziali da impostare per un ambiente di produzione sono:

### 2.1 Fuso orario (`date.timezone`)
Evita warning continui nei log e funzioni di data/ora errate:
```ini
date.timezone = Europe/Rome
```

### 2.2 Limiti di memoria ed upload
Adeguare i valori di default (troppo restrittivi per la maggior parte dei CMS moderni):
```ini
memory_limit = 256M
upload_max_filesize = 64M
post_max_size = 64M
max_execution_time = 300
```

### 2.3 Sicurezza CGI / Pathinfo
Previene vulnerabilità nell'esecuzione di script con PHP-FPM:
```ini
cgi.fix_pathinfo = 0
```

### 2.4 OPcache
Assicurarsi che l'estensione OPcache sia abilitata per garantire le massime performance:
```ini
zend_extension=opcache
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
```

---

## 3. Integrazione con Apache (httpd) su CentOS 7

In Apache (tramite `mod_proxy` e `mod_proxy_fcgi`), per inoltrare le richieste PHP al socket FPM compilato in `/opt/php82`, aggiungere nella configurazione del VirtualHost (o in un file `.conf` in `/etc/httpd/conf.d/`):

```apache
<FilesMatch \.php$>
    SetHandler "proxy:unix:/opt/php82/var/run/php8.2-fpm.sock|fcgi://localhost"
</FilesMatch>
```

---

## 4. Riavvio e verifica dei servizi

Dopo aver salvato i file, riavviare o abilitare PHP-FPM e Apache:

```bash
# Riavvia il servizio systemd di PHP-FPM
systemctl restart php82-fpm

# Verifica lo stato e che il socket sia stato creato
systemctl status php82-fpm
ls -la /opt/php82/var/run/php8.2-fpm.sock

# Riavvia Apache
systemctl restart httpd
```
