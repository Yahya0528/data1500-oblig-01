-- ==============================
-- OPPRETT TABELLER (RIKTIG REKKEFØLGE)
-- ==============================

CREATE TABLE Kunde (
    kunde_id SERIAL PRIMARY KEY,
    mobilnr VARCHAR(15) UNIQUE NOT NULL,
    epost VARCHAR(100) UNIQUE NOT NULL,
    fornavn VARCHAR(50) NOT NULL,
    etternavn VARCHAR(50) NOT NULL,
    CONSTRAINT chk_mobilnr CHECK (mobilnr ~ '^[0-9+][0-9]{7,14}$'),
    CONSTRAINT chk_epost CHECK (epost ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

CREATE TABLE Stasjon (
    stasjon_id SERIAL PRIMARY KEY,
    stasjonsnavn VARCHAR(100) NOT NULL,
    adresse VARCHAR(200) NOT NULL
);

CREATE TABLE Laas (
    laas_id SERIAL PRIMARY KEY,
    stasjon_id INTEGER NOT NULL REFERENCES Stasjon(stasjon_id),
    status VARCHAR(20) NOT NULL DEFAULT 'aktiv'
        CHECK (status IN ('aktiv', 'ute_av_drift'))
);

CREATE TABLE Sykkel (
    sykkel_id SERIAL PRIMARY KEY,
    tatt_i_bruk DATE NOT NULL DEFAULT CURRENT_DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'ledig'
        CHECK (status IN ('ledig', 'utleid', 'ute_av_drift')),
    current_stasjon_id INTEGER REFERENCES Stasjon(stasjon_id),
    current_laas_id INTEGER UNIQUE REFERENCES Laas(laas_id),
    CONSTRAINT chk_plassering CHECK (
        (current_stasjon_id IS NULL AND current_laas_id IS NULL) OR
        (current_stasjon_id IS NOT NULL AND current_laas_id IS NOT NULL)
    )
);

CREATE TABLE Utleie (
    utleie_id SERIAL PRIMARY KEY,
    kunde_id INTEGER NOT NULL REFERENCES Kunde(kunde_id),
    sykkel_id INTEGER NOT NULL REFERENCES Sykkel(sykkel_id),
    laas_id_ut INTEGER NOT NULL REFERENCES Laas(laas_id),
    laas_id_inn INTEGER REFERENCES Laas(laas_id),
    utleietidspunkt TIMESTAMP NOT NULL,
    innleveringstidspunkt TIMESTAMP,
    leiebeloep DECIMAL(10,2),
    CONSTRAINT chk_innlevering CHECK (
        innleveringstidspunkt IS NULL
        OR innleveringstidspunkt > utleietidspunkt
    ),
    CONSTRAINT chk_belop CHECK (leiebeloep IS NULL OR leiebeloep >= 0)
);

-- Hindre mer enn én aktiv utleie per sykkel
CREATE UNIQUE INDEX idx_aktiv_utleie
ON Utleie(sykkel_id)
WHERE innleveringstidspunkt IS NULL;


-- ==============================
-- TESTDATA
-- ==============================

INSERT INTO Kunde (mobilnr, epost, fornavn, etternavn) VALUES
('+4798765432', 'ola.nordmann@email.com', 'Ola', 'Nordmann'),
('+4712345678', 'kari.hansen@email.com', 'Kari', 'Hansen'),
('+4745678901', 'per.olsen@email.com', 'Per', 'Olsen'),
('+4734567890', 'lise.berg@email.com', 'Lise', 'Berg'),
('+4723456789', 'tor.dahl@email.com', 'Tor', 'Dahl');

INSERT INTO Stasjon (stasjonsnavn, adresse) VALUES
('Sentrum Stasjon', 'Torggata 1'),
('Universitetet Stasjon', 'Sem Sælands vei 7'),
('Jernbanetorget Stasjon', 'Jernbanetorget 1'),
('Majorstuen Stasjon', 'Bogstadveien 30'),
('Grünerløkka Stasjon', 'Markveien 50');

-- 100 låser (20 per stasjon)
INSERT INTO Laas (stasjon_id)
SELECT s.stasjon_id
FROM Stasjon s
CROSS JOIN generate_series(1, 20);

-- 100 sykler
INSERT INTO Sykkel (tatt_i_bruk)
SELECT (DATE '2022-01-01' + (random() * 730)::int)
FROM generate_series(1, 100);

-- 50 utleier (noen pågående)
WITH tilfeldig AS (
    SELECT
        k.kunde_id,
        s.sykkel_id,
        l.laas_id,
        timestamp '2023-01-01'
            + random() * (timestamp '2023-12-31'
            - timestamp '2023-01-01') AS start_tid
    FROM Kunde k
    CROSS JOIN Sykkel s
    CROSS JOIN Laas l
    ORDER BY random()
    LIMIT 50
)
INSERT INTO Utleie (
    kunde_id,
    sykkel_id,
    laas_id_ut,
    laas_id_inn,
    utleietidspunkt,
    innleveringstidspunkt,
    leiebeloep
)
SELECT
    t.kunde_id,
    t.sykkel_id,
    t.laas_id,
    CASE WHEN random() > 0.2 THEN t.laas_id ELSE NULL END,
    t.start_tid,
    CASE WHEN random() > 0.2
         THEN t.start_tid + interval '2 hours'
         ELSE NULL
    END,
    CASE WHEN random() > 0.2
         THEN (random() * 200)::decimal(10,2)
         ELSE NULL
    END
FROM tilfeldig t;


-- ==============================
-- TILGANGSKONTROLL
-- ==============================

CREATE ROLE kunde;

CREATE USER kunde_1 WITH PASSWORD 'sikkert_passord';
GRANT kunde TO kunde_1;

CREATE TABLE app_user_kunde (
    db_user VARCHAR(100) PRIMARY KEY,
    kunde_id INTEGER REFERENCES Kunde(kunde_id)
);

INSERT INTO app_user_kunde (db_user, kunde_id)
VALUES ('kunde_1', 1);

CREATE VIEW kunde_egne_utleier AS
SELECT u.*
FROM Utleie u
JOIN app_user_kunde a
    ON u.kunde_id = a.kunde_id
WHERE a.db_user = current_user;

GRANT SELECT ON Sykkel, Stasjon, Laas, Kunde TO kunde;
GRANT SELECT ON kunde_egne_utleier TO kunde;

REVOKE ALL ON Utleie FROM kunde;