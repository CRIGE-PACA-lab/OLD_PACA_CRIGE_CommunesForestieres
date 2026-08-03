# -*- coding: utf-8 -*-
"""
MODULE_2_OLD50m_v2.3.py — Exécution automatisée du module OLD50m pour le département de la Drôme
Auteur : MJMartinat
Objectif : Générer les zones d’obligation légale de débroussaillement (OLD) a 50m a l'échelle départementale
"""

import os, logging, pandas as pd, time
from sqlalchemy import create_engine, text

# =============================================================================
# CONFIGURATION DU CONTEXTE DEPARTEMENTAL (DRÔME)
# =============================================================================

DEPT = '13'

# Schemas
SCHEMA_BDTOPO   = 'r_bdtopo'
SCHEMA_CADASTRE = 'r_cadastre'
SCHEMA_PUBLIC   = 'public'
SCHEMA_PARCELLE = f'{DEPT}_old50m_parcelle'
SCHEMA_BATI     = f'{DEPT}_old50m_bati'
SCHEMA_RESULTAT = f'{DEPT}_old50m_resultat'

# Tables
TABLE_COMMUNE      = 'geo_commune'
TABLE_PARCELLE     = 'parcelle_info'
TABLE_UF           = 'geo_unite_fonciere'
TABLE_BATI         = 'batiment'
TABLE_CIMETIERE    = 'cimetiere'
TABLE_INSTALLATION = 'zone_d_activite_ou_d_interet'
TABLE_ZONAGE       = f'{DEPT}_zonage_global'
TABLE_OLD200M      = 'old200m'
TABLE_EOLIEN       = 'eolien_filtre'
TABLE_PPRIF 	   = 'pprif'
TABLE_ADRESSE	   = 'adresse'
TABLE_LAP 		   = 'lien_adresse-parcelle'

# Base de donnees
DB_CONFIG = {
    "host": "localhost",
    "port": "port",
    "dbname": "nom_database",
    "user": "nom_utilisateur",
    "password": "mdp_utilisateur"
}

# =============================================================================
# INITIALISATION DU MOTEUR ET DES LOGS
# =============================================================================

engine = create_engine(
    f"postgresql://{DB_CONFIG['user']}:{DB_CONFIG['password']}@"
    f"{DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['dbname']}?client_encoding=UTF8",
    future=True
)

LOG_FILE = r"D:\projet_OLD\old50mV3\log\log_outil_old50m.log"
logging.basicConfig(
    filename=LOG_FILE, level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s", datefmt="%Y-%m-%d %H:%M:%S",
    encoding='utf-8'
)
logging.getLogger().addHandler(logging.StreamHandler())

# =============================================================================
# FONCTIONS UTILITAIRES
# =============================================================================

def get_communes(limit=None):
    """Récupère la liste des communes concernées par l’OLD200m."""
    query = f"""
        SELECT DISTINCT c.idu, c.tex2
        FROM {SCHEMA_CADASTRE}.{TABLE_COMMUNE} c
        JOIN {SCHEMA_PUBLIC}.{TABLE_OLD200M} o
        ON ST_Intersects(c.geom, o.geom)  -- Toutes les communes qui touchent
        WHERE 
		c.lot = '2'
         -- Filtrer pour garder seulement celles significativement impactées
         -- ST_Area(ST_Intersection(c.geom, o.geom)) / ST_Area(c.geom) > 0.01
         -- ou bien test du scrip python sur une seule commune
         -- c.commune = '260275'
       ORDER BY c.idu
    """
    if limit:
        query += f" LIMIT {limit}"
    with engine.connect() as conn:
        return pd.read_sql(query, conn)


