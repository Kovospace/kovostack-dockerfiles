TO-DO pred spustením aplikácie
==============================

- skopírovať nginx zložku s konfigurákom niekde na lokál a pripojiť ju ako volume
- v nginx zložke je aj konfigurák basic auth plugin, tiež to niekde na lokál nakopírovať a namountovať
  - v tejto zložke treba potom spustiť príkaz ```htpasswd -c .htpasswd myuser``` čim sa popridávajú užívatelia
