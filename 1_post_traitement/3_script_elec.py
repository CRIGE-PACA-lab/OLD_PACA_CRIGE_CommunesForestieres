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
TABLE_BT 		   = 'reseau-aerien-basse-tension-bt'
TABLE_HT		   = 'reseau-aerien-haute-tension-ht'
TABLE_HTA 		   = 'reseau-aerien-moyenne-tension-hta'
TABLE_VF 		   = 'troncon_de_voie_ferree'
TABLE_BDFORET      = 'bd_foret'

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
        'schema_travail': f"{insee}_elec",

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
		'TABLE_BT' : TABLE_BT, 		
		'TABLE_HT' : TABLE_HT,		
		'TABLE_HTA' : TABLE_HTA, 	
		'TABLE_VF' : TABLE_VF,	
		'TABLE_BDFORET' : TABLE_BDFORET,
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

--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--
------------------------------------- ⚡ LIGNES ELECTRIQUES ⚡ -------------------------------------
--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--
--- Identifier les obligations légales de débroussaillement (OLD) générées par les infrastrutures  ---
--- de transport d'éléctricité les gestionnaires chargés de leur exécution.	   ---
--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--
--- Auteurs : CRIGE PACA, Communes forestières PACA                                                ---                    
--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--


--*------------------------------------------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------------------------------------------*--
----------------------------------------- Données nécéssaires ----------------------------------------------------------------------------------------
--- Lignes électriques aériennes Basse Tension (BT) téléchargeable sur le site de l'Agence ORE renommé "r_bdtopo"."reseau-aerien-basse-tension-bt"       ---
--- Lignes électriques aériennes moyenne tension (HTA) téléchargeable sur le site de l'Agence ORE renommé "r_bdtopo"."reseau-aerien-moyenne-tension-hta" ---
--- Lignes électriques aériennes haute tension (HT) disponibles sur la BT TOPO renommé "r_bdtopo"."reseau-aerien-haute-tension-ht"				  ----
--- Contours forestiers de la BD Foret téléchargeable sur le site de l'IGN "r_bdtopo"."bd_foret"												  ----
--*------------------------------------------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--
----   INTEGRATION DU CODE INSEE DU DEPARTEMENT CONCERNEE                                                     ----
----                                                                                                          ----
----   Remplacer 83XXX   avec le code INSEE de la commune                                                       ----
----   Remplacer XXX par les 3 dernier chiffres du code commune
----   Remplacer AA par le code INSEE du département
----                                                                                                       ----
----   Exemple pour le département du VAR dont le code INSEE est 83                                           ----
----   Rechercher - remplacer "83XXX" par "83" (CTRL+f)                                                          ----
--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--

-----------------------------------------------------
--- Création du schéma et restart			      ---
-----------------------------------------------------

DROP SCHEMA IF EXISTS "{schema_travail}" CASCADE;
CREATE SCHEMA "{schema_travail}";
COMMIT;

CREATE INDEX ON "{SCHEMA_BDTOPO}".bd_foret USING GIST (geom);
COMMIT;

CREATE INDEX ON "{SCHEMA_PUBLIC}".old200m USING GIST (geom); 
COMMIT;

DELETE FROM "{SCHEMA_RESULTAT}"."{insee}_result_final_mcd"
WHERE id_ligne_elec IS NOT NULL; 
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--
--- Montage de la base de données -----------------------------------------
------------------------------------------------------------------------------
--- Résumé : Création des tables de la base de données (voir MCD)          ---
------------------------------------------------------------------------------

--*------------------------------------------------------------------------------------------------------------*--

--- Table lignes electriques ---

ALTER TABLE  "{SCHEMA_BDTOPO}"."reseau-aerien-haute-tension-ht"
ALTER COLUMN geom
TYPE geometry(Geometry, 2154)
USING ST_Force2D(geom);
COMMIT;

ALTER TABLE "{SCHEMA_BDTOPO}"."reseau-aerien-haute-tension-ht"
ALTER COLUMN geom TYPE geometry(Geometry, 2154) USING ST_SetSRID(geom, 2154);
COMMIT;

ALTER TABLE "{SCHEMA_BDTOPO}"."reseau-aerien-basse-tension-bt"
ALTER COLUMN geom TYPE geometry(Geometry, 2154) USING ST_SetSRID(geom, 2154);
COMMIT;

ALTER TABLE "{SCHEMA_BDTOPO}"."reseau-aerien-moyenne-tension-hta"
ALTER COLUMN geom TYPE geometry(Geometry, 2154) USING ST_SetSRID(geom, 2154);
COMMIT;

ALTER TABLE "{SCHEMA_BDTOPO}"."reseau-aerien-basse-tension-bt"
ADD COLUMN IF NOT EXISTS id_gest INTEGER,
ADD COLUMN IF NOT EXISTS id_zonage INTEGER,		
ADD COLUMN IF NOT EXISTS deb_m INTEGER; 
COMMIT;