def prepare_sql_for_commune(raw_sql, insee, idu):
    """Injecte dynamiquement les variables dans le SQL a exécuter pour chaque commune."""
    context = {
        'insee': f"{DEPT}{idu}",
        'idu': idu,
        'code_commune': f"{DEPT}2{idu}",
        'schema_travail': f"{DEPT}_adresse",

        # Schemas globaux
        'SCHEMA_BDTOPO': SCHEMA_BDTOPO,
        'SCHEMA_CADASTRE': SCHEMA_CADASTRE,
        'SCHEMA_PUBLIC': SCHEMA_PUBLIC,
        'SCHEMA_PARCELLE': SCHEMA_PARCELLE,
        'SCHEMA_BATI': SCHEMA_BATI,
        'SCHEMA_RESULTAT': SCHEMA_RESULTAT,

        # Tables
        'TABLE_COMMUNE': TABLE_COMMUNE,
        'TABLE_PARCELLE': TABLE_PARCELLE,
        'TABLE_UF': TABLE_UF,
        'TABLE_BATI': TABLE_BATI,
        'TABLE_CIMETIERE': TABLE_CIMETIERE,
        'TABLE_INSTALLATION': TABLE_INSTALLATION,
        'TABLE_ZONAGE': TABLE_ZONAGE,
        'TABLE_OLD200M': TABLE_OLD200M,
        'TABLE_EOLIEN': TABLE_EOLIEN,
		'TABLE_PPRIF' : TABLE_PPRIF,
		'TABLE_ADRESSE'	: TABLE_ADRESSE,
		'TABLE_LAP' : TABLE_LAP,
    }

    for key, value in context.items():
        raw_sql = raw_sql.replace(f"{{{key}}}", value)

    return raw_sql

def execute_module(insee, idu, tex2, sql_template):
    logging.info(f"--- Début traitement {insee}_{tex2} ---")
    sql_script = prepare_sql_for_commune(sql_template, insee, idu)
    try:
        with engine.begin() as conn:
            # Découpe les instructions SQL par point-virgule
            for statement in sql_script.strip().split(';'):
                if statement.strip():  # ignore les lignes vides
                    conn.execute(text(statement + ';'))
        logging.info(f"--- Fin traitement {insee}_{tex2} ---")
    except Exception as e:
        logging.error(f"Erreur sur {insee}_ ({tex2}) : {e}")

