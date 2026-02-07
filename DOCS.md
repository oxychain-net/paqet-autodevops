# 🚀 Paqet AutoDevOps - Enterprise Installer Suite

> **Production-Grade Installation & Configuration System for Paqet**
> 
> Zero-configuration, intelligent, self-healing deployment system

---

## 📋 نمای کلی سیستم (System Overview)

این مجموعه شامل **3 اسکریپت اصلی** برای نصب، پیکربندی و مدیریت کامل Paqet می‌باشد:

### 🔧 اجزای سیستم

1. **`paqet-prerequisites.sh`** - نصب پیش‌نیازها و بهینه‌سازی سرور
2. **`paqet-installer.sh`** - نصب و پیکربندی هوشمند Paqet  
3. **`paqet-manager.sh`** - مدیریت و نظارت بر سرویس

---

## 📥 نصب سریع (Quick Install)

```bash
# دانلود و اجرای یک‌مرحله‌ای
curl -fsSL https://raw.githubusercontent.com/oxychain-net/paqet-autodevops/main/install.sh | sudo bash
```

یا نصب دستی:

```bash
# دانلود اسکریپت‌ها
wget https://raw.githubusercontent.com/oxychain-net/paqet-autodevops/main/paqet-prerequisites.sh
wget https://raw.githubusercontent.com/oxychain-net/paqet-autodevops/main/paqet-installer.sh
wget https://raw.githubusercontent.com/oxychain-net/paqet-autodevops/main/paqet-manager.sh

# اعطای مجوز اجرا
chmod +x paqet-*.sh

# اجرای نصب کامل
sudo ./paqet-installer.sh --full-install
```

---

## 🎯 ویژگی‌های کلیدی

### ✨ نصب خودکار کامل
- ✅ نصب خودکار Go 1.25+ (در صورت نیاز)
- ✅ نصب و پیکربندی libpcap
- ✅ دریافت و کامپایل Paqet از GitHub
- ✅ تشخیص خودکار معماری سیستم (AMD64/ARM64)

### 🧠 پیکربندی هوشمند
- 🔍 تشخیص خودکار نوع سرور (Client/Server)
- 🌐 شناسایی خودکار Interface شبکه
- 📡 تشخیص IP و MAC Address
- 🔐 تولید خودکار کلید رمزنگاری (Secret Key)

### 🛡️ امنیت و بهینه‌سازی
- 🔥 پیکربندی خودکار iptables (Server)
- ⚡ بهینه‌سازی Kernel (BBR, TCP)
- 🎛️ تنظیمات MTU بهینه
- 📊 Monitoring و Health Check

### 🔄 مدیریت حرفه‌ای
- 📋 منوی تعاملی کاربرپسند
- ✏️ ویرایش آسان تنظیمات
- 🔄 راه‌اندازی مجدد هوشمند
- 📈 نمایش وضعیت و لاگ‌ها

---

# 📦 اسکریپت 1: نصب پیش‌نیازها (`paqet-prerequisites.sh`)


---

# 📦 اسکریپت 2: نصب‌کننده هوشمند Paqet (`paqet-installer.sh`)

به دلیل محدودیت حجم پاسخ، **قسمت اول** اسکریپت نصب‌کننده را ارائه می‌دهم:

```bash
```

---
# 📦 اسکریپت 3: مدیریت و نظارت Paqet (`paqet-manager.sh`)

```bash
```

---

# 📦 اسکریپت 4: نصب یک‌مرحله‌ای (`install.sh`)

```bash
```

---

# 📚 مستندات کامل (`README.md`)

```markdown
```

---

## 🎯 خلاصه و نتیجه‌گیری

این مجموعه شامل **4 اسکریپت اصلی** است:

### 1️⃣ `paqet-prerequisites.sh` (نصب پیش‌نیازها)
- نصب Go, libpcap, build tools
- بهینه‌سازی Kernel (BBR)
- پیکربندی System Limits
- تنظیم Time Sync & Entropy

### 2️⃣ `paqet-installer.sh` (نصب‌کننده هوشمند)
- ویزارد تعاملی کامل
- تشخیص خودکار شبکه
- تولید Secret Key
- ساخت Systemd Service
- پیکربندی Firewall (Server)

### 3️⃣ `paqet-manager.sh` (مدیریت و نظارت)
- کنترل سرویس
- مشاهده و صادرات لاگ
- ویرایش تنظیمات
- مانیتورینگ Health
- Backup & Restore
- Watchdog نصب/حذف
- مدیریت Firewall

### 4️⃣ `install.sh` (نصب یک‌مرحله‌ای)
- دانلود خودکار اسکریپت‌ها
- اجرای ترتیبی Prerequisites → Installer
- نصب دائمی اسکریپت‌ها

---

### 🚀 برای شروع:

```bash
curl -fsSL https://raw.githubusercontent.com/oxychain-net/paqet-autodevops/main/install.sh | sudo bash
```

**تمام!** کاربر فقط یک دستور اجرا می‌کند و سیستم به صورت خودکار همه چیز را انجام می‌دهد. 🎉
