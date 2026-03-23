Zaplanuj utworzenie calego deploymentu klastra opensearch w GCP. Uzyj technologii ansible, packer oraz terraform. Uzywajac packer i ansible utworz jeden obraz, ktory w zaleznosci od ustawionych metadanych bedzie konkretnym nodem w klastrze. Klaster ma byc w jednym regionie i w 3 zonach aby zapewnic HA. Jest wymaganie aby na produkcji robic rotacje nowych obrazow raz w miesiacu. Base image to redhat. Dobrze aby byla mozliwosc robienia rotacji klastra w trybie online, czyli zona po zonie aby dane byly caly czas dostepne. Do klastra z  danymi bedzie potrzebny drugi klaster do monitoringu, czyli taki, ktory bedzie zbieral metryki i pokazywal je na Opensearch dashboard. Ma byc mozliwosc zarzadzania 3 srodowiskami dev, 3 uat oraz jednym prod. W ramach klastra prod moga byc wymagane nody koordynujace oraz data-hot.

Role:
master (master)
data (data, ingest)
coordinator (empty role)
hot-node (data-hot, ingest)
monitor (master, data, dashboard)