def fmt(t):  # transforme une durée au format hh:mm:ss
    h = int(t // 3600)
    m = int((t % 3600) // 60)
    s = int(t % 60)
    return f"{h:02d}:{m:02d}:{s:02d}"

# =============================================================================
# MODULE SQL EMBARQUE (a completer)
# =============================================================================

MODULE_SQL = """

-------------------------------------------------------------
----------------- OLD50m2MCD_PACA - Adresses ----------------
-------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- Ce script permet d'ajouter les adresses aux résultats de l'outil OLD50m après formatage selon le modèle de données.												 ---
--- Traitements sous PostgreSQL/PostGIS 																															 ---
--- Documentation de l'outil OLD50m : https://gitlab-forge.din.developpement-durable.gouv.fr/frederic.sarret/old_50m/ 												 ---	
--- Modèle de données OLD : https://github.com/CRIGE-PACA-lab/OLD_PACA_CRIGE_CommunesForestieres 																	 ---
----  Auteurs : CRIGE PACA, Communes forestières PACA    																						                                                 ---
----  Version : 1.00                                                                                 																 ---
------------------------------------------------------------------------------------------------------------------------------------------------------------------------																	

--*------------------------------------------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------------------------------------------*--
----------------------------------------- DONNEES NECESSAIRES ----------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------
--- Adresses (points) du produit BANPLUS diffusé par l'IGN     																					   ---
--- Lien Adresses-Parcelle (lignes) du produit BANPLUS diffusé par l'IGN 																		   ---
--*------------------------------------------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------------------------------------------*--

------------------------------------------------------------------------------------------------------------------
----   Remplacer "26xxx" par le code INSEE de la commune                                                      ----
----   Remplacer "AA" par le code INSEE du Département 
----   Si cadastre livré en plusieurs lots : pensez à changer la valeur intermédiaire ligne 47.   												  ----
------------------------------------------------------------------------------------------------------------------

--*------------------------------------------------------------------------------------------------------------*--
-----------------------------------------------------
--- Création du schéma							  ---
-----------------------------------------------------

DROP SCHEMA IF EXISTS  "{schema_travail}" CASCADE;
CREATE SCHEMA "{schema_travail}";
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--

--- Table adresse_parcelle : joiture des tables "parcelles_info" et "lien_bati_parcelle" ---

ALTER TABLE "{SCHEMA_BDTOPO}"."{TABLE_LAP}"
ADD COLUMN IF NOT EXISTS idu_cadastre VARCHAR; 
COMMIT;

UPDATE "{SCHEMA_BDTOPO}"."{TABLE_LAP}"
SET idu_cadastre = concat(left(idu,2),'1',right(idu,12)); --- Valeur intermédiaire à changer par '0','1' ou '2' si plusieurs lots au cadastre.
COMMIT;

DROP TABLE IF EXISTS "{schema_travail}".adresse_parcelle1; 
CREATE TABLE "{schema_travail}".adresse_parcelle1 AS 
SELECT a.geo_parcelle, 
a.comptecommunal,
b.id_adr
FROM "{SCHEMA_CADASTRE}"."{TABLE_PARCELLE}" as a, "{SCHEMA_BDTOPO}"."{TABLE_LAP}" as b 
WHERE a.geo_parcelle = b.idu_cadastre; 
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--

--- Table adresse_parcelle2 : ajout des points d'adresses ---


DROP TABLE IF EXISTS "{schema_travail}".adresse_parcelle2; 
CREATE TABLE "{schema_travail}".adresse_parcelle2 AS 
SELECT a.*, 
b."NUMERO" as numero,
b."REP" as rep,
b."NOM_VOIE" as nom_voie,
b."INSEE_COM" as insee_com,
b."NOM_COM" as nom_com,
b."POSITION" as position 
FROM "{schema_travail}".adresse_parcelle1 as a, "{SCHEMA_BDTOPO}".adresse as b 
WHERE a.id_adr = b."ID_ADR"; 
COMMIT;

ALTER TABLE "{schema_travail}".adresse_parcelle2 
ADD COLUMN IF NOT EXISTS adresse_concat TEXT;
COMMIT;

UPDATE "{schema_travail}".adresse_parcelle2
SET adresse_concat = concat(case 
when numero = '0' or numero = '99999' then null 
else numero end,' ',rep,' ',nom_voie,' ',insee_com,' ',nom_com);
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--

--- Insertion de l'adresse dans la table de résultats ---

ALTER TABLE "{SCHEMA_RESULTAT}"."{insee}_result_final_mcd"
ADD COLUMN IF NOT EXISTS obl_adresse TEXT;

UPDATE "{SCHEMA_RESULTAT}"."{insee}_result_final_mcd" AS a 
SET obl_adresse = b.adresse_concat
FROM "{schema_travail}".adresse_parcelle2 as b
WHERE a.obl_comptcom = b.comptecommunal;
COMMIT;


--*-----------------------------------------------------------------------------------------------------------*--
--*-----------------------------------------------------------------------------------------------------------*--
----                                 NETTOYAGE DU SCHÉMA DE TRAVAIL                                          ----
----                          (décommenter si suppression souhaitée)                                         ----
--*-----------------------------------------------------------------------------------------------------------*--
-- Description : Suppression complète du schéma de travail et de TOUTES ses tables (CASCADE).                ----
--               ATTENTION : Opération IRRÉVERSIBLE. À n''exécuter QUE si :                                  ----
--               • La table finale __CODE_INSEE___result_final a été vérifiée et validée                     ----
--               • Les exports nécessaires ont été réalisés                                                  ----
--               • Aucun besoin de traçabilité/debug des tables intermédiaires                               ----
--               Libère l''espace disque occupé par les tables temporaires de calcul.                        ----
--*-----------------------------------------------------------------------------------------------------------*--

DROP SCHEMA "{schema_travail}" CASCADE;
COMMIT;


"""


# =============================================================================
# EXECUTION PRINCIPALE
# =============================================================================

if __name__ == "__main__":
    start_total = time.perf_counter()   # début du traitement total

    logging.info(f"===== Lancement module OLD50m - Département {DEPT} =====")
    communes = get_communes()
   
    for _, row in communes.iterrows():
        start_iter = time.perf_counter()   # début de l’itération

        idu = str(row['idu']).zfill(3)
        insee = f"{DEPT}{idu}"
        code_commune = f"{DEPT}2{idu}"
        execute_module(insee, idu, row['tex2'], MODULE_SQL)

        elapsed_iter = time.perf_counter() - start_iter
        logging.info(f"Temps écoulé pour la commune {insee} : {fmt(elapsed_iter)}")

    total_elapsed = time.perf_counter() - start_total  # durée totale
    logging.info(f"===== Fin de traitement départemental — durée totale : {fmt(total_elapsed)} =====")

