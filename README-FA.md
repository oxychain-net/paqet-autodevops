# 🚀 Paqet AutoDevOps - Enterprise Installation Suite

> **Production-grade automated installation, configuration, and management system for Paqet**

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/oxychain-net/paqet-autodevops)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

---

## 📋 فهرست مطالب

1. [معرفی](#معرفی)
2. [ویژگی‌ها](#ویژگیها)
3. [پیش‌نیازها](#پیشنیازها)
4. [نصب سریع](#نصب-سریع)
5. [راهنمای استفاده](#راهنمای-استفاده)
6. [پیکربندی پیشرفته](#پیکربندی-پیشرفته)
7. [عیب‌یابی](#عیبیابی)
8. [پشتیبانی](#پشتیبانی)

---

## 🎯 معرفی

**Paqet AutoDevOps** یک مجموعه کامل برای نصب، پیکربندی و مدیریت [Paqet](https://github.com/yourusername/paqet) می‌باشد که به کاربران غیرحرفه‌ای اجازه می‌دهد بدون نیاز به دانش عمیق Linux، یک سرور Paqet حرفه‌ای راه‌اندازی کنند.

### چرا AutoDevOps؟

- ❌ **بدون نیاز به دانش فنی عمیق**
- ✅ **نصب خودکار تمام پیش‌نیازها**
- ✅ **پیکربندی هوشمند بر اساس تشخیص خودکار شبکه**
- ✅ **مدیریت آسان از طریق منوی تعاملی**
- ✅ **پشتیبانی خودکار و نظارت 24/7**

---

## ✨ ویژگی‌ها

### 🔧 نصب و پیکربندی
- ✅ نصب خودکار Go 1.25+
- ✅ نصب و پیکربندی libpcap
- ✅ بهینه‌سازی کامل Kernel Linux (BBR, TCP)
- ✅ تشخیص خودکار Interface، IP، MAC Address
- ✅ تولید خودکار Secret Key رمزنگاری
- ✅ پیکربندی خودکار Firewall (Server)
- ✅ ساخت Systemd Service

### 🎛️ مدیریت
- 📊 داشبورد مانیتورینگ در زمان واقعی
- 🔄 کنترل سرویس (Start/Stop/Restart)
- 📝 ویرایشگر تنظیمات با اعتبارسنجی خودکار
- 📋 مشاهده و صادرات لاگ‌ها
- 🔐 چرخش خودکار Secret Key
- 💾 پشتیبان‌گیری و بازگردانی
- 🛡️ Watchdog خودترمیم‌کننده

### 📊 نظارت و تست
- ✅ آمار اتصالات در زمان واقعی
- ✅ تست اتصال SOCKS5/Server
- ✅ نظارت بر مصرف CPU/Memory
- ✅ بررسی وضعیت Firewall
- ✅ آمار خطاها

---

## 📦 پیش‌نیازها

### سیستم‌عامل‌های پشتیبانی‌شده:
- ✅ Ubuntu 18.04+ / Debian 10+
- ✅ CentOS 7+ / RHEL 7+
- ✅ Rocky Linux / AlmaLinux

### نیازمندی‌های سیستم:
- 🖥️ CPU: 1 Core+
- 💾 RAM: 512MB+ (1GB+ توصیه می‌شود)
- 💿 Disk: 1GB Free Space
- 🌐 Network: IPv4 یا IPv6
- 🔑 Root Access

---

## 🚀 نصب سریع

### روش 1: نصب یک‌مرحله‌ای (توصیه می‌شود)

```bash
curl -fsSL https://raw.githubusercontent.com/oxychain-net/paqet-autodevops/main/install.sh | sudo bash
```

### روش 2: نصب دستی

```bash
# دانلود اسکریپت‌ها
wget https://raw.githubusercontent.com/oxychain-net/paqet-autodevops/main/paqet-prerequisites.sh
wget https://raw.githubusercontent.com/oxychain-net/paqet-autodevops/main/paqet-installer.sh
wget https://raw.githubusercontent.com/oxychain-net/paqet-autodevops/main/paqet-manager.sh

# اعطای مجوز
chmod +x paqet-*.sh

# نصب پیش‌نیازها
sudo ./paqet-prerequisites.sh

# نصب Paqet
sudo ./paqet-installer.sh

# (اختیاری) کپی در /usr/local/bin
sudo cp paqet-*.sh /usr/local/bin/
```

---

## 📖 راهنمای استفاده

### گام 1: نصب پیش‌نیازها

```bash
sudo ./paqet-prerequisites.sh
```

این اسکریپت:
- ✅ Go 1.25+ را نصب می‌کند
- ✅ libpcap را نصب و پیکربندی می‌کند
- ✅ Kernel را بهینه می‌کند (BBR فعال)
- ✅ System Limits را تنظیم می‌کند
- ✅ Time Sync و Entropy را پیکربندی می‌کند

### گام 2: نصب Paqet

```bash
sudo ./paqet-installer.sh
```

**ویزارد تعاملی شما را راهنمایی می‌کند:**

#### 2.1. انتخاب نقش (Role)
```
1) Client - برای کاربران نهایی (SOCKS5 Proxy)
2) Server - برای سرور مرکزی
```

#### 2.2. پیکربندی شبکه
- Interface خودکار تشخیص داده می‌شود
- IP Address و MAC خودکار استخراج می‌شود
- فقط تأیید کنید!

#### 2.3. تنظیمات امنیت
- Secret Key خودکار تولید می‌شود
- **حتماً آن را ذخیره کنید!**

#### 2.4. بررسی و نصب
- تنظیمات را مرور کنید
- تأیید کنید و نصب آغاز می‌شود

### گام 3: مدیریت سرویس

```bash
sudo ./paqet-manager.sh
```

**منوی تعاملی:**

```
═══════════════════ Service Control ═══════════════════
 1) Start Service
 2) Stop Service
 3) Restart Service
 4) Service Status

═══════════════════ Monitoring ═══════════════════
 7) View Live Logs
14) Health Dashboard
15) Connection Statistics

═══════════════════ Configuration ═══════════════════
11) View Configuration
12) Edit Configuration
13) Rotate Secret Key

═══════════════════ Backup & Restore ═══════════════════
17) Create Backup
19) Restore Backup

═══════════════════ Advanced ═══════════════════
20) Install Watchdog
23) Configure Firewall Rules
```

---

## 🔧 پیکربندی پیشرفته

### تنظیمات Client

فایل: `/etc/paqet/client.yaml`

```yaml
role: "client"

log:
  level: "info"

socks5:
  - listen: "127.0.0.1:1080"

network:
  interface: "eth0"
  ipv4:
    addr: "192.168.1.100:0"
    router_mac: "aa:bb:cc:dd:ee:ff"

server:
  addr: "SERVER_IP:9999"

transport:
  protocol: "kcp"
  kcp:
    mode: "fast"
    key: "YOUR_SECRET_KEY"
```

### تنظیمات Server

فایل: `/etc/paqet/server.yaml`

```yaml
role: "server"

log:
  level: "info"

listen:
  addr: ":9999"

network:
  interface: "eth0"
  ipv4:
    addr: "10.0.0.100:9999"
    router_mac: "aa:bb:cc:dd:ee:ff"

transport:
  protocol: "kcp"
  kcp:
    mode: "fast"
    key: "YOUR_SECRET_KEY"
```

### پیکربندی Firewall (Server)

**روش 1: از طریق Manager**
```bash
sudo paqet-manager.sh
# انتخاب گزینه 23
```

**روش 2: دستی**
```bash
# جایگزین 9999 با پورت Listen خود
PORT=9999

iptables -t raw -A PREROUTING -p tcp --dport $PORT -j NOTRACK
iptables -t raw -A OUTPUT -p tcp --sport $PORT -j NOTRACK
iptables -t mangle -A OUTPUT -p tcp --sport $PORT --tcp-flags RST RST -j DROP

# ذخیره دائمی
iptables-save > /etc/iptables/rules.v4
```

---

## 🔍 عیب‌یابی

### مشکل 1: سرویس Start نمی‌شود

**علائم:**
```bash
systemctl status paqet-client
# ● paqet-client.service - failed
```

**راه‌حل:**
```bash
# 1. بررسی لاگ‌ها
journalctl -u paqet-client -n 50

# 2. تست دستی
sudo paqet run -c /etc/paqet/client.yaml

# 3. بررسی تنظیمات
paqet-manager.sh -> گزینه 11 (View Configuration)
```

### مشکل 2: اتصال برقرار نمی‌شود (Client)

**علائم:**
```bash
curl -x socks5h://127.0.0.1:1080 https://ifconfig.me
# Timeout
```

**راه‌حل:**
```bash
# 1. بررسی Server Address
grep "server:" /etc/paqet/client.yaml

# 2. تست ping به سرور
ping SERVER_IP

# 3. بررسی Secret Key
# باید در Client و Server یکسان باشد

# 4. بررسی لاگ‌های Server
ssh root@SERVER_IP
journalctl -u paqet-server -f
```

### مشکل 3: Firewall مشکل دارد (Server)

**علائم:**
```bash
# اتصالات ناپایدار، قطع شدن مکرر
```

**راه‌حل:**
```bash
# بررسی قوانین iptables
paqet-manager.sh -> گزینه 24

# اعمال مجدد قوانین
paqet-manager.sh -> گزینه 23

# تست دستی
iptables -t raw -L PREROUTING -n -v | grep 9999
```

### مشکل 4: BBR فعال نیست

**راه‌حل:**
```bash
# بررسی وضعیت فعلی
sysctl net.ipv4.tcp_congestion_control

# اگر "cubic" بود:
# 1. بررسی پشتیبانی Kernel
uname -r  # باید >= 4.9 باشد

# 2. اجرای مجدد prerequisites
sudo paqet-prerequisites.sh

# 3. Reboot
sudo reboot
```

---

## 📊 دستورات مفید

### مدیریت سرویس
```bash
# شروع
sudo systemctl start paqet-client

# توقف
sudo systemctl stop paqet-client

# راه‌اندازی مجدد
sudo systemctl restart paqet-client

# وضعیت
sudo systemctl status paqet-client

# فعال‌سازی در boot
sudo systemctl enable paqet-client
```

### مشاهده لاگ‌ها
```bash
# لاگ‌های زنده
sudo journalctl -u paqet-client -f

# 50 خط آخر
sudo journalctl -u paqet-client -n 50

# فقط خطاها
sudo journalctl -u paqet-client -p err

# از تاریخ خاص
sudo journalctl -u paqet-client --since "2026-01-01"
```

### تست اتصال
```bash
# تست SOCKS5 (Client)
curl -x socks5h://127.0.0.1:1080 https://ifconfig.me

# تست CloudFlare Trace
curl -x socks5h://127.0.0.1:1080 https://www.cloudflare.com/cdn-cgi/trace

# بررسی Listener (Server)
ss -tnlp | grep 9999
```

### مانیتورینگ
```bash
# مصرف CPU/Memory
ps aux | grep paqet

# اتصالات فعال (Client)
ss -tn | grep :1080

# اتصالات فعال (Server)
ss -tn | grep :9999

# ترافیک Interface
iftop -i eth0
```

---

## 🛡️ امنیت

### بهترین روش‌ها (Best Practices)

1. **Secret Key قوی استفاده کنید**
   ```bash
   # تولید خودکار (64 کاراکتر hex)
   head -c 32 /dev/urandom | xxd -p -c 32
   ```

2. **Firewall را پیکربندی کنید (Server)**
   ```bash
   # فقط پورت‌های ضروری را باز کنید
   ufw allow 22/tcp   # SSH
   ufw allow 9999/tcp # Paqet
   ufw enable
   ```

3. **Secret Key را چرخش دهید (به صورت دوره‌ای)**
   ```bash
   paqet-manager.sh -> گزینه 13
   ```

4. **پشتیبان‌گیری منظم**
   ```bash
   paqet-manager.sh -> گزینه 17
   ```

5. **لاگ‌ها را نظارت کنید**
   ```bash
   paqet-manager.sh -> گزینه 7
   ```

---

## 🔄 به‌روزرسانی

```bash
# 1. پشتیبان‌گیری
sudo paqet-manager.sh -> گزینه 17

# 2. دانلود نسخه جدید
wget https://raw.githubusercontent.com/.../paqet-installer.sh

# 3. اجرا
sudo ./paqet-installer.sh

# یا استفاده از Binary جدید
sudo paqet-installer.sh -> گزینه 5
```

---

## 🆘 پشتیبانی

### مستندات
- 📖 [Paqet Official Docs](https://github.com/yourusername/paqet)
- 💬 [Community Forum](https://forum.example.com)

### گزارش مشکل
اگر مشکلی پیدا کردید:
1. لاگ‌ها را جمع‌آوری کنید: `journalctl -u paqet-* > logs.txt`
2. تنظیمات را بررسی کنید (Secret Key را حذف کنید!)
3. Issue باز کنید: [GitHub Issues](https://github.com/oxychain-net/paqet-autodevops/issues)

---

## 📝 License

MIT License - [LICENSE](LICENSE)

---

## 🙏 سپاسگزاری

- [Paqet Project](https://github.com/yourusername/paqet)
- [OxyChain-Net](https://oxychain.net)
- Community Contributors

---

**Made with ❤️ by oxychain-net**
