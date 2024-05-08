README


Dôležité príkazy, inicializácie - root
--------------------------------------

* Autoštart používateľa (docker beží v rootless režime)  
  - autoštart používateľa pod ktorým beží docker nie je možný, ale jednorázovým nastavením `loginctl enable-linger kovo` je možné sprístupniť akoby na pozadí 
    sedenie a procesy používateľa pod ktorým docker a kontajnery bežia