ALTER TABLE "{SCHEMA_BDTOPO}"."reseau-aerien-moyenne-tension-hta"
ADD COLUMN IF NOT EXISTS id_gest INTEGER,
ADD COLUMN IF NOT EXISTS id_zonage INTEGER,
ADD COLUMN IF NOT EXISTS deb_m INTEGER;
COMMIT;

ALTER TABLE "{SCHEMA_BDTOPO}"."reseau-aerien-haute-tension-ht"
ADD COLUMN IF NOT EXISTS id_gest INTEGER,
ADD COLUMN IF NOT EXISTS id_zonage INTEGER,
ADD COLUMN IF NOT EXISTS deb_m INTEGER; 
COMMIT;

UPDATE "{SCHEMA_BDTOPO}"."reseau-aerien-basse-tension-bt"
SET 
id_gest = 17,
deb_m = 2 ; 
COMMIT;

UPDATE "{SCHEMA_BDTOPO}"."reseau-aerien-moyenne-tension-hta"
SET 
id_gest = 17,
deb_m = 2; 
COMMIT;

UPDATE "{SCHEMA_BDTOPO}"."reseau-aerien-haute-tension-ht"
SET 
id_gest = 16,
deb_m = case when voltage = '400 kV' then 40 else 20 end; 
COMMIT;

UPDATE "{SCHEMA_BDTOPO}"."reseau-aerien-basse-tension-bt" as a 
SET id_zonage = b.fid
from  "{SCHEMA_PUBLIC}".old200m  as b
where st_within(a.geom,b.geom); 
COMMIT;

UPDATE "{SCHEMA_BDTOPO}"."reseau-aerien-moyenne-tension-hta" as a 
SET id_zonage = b.fid
from "{SCHEMA_PUBLIC}".old200m as b
where st_within(a.geom,b.geom); 
COMMIT;

UPDATE "{SCHEMA_BDTOPO}"."reseau-aerien-haute-tension-ht" as a 
SET id_zonage = b.fid
from "{SCHEMA_PUBLIC}".old200m as b
where st_within(a.geom,b.geom); 
COMMIT;

DROP TABLE IF EXISTS "{SCHEMA_BDTOPO}".ligne_electrique;
CREATE TABLE  "{SCHEMA_BDTOPO}".ligne_electrique(
   id_ligne_elec SERIAL,
   id_source VARCHAR(50),
   voltage_kv VARCHAR,
   fonctionnement VARCHAR,
   source VARCHAR(50),
   deb_m INT,
   geom GEOMETRY,
   id_gest INT,
   id_zonage INT,
   PRIMARY KEY(id_ligne_elec)
);

COMMIT;

INSERT INTO "{SCHEMA_BDTOPO}".ligne_electrique( id_source,deb_m,geom,id_gest,id_zonage)
select id, deb_m, geom, id_gest, id_zonage
from "{SCHEMA_BDTOPO}"."reseau-aerien-basse-tension-bt";
COMMIT;

INSERT INTO "{SCHEMA_BDTOPO}".ligne_electrique( id_source,deb_m,geom,id_gest,id_zonage)
select id, deb_m, geom, id_gest, id_zonage
from "{SCHEMA_BDTOPO}"."reseau-aerien-moyenne-tension-hta";
COMMIT;

INSERT INTO "{SCHEMA_BDTOPO}".ligne_electrique(id_source,voltage_kv,fonctionnement,deb_m,geom,id_gest,id_zonage)
select cleabs,voltage,etat_de_l_objet,deb_m,geom,id_gest,id_zonage
from "{SCHEMA_BDTOPO}"."reseau-aerien-haute-tension-ht";
COMMIT;

UPDATE "{SCHEMA_BDTOPO}".ligne_electrique AS a
SET source = CASE WHEN voltage_kv is null then 'ore' else 'bd_topo' end;
COMMIT;

CREATE INDEX ON "{SCHEMA_BDTOPO}".ligne_electrique USING GIST (geom);
COMMIT;

DROP TABLE IF EXISTS "{schema_travail}"."{insee}_ligne_electrique";
CREATE TABLE "{schema_travail}"."{insee}_ligne_electrique" as 
SELECT a.*
FROM "{SCHEMA_BDTOPO}".ligne_electrique  as a,  "{SCHEMA_CADASTRE}".geo_commune as b
where b.idu = '{idu}' and st_intersects(a.geom,b.geom); 
COMMIT; 

CREATE INDEX ON "{schema_travail}"."{insee}_ligne_electrique" USING GIST (geom);
COMMIT;


--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--
--- II. Modélisation des Obligations 									   	     						   	   --- 
--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--

--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--

--- Résumé : la modélisation des OLD se déroule en 3 grandes étapes (II-a) : 		---														 
--- 1. Modélisation des OLD générées par les electriques : 							---
---		- Zone tampon de x m autour des lignes electriques 							---
---		- Découpage des OLD à l'intérieur du zonage OLD 						 	---
---		- Intersection avec le cadastre 										 	---
--- 2. Modélisation des OLD générées par les voies férrées (II-b) : 				---
---		-Zone tampon de x m + largeur de la voie autour des lignes de chemin de fer ---
---		- Découpage des OLD à l'intérieur du zonage OLD 						    ---
---		- Intersection avec le cadastre 											---
--- 3. Aggrégation des deux couches OLD (II-c)     								    ---
---------------------------------------------------------------------------------------
--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--


