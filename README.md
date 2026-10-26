# luci-app-portmanager

Управление портами роутера в LuCI на OpenWrt 25.x (rpcd/ucode, без CBI). Интерфейс на русском.

Универсальное для разного железа: поддерживает netdev/DSA, legacy swconfig и Wi-Fi точки доступа.

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

На роутере:

```sh
apk add --allow-untrusted luci-app-portmanager-1.0.0-r1.apk
```

Либо одной строкой из релиза GitHub:

```sh
wget -O /tmp/pm.apk https://github.com/jeysson89/luci-app-portmanager/releases/latest/download/luci-app-portmanager-1.0.0-r1.apk \
  && apk add --allow-untrusted /tmp/pm.apk
```

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

Готовый `luci-app-portmanager-1.0.0-r1.apk` лежит в релизах GitHub. Для пересборки используется сам роутер (`mkpkg` отсутствует в apk 3.0.5, поэтому берётся статический `apk` Alpine):

```powershell
# из корня репозитория, с копией sh.py рядом (root@192.168.1.1)
powershell -File dev\build-apk.ps1
```

Скрипт загружает `files/` в `/tmp/pkgroot`, `dev/build-apk.sh` в `/tmp/build-apk.sh`, собирает пакет и сохраняет его в `dist/`.

Или есть `Makefile` для OpenWrt SDK.

## Лицензия

GPL-3.0-or-later.
