## Co
<!-- Jedno-dwa zdania: co zmienia ten PR. ID zadania z BACKLOG.md (np. `P1-003`). -->

## Dlaczego
<!-- Kryterium akceptacji z backlogu / problem, który to rozwiązuje. -->

## Jak testowano
<!-- Wklej wynik `make check` oraz raport agenta qa-playtester (dla zadań P0/P1). -->

```
make check →
```

## Ryzyka
<!-- Co może się zepsuć? Migracje save'ów, balans, zachowanie na urządzeniu, rollback. -->

## Checklist
- [ ] Testy dodane / zaktualizowane (nic nie osłabione ani wyłączone)
- [ ] `docs/GDD.md` zaktualizowany (jeśli zmiana mechaniki)
- [ ] Brak sekretów w diffie (keystore, .p8, JSON service account, klucze reklam)
- [ ] ≤ 300 zmienionych linii kodu (bez assetów i lock-files)