--*------------------------------------------------------------------------------------------------------------*--
--- Lignes electriques ---

DROP TABLE IF EXISTS "{schema_travail}".bd_foret;
CREATE TABLE "{schema_travail}".bd_foret as 
SELECT a.*
FROM "{SCHEMA_BDTOPO}".bd_foret as a,  "{SCHEMA_CADASTRE}".geo_commune as b
where b.idu = '{idu}' and st_intersects(a.geom,b.geom); 
COMMIT;

CREATE INDEX ON "{schema_travail}".bd_foret USING GIST (geom);
COMMIT;

drop table if exists "{schema_travail}".bd_foretrgr;
create table "{schema_travail}".bd_foretrgr as 
select ST_Union(a.geom) as geom
from  "{schema_travail}".bd_foret as a, "{SCHEMA_PUBLIC}".old200m as b
where st_intersects(a.geom,b.geom);
COMMIT;

CREATE INDEX ON "{schema_travail}".bd_foretrgr USING GIST (geom);
COMMIT;

drop table if exists "{schema_travail}".rte_ligne_temp0;
create table "{schema_travail}".rte_ligne_temp0 as 
select a.id_ligne_elec,
a.deb_m,
st_intersection(a.geom,b.geom) as geom
from "{schema_travail}"."{insee}_ligne_electrique"  as a, "{schema_travail}".bd_foretrgr as b 
where st_intersects(a.geom,b.geom);
COMMIT;

CREATE INDEX ON "{schema_travail}".rte_ligne_temp0 USING GIST (geom);
COMMIT;

drop table if exists "{schema_travail}".rte_ligne_temp1;
create table "{schema_travail}".rte_ligne_temp1 as 
select a.id_ligne_elec as id_ligne_elec,
st_buffer(a.geom,a.deb_m) as geom
from "{schema_travail}".rte_ligne_temp0 as a, "{schema_travail}".bd_foretrgr as b
where st_intersects(a.geom,b.geom);
COMMIT;

CREATE INDEX ON "{schema_travail}".rte_ligne_temp1 USING GIST (geom);
COMMIT;

drop table if exists "{schema_travail}".rte_ligne2_temp;
create table "{schema_travail}".rte_ligne2_temp as 
select a.id_ligne_elec as id_ligne_elec,
b.proprietaire as nom_prop, 
b.geo_parcelle,
b.comptecommunal as comptcom_prop,
b.adresse as adresse_prop, 
st_intersection(a.geom,b.geom) as geom
from "{schema_travail}".rte_ligne_temp1 as a,  "{SCHEMA_CADASTRE}".parcelle_info as b
where st_intersects(a.geom,b.geom);
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--
--- Aggrégation des OLD ---

INSERT INTO "AA_old50m_resultat"."{insee}_result_final_mcd"(nom_prop,comptcom_prop,geom_obligations_elec,id_ligne_elec,geo_parcel)
SELECT nom_prop,comptcom_prop,geom,id_ligne_elec,geo_parcelle
FROM "{schema_travail}".rte_ligne2_temp; 
COMMIT;

ALTER TABLE "AA_old50m_resultat"."{insee}_result_final_mcd" 
ADD COLUMN IF NOT EXISTS id_gest INT; 
COMMIT;

UPDATE "AA_old50m_resultat"."{insee}_result_final_mcd" as a 
SET id_gest = b.id_gest
FROM "{schema_travail}"."{insee}_ligne_electrique"  as b
WHERE a.id_ligne_elec = b.id_ligne_elec;
COMMIT;

UPDATE "AA_old50m_resultat"."{insee}_result_final_mcd" as a 
SET obl_nom = b.nom_gest,
obl_statut = b.statut,
obl_adresse = b.adresse
FROM "{SCHEMA_PUBLIC}".gestionnaires as b
WHERE a.id_gest = b.id_gest;
COMMIT;

UPDATE "AA_old50m_resultat"."{insee}_result_final_mcd"
SET id_old = concat(id_gest,'elec',fid_old),
surface_m2 = st_area(geom_obligations_elec)
WHERE id_ligne_elec IS NOT NULL;
COMMIT;

--*-----------------------------------------------------------------------------------------------------------*--
--*-----------------------------------------------------------------------------------------------------------*--
----                                 NETTOYAGE DU SCHÉMA DE TRAVAIL                                          ----
----                          (décommenter si suppression souhaitée)                                         ----
--*-----------------------------------------------------------------------------------------------------------*--
-- Description : Suppression complète du schéma de travail et de TOUTES ses tables (CASCADE).                ----
--               ATTENTION : Opération IRRÉVERSIBLE. À n''exécuter QUE si :                                  ----
--               • La table finale a été vérifiée et validée                                                 ----
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

