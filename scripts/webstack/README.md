# Web Stack Installer (Apache + PHP + MariaDB + SSL + phpMyAdmin)

A fully automated script to install a production-ready web stack on any Ubuntu VPS.  
Perfect for setting up multiple domains with SSL, secure databases, and phpMyAdmin in minutes.

---

## 🚀 Features

- Apache-only stack (no NGINX)
- PHP 7/8, MariaDB, and phpMyAdmin
- Automatic Let's Encrypt SSL with redirect
- Secure MyBB-style database created per domain
- Shared phpMyAdmin login page at `/phpmyadmin`
- Safe to re-run to add more domains
- Hardened settings (no root login to phpMyAdmin)
- UFW firewall rules applied
- Adds `Coming Soon` and `info.php` pages per site

---

## 🧠 Requirements

- Ubuntu 20.04 / 22.04 VPS
- Root SSH access
- Domains pointed to your server’s IP

---

## ⚙️ One-liner Installation

> Replace `example.com` and email as prompted:

```bash
bash <(curl -s https://raw.githubusercontent.com/codetwigdev/codetwig/main/scripts/webstack.sh)
```

---

## 🔁 Run Again for New Domains

This script is designed to be re-run to set up more domains.  
Each run:
- Creates a new Apache virtual host
- Secures it with SSL
- Adds its own database and user
- Links phpMyAdmin and sets up a landing page

---

## 📂 Output Example

- `/var/www/domain.com/` — website files
- `/root/db_domain.com.txt` — DB credentials
- `https://domain.com/info.php` — PHP test
- `https://domain.com/phpmyadmin` — login for DBs

---

## ✅ Example Use Case

1. Spin up a fresh VPS
2. Point `domain.com` to your IP
3. Run the one-liner script
4. Repeat for `client1.com`, `client2.com`, etc.

---

## 📃 License

MIT — free to use, modify, and distribute.