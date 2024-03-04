# Programabilni generator talasnog oblika 
Programabilni generator talasnog oblika (eng. Programmable Waveform Generator - PWG) je sistem za generisanje talasnog oblika na osnovu ulaznih vremenskih odrednica, tj. timestamp-ova. Rezolucija sistema iznosi 20 ns.
Sistem se sastoji iz četiri modula, a to su:
- Brojač
- Izlazna logika
- Registarska mapa
- FIFO bafer

Brojački modul se sastoji od 64 bita od kojih viša 32 bita predstavljaju UNIX time, a niža 32 bita predstavljaju vrijeme u nano sekundama. Prije početka brojanja, potrebno je podesiti brojač na odgovarajuće sistemsko vrijeme.  

Izlaznu logiku čine komparator i D flip flop, a na samom izlazu ovog modula generišemo traženi talasni oblik.  

Registarska mapa se sastoji od 7 32-bitnih registara. U registru na nultoj adresi se čuva sistemsko vrijeme. Statusni registar se nalazi na prvoj adresi u mapi, a njega čine nekoliko flegova koji nam daju informacije o stanju FIFO bafera i stistemskog vremena( SYS_TIME_ERROR, FIFO_EMPTY, FIFO_FULL). Kontrolni registar se nalazi na drugoj adresi u registarskoj mapi, i sadrži tri flega: START_ENABLE, INTERRUPT ENABLE, SOFTWARE_RESET. Na preostale četiri adrese nalaze se registri FALL_TS_H, FALL_TS_L, RISE_TS_H, RISE_TS_L koji služe za čuvanje vremenskih odrednica potrebnih za generisanje talasnog oblika.  

FIFO bafer je komponenta koja služi za pohranjivanje korisnički definisanih vremenskih odrednica. Dubina FIFO bafera mora biti konfigurabilna. U pitanju je kružni bafer sa mogućnošću prepisivanja podataka.  

Sva konfiguracija i unos podataka u sistem korisniku je omogućena putem Avalon MM protokola, implementiranog unutar komponente registarskog fajla.