# luci-app-portmanager

Управление портами роутера в LuCI (rpcd/ucode, без CBI). Интерфейс на русском.

Универсальное для разного железа: поддерживает netdev/DSA, legacy swconfig и Wi-Fi точки доступа.

| Проверено | Версия | Менеджер пакетов |
|---|---|---|
| Cudy TR3000 v1 (MT7981) | OpenWrt 25.12.2 | apk |
| Xiaomi Mi Router AX3000T (MT7981) | OpenWrt 24.10.4 | opkg |
| прочее aarch64/mipsel + 23.05/24.10/25.x | — | apk или opkg (формат архива выбирается автоматически) |

## Что умеет

| Раздел | Для чего |
|--------|----------|
| **Порты** | Таблица портов: тип (WAN/LAN), состояние линка, скорость, MAC порта. Кнопка «Вкл/Выкл» включает и отключает порт (Ethernet — через `enabled` у netifd-устройства, Wi-Fi — через `disabled` у `wifi-iface`) |
| **Устройства за портом** | Раскрывающаяся строка таблицы: список клиентов с IP, MAC и именами, с кнопками удаления MAC-записей |
| **Очистка MAC** | FDB-очистка — только динамические записи моста (`bridge fdb flush ... dynamic`); ARP-очистка — построчно, только на LAN-устройствах и только динамические записи. WAN-записи (шлюз провайдера) и постоянные записи моста никогда не затрагиваются — связность не рвётся |
| **Неизвестные устройства** | Клиенты, найденные в FDB/ARP/DHCP, но не привязанные к конкретному порту |
| **Torch** | Активные соединения (данные conntrack) с подсчётом трафика, направления и скорости. Два фильтра одновременно: по порту и по устройству |

Один вызов `list` возвращает всё: порты, роли, клиентов, MAC-адреса — обновление каждые 5 секунд.

## Быстрая установка

Одной строкой (сам выберет apk/ipk и поставит зависимости):

```sh
wget -qO- https://raw.githubusercontent.com/jeysson89/luci-app-portmanager/main/install.sh | sh
```

Либо вручную:

```sh
# OpenWrt 25.x (apk)
wget -O /tmp/pm.apk https://github.com/jeysson89/luci-app-portmanager/releases/latest/download/luci-app-portmanager-1.0.0-r1.apk
apk add /tmp/pm.apk

# OpenWrt 23.05 / 24.10 (opkg)
wget -O /tmp/pm.ipk https://github.com/jeysson89/luci-app-portmanager/releases/latest/download/luci-app-portmanager_1.0.0-r1_all.ipk
opkg install /tmp/pm.ipk
```

Пакет подписан RSA-ключом (публичный ключ в `keys/`), поэтому на apk-системах работает обычный `apk add` и установка через веб-интерфейс LuCI (System → Software → Upload) без `--allow-untrusted`.

После установки откройте в браузере:

```
http://192.168.1.1/cgi-bin/luci/admin/network/portmanager
```

Зависимости (`luci-base`, `rpcd-mod-ucode`, `ip-bridge`) ставятся автоматически вместе с пакетом.

## Как это устроено

- **Бэкенд** — rpcd ucode-плагин `/usr/share/rpcd/ucode/portmanager`, ubus-объект `portmanager`:
  - `list` — порты (netdev/DSA/swconfig/Wi-Fi), клиенты (bridge FDB + ARP + DHCP);
  - `setEnabled` — включение/отключение порта;
  - `flushMac` — безопасная очистка FDB/ARP (см. таблицу выше);
  - `deleteMac` — удаление одной записи FDB/ARP;
  - `torch` — активные соединения из conntrack с байтами, направлением и портами.
- **Фронтенд** — view LuCI `/www/luci-static/resources/view/portmanager/main.js`, чистый DOM + пунктуальные RPC-вызовы.
- **ACL** — `read`: `list`, `torch`; `write`: `setEnabled`, `flushMac`, `deleteMac`.

## Сборка пакета (только если нужно пересобрать)

В релизах GitHub лежат оба формата: `luci-app-portmanager-1.0.0-r1.apk` (apk-системы, подписан) и `luci-app-portmanager_1.0.0-r1_all.ipk` (opkg-системы).

**ipk для OpenWrt 23.05/24.10** — собирается локально, SDK не нужен:

```sh
python dev\build-ipk.py     # -> dist\luci-app-portmanager_1.0.0-r1_all.ipk
```

**apk для OpenWrt 25.x** — собирается на самом роутере (в apk 3.0.5 нет mkpkg, берётся статический apk Alpine); требуется `sh.py` в корне репо и переменная `ROUTER_PASS`:

```powershell
ROUTER_PASS=... powershell -File dev\build-apk.ps1
```

Скрипт загружает `files/` в `/tmp/pkgroot`, ключ подписи `keys/*.rsa` в `/tmp/`, `dev/build-apk.sh` в `/tmp/build-apk.sh`, собирает подписанный пакет и сохраняет его в `dist/`.

Или есть `Makefile` для OpenWrt SDK.

## Лицензия

GPL-3.0-or-later.
