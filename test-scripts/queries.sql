-- 5.1
SELECT * FROM Sykkel;

-- 5.2
SELECT etternavn, fornavn, mobilnr
FROM Kunde
ORDER BY etternavn;

-- 5.3
SELECT *
FROM Sykkel
WHERE tatt_i_bruk > DATE '2023-04-01';

-- 5.4
SELECT COUNT(*) AS antall_kunder
FROM Kunde;

-- 5.5
SELECT
  k.kunde_id,
  k.fornavn,
  k.etternavn,
  COUNT(u.utleie_id) AS antall_utleier
FROM Kunde k
LEFT JOIN Utleie u ON k.kunde_id = u.kunde_id
GROUP BY k.kunde_id, k.fornavn, k.etternavn;

-- 5.6
SELECT k.*
FROM Kunde k
LEFT JOIN Utleie u ON k.kunde_id = u.kunde_id
WHERE u.utleie_id IS NULL;

-- 5.7
SELECT sy.*
FROM Sykkel sy
LEFT JOIN Utleie u ON sy.sykkel_id = u.sykkel_id
WHERE u.utleie_id IS NULL;

-- 5.8
SELECT
  sy.sykkel_id,
  k.fornavn,
  k.etternavn,
  k.mobilnr,
  u.utleietidspunkt
FROM Sykkel sy
JOIN Utleie u ON sy.sykkel_id = u.sykkel_id
JOIN Kunde k ON u.kunde_id = k.kunde_id
WHERE u.innleveringstidspunkt IS NULL
  AND u.utleietidspunkt < NOW() - INTERVAL '24 hours';