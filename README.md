# 🚀 The PHP Compiler Script ![.github/workflows/compile-tests.yml](https://github.com/SergiX44/ISPC-PHPCompiler/workflows/.github/workflows/compile-tests.yml/badge.svg)

This script will help you to manage different PHP version for your webserver (especially made for ISPConfig installations).
This supports **auto compiling and auto configure feature** with a **very high optimization level** (`-O3` `-march=native` `-mtune=native` flags) for PHP >= 5.6. See the versions.sh file to see them.

At every launch a new version of the `versions.sh` file is imported from this repository, it **ensure always up to date links and builds**.

# How to use

Just run this command in your shell to download and run the script, and then just follow the instruction on your screen:

```bash
wget https://raw.githubusercontent.com/IDS-Unitelm/ISPC-PHPCompiler/bash-version/php-compiler.sh; chmod +x php-compiler.sh; bash php-compiler.sh
```

# Currently supported platforms

| OS \ PHP     	| 5.6 	| 7.0 	| 7.1 	| 7.2 	| 7.3 	| 7.4 	| 8.0 	| 8.1  | 8.2  | 8.3  | 8.4  |
|--------------	|-----	|-----	|-----	|-----	|-----	|-----	|-----	|-----	|-----	|-----	|-----	|
| Debian 9     	|     	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	|      |      |
| Debian 10    	|     	|     	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	|
| Debian 11    	|     	|     	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	|
| CentOS 7 *   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	|
| Ubuntu 18.04 **|     	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	|
| Ubuntu 20.04 	|     	|     	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	|
| Ubuntu 22.04 *** |   	|     	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	| ✔️   	|

(*) On CentOS 7, OpenSSL 1.1.1w and libzip are compiled automatically in isolated prefixes when building PHP >= 8.0.
(**) On Ubuntu 18.04, third-party repository conflicts (e.g. `deb.sury.org`) are automatically handled by compiling dependencies (OpenSSL 1.1.1w, libxml2, libxslt, libzip, ICU) into `/opt/php-deps` with runtime RPATH isolation, leaving existing production PHP services intact.
(***) On Ubuntu 22.x PHP <= 8.0 only without OpenSSL.

## Experimental: PHP 7.4 CVE mitigation

The menu includes **PHP 7.4.31-dev CVE-2026 patched**, built from the PHP source commit `712e60f9edfd03f0960fc4fc3c2c375f42b90aa2` on the upstream `PHP-7.4-CVE-2026-109618-109619` branch. The source archive is pinned to that commit and verified with SHA-256 before extraction; the build does not follow the moving branch name. This commit's `main/php_version.h` identifies it as PHP 7.4.31-dev, not 7.4.33.

This is a community backport for an end-of-life PHP line, not an official PHP release or a replacement for upgrading to a supported PHP version. It installs separately under `/opt/php74-cve`, creates the `php74-cve` command and `php74-cve-fpm` service, and does not automatically change the system `php` alternative. Build preparation requires `autoconf`, `bison`, and `re2c`.

The mitigation changes multipart parsing and disables the RFC1867 upload-progress callback. Test application uploads and any use of `PHP_SESSION_UPLOAD_PROGRESS` before production deployment. Run the PHP test suite and the project's `tests/` checks on the target operating system before relying on this build.

See [the PHP 7.4 CVE build notes](examples/php74-cve/README.md) for installation, validation, and rollback guidance.

# EOL

The script should also work on:

- Ubuntu 14.04
- Ubuntu 16.04
- Ubuntu 17.04
- Ubuntu 17.10
- Devuan 1
- Devuan 2
- Devuan 3
- Debian 8
- CentOS 8

But these platforms are no longer tested.

# Contributors

| [](https://github.com/SergiX44)         | [](https://github.com/Pe46dro)        |
| -------------------------------------- | ------------------------------------ |
| [SergiX44](https://github.com/SergiX44) | [Pe46dro](https://github.com/Pe46dro) |
