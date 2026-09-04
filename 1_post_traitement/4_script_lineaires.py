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

DEPT = 'XX'

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
TABLE_ROUTE 	   = 'troncon_de_route'
TABLE_VF 		   = 'troncon_de_voie_ferree'


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
        'schema_travail': f"{insee}_lineaires",

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
		'TABLE_ROUTE' : TABLE_ROUTE,
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

DROP SCHEMA IF EXISTS "{schema_travail}" CASCADE;
CREATE SCHEMA "{schema_travail}";
COMMIT;

DELETE FROM "{SCHEMA_RESULTAT}"."{insee}_result_final_mcd"
WHERE id_troncon IS NOT NULL; 
COMMIT;

DELETE FROM "{SCHEMA_RESULTAT}"."{insee}_result_final_mcd"
WHERE id_vf IS NOT NULL; 
COMMIT;

ALTER TABLE "{SCHEMA_BDTOPO}".troncon_de_route
ADD COLUMN IF NOT EXISTS id_zonage INTEGER; 
COMMIT;

DROP TABLE IF EXISTS "{schema_travail}".troncon_de_route_bdtopo;
CREATE TABLE "{schema_travail}".troncon_de_route_bdtopo as
SELECT a.*
FROM "{SCHEMA_BDTOPO}".troncon_de_route as a, "{SCHEMA_CADASTRE}".geo_commune as b 
WHERE b.idu = '{idu}' and st_intersects(a.geom,b.geom);
COMMIT;

UPDATE "{schema_travail}".troncon_de_route_bdtopo as a 
SET id_zonage = b.fid
from public.old200m as b 
where st_intersects(a.geom,b.geom);
COMMIT; 

DROP TABLE IF EXISTS "{schema_travail}".routes;
CREATE TABLE "{schema_travail}".routes(
   id_troncon SERIAL,
   cleabs VARCHAR(50),
   nature VARCHAR(50),
   importance VARCHAR(50),
   acces_vehicule_leger VARCHAR(50),
   nom_voie TEXT,
   cpx_numero VARCHAR(50),
   cpx_classement_administratif VARCHAR(50),
   cpx_gestionnaire VARCHAR(50),
   nombre_de_voies INT,
   largeur_de_chaussee INT,
   deb_m INTEGER,
   source VARCHAR(50),
   geom GEOMETRY,
   id_gest INT,
   id_zonage INT,
   PRIMARY KEY(id_troncon)
);
COMMIT;

insert into "{schema_travail}".routes(cleabs,nature,importance,acces_vehicule_leger, nom_voie, cpx_numero, cpx_classement_administratif, cpx_gestionnaire, nombre_de_voies,largeur_de_chaussee,geom,id_zonage)
select cleabs,nature,importance,acces_vehicule_leger,cpx_toponyme_route_nommee, cpx_numero,cpx_classement_administratif , cpx_gestionnaire,nombre_de_voies,largeur_de_chaussee,geom,id_zonage
from "{schema_travail}".troncon_de_route_bdtopo
where acces_vehicule_leger = 'Libre' or acces_vehicule_leger = 'A préage' and id_zonage is not null ; --- Seulement les routes ouvertes à la circulation et soumises aux OLD
COMMIT;

CREATE INDEX ON "{schema_travail}".routes USING GIST (geom);
COMMIT;

UPDATE "{schema_travail}".routes as a 
SET id_gest = b.id_gest
from "{SCHEMA_PUBLIC}".gestionnaires as b
where a.cpx_gestionnaire = b.nom_gest;
COMMIT;

UPDATE "{schema_travail}".routes 
SET cpx_gestionnaire = case 
					   when  cpx_gestionnaire is null then 'prive'
					   else cpx_gestionnaire end,
	deb_m = case when cpx_classement_administratif =  'Autoroute/Route nommée'  then 20 
 				 when cpx_classement_administratif = 'Départementale' or cpx_classement_administratif = 'Départementale/Route nommée'  then 10
  				 when cpx_classement_administratif = 'Nationale' or cpx_classement_administratif = 'Nationale/Route nommée'  then 10
 				 else 5 end ;
COMMIT;




ALTER TABLE "{SCHEMA_BDTOPO}".troncon_de_voie_ferree
ADD COLUMN IF NOT EXISTS id_gest INT,
ADD COLUMN IF NOT EXISTS id_zonage INT,
ADD COLUMN IF NOT EXISTS larg_m INT; 
COMMIT;

UPDATE "{SCHEMA_BDTOPO}".troncon_de_voie_ferree as a 
SET id_zonage = b.fid
from "{SCHEMA_PUBLIC}".old200m as b
where st_intersects(a.geom,b.geom); 
COMMIT;

UPDATE "{SCHEMA_BDTOPO}".troncon_de_voie_ferree 
SET id_gest = CASE WHEN largeur = 'Etroite' THEN 18
WHEN largeur = 'Normale' then 15
else null end; 
COMMIT;

UPDATE "{SCHEMA_BDTOPO}".troncon_de_voie_ferree  
SET larg_m = CASE WHEN largeur = 'Etroite' THEN 1
WHEN largeur = 'Normale' then 1.435
else null end; 
COMMIT;

DROP TABLE IF EXISTS "{SCHEMA_BDTOPO}".voies_ferees;
CREATE TABLE "{SCHEMA_BDTOPO}".voies_ferees(
   id_vf SERIAL,
   id_bdtopo VARCHAR(50),
   larg_m INT,
   nb_voies INT, 
   deb_m FLOAT(50),
   source VARCHAR(50),
   geom GEOMETRY,
   id_gest INT,
   id_zonage INT,
   PRIMARY KEY(id_vf)
);
COMMIT;

INSERT INTO "{SCHEMA_BDTOPO}".voies_ferees(id_bdtopo,larg_m,nb_voies,geom,id_gest,id_zonage)
select cleabs,larg_m,nombre_de_voies,geom,id_gest,id_zonage
from "{SCHEMA_BDTOPO}".troncon_de_voie_ferree;
COMMIT;

UPDATE "{SCHEMA_BDTOPO}".voies_ferees
SET deb_m = (larg_m*nb_voies)+7;
COMMIT;

CREATE INDEX ON "{SCHEMA_BDTOPO}".voies_ferees USING GIST (geom);
COMMIT;

DROP TABLE IF EXISTS "{schema_travail}"."{insee}_voies_ferees";
CREATE TABLE "{schema_travail}"."{insee}_voies_ferees" as 
SELECT a.*
FROM "{SCHEMA_BDTOPO}".voies_ferees  as a, "{SCHEMA_CADASTRE}".geo_commune as b
where b.idu =  '{idu}' and st_intersects(a.geom,b.geom); 
COMMIT; 

CREATE INDEX ON "{schema_travail}"."{insee}_voies_ferees" USING GIST (geom); 
COMMIT;

UPDATE "{schema_travail}".routes
SET nombre_de_voies = case when nombre_de_voies < 1 or nombre_de_voies is null then 1 else nombre_de_voies end,
largeur_de_chaussee = case when largeur_de_chaussee < 1 or largeur_de_chaussee is null then 1 else largeur_de_chaussee end; 
COMMIT; 

Drop table if exists "{schema_travail}".old_route_temp;
Create table "{schema_travail}".old_route_temp as 
select a.id_troncon as id_troncon,
st_buffer(a.geom,(a.deb_m + (a.largeur_de_chaussee *  a.nombre_de_voies ))) as geom
from "{schema_travail}".routes as a, "{SCHEMA_PUBLIC}".old200m as b
where st_intersects(a.geom,b.geom);
COMMIT;

CREATE INDEX ON "{schema_travail}".old_route_temp USING GIST (geom);
COMMIT;

UPDATE "{schema_travail}".old_route_temp as a 
set geom = st_intersection(a.geom,b.geom)
from "{SCHEMA_PUBLIC}".old200m as b
where st_intersects(a.geom,b.geom);
COMMIT;

Drop table if exists "{schema_travail}".old_route_temp2;
Create table "{schema_travail}".old_route_temp2 as 
select a.id_troncon as id_troncon, 
b.geo_parcelle, 
b.adresse as adresse_prop, 
b.comptecommunal as comptcom_prop,
b.proprietaire as nom_prop,
st_intersection(a.geom,b.geom) as geom
from "{schema_travail}".old_route_temp as a, "{SCHEMA_CADASTRE}".parcelle_info as b
where st_intersects(a.geom,b.geom);
COMMIT;

DROP TABLE IF EXISTS "{schema_travail}"."{insee}_obligations_routes";
CREATE TABLE "{schema_travail}"."{insee}_obligations_routes"(
   id_obligation SERIAL,
   geom GEOMETRY,
   comptcom_prop VARCHAR(250),
   nom_prop TEXT,
   adresse_prop TEXT,
   surface_m2 FLOAT,
   id_troncon INT,
   geo_parcelle VARCHAR(50),
   id_prop VARCHAR(50),
   PRIMARY KEY(id_obligation)
);
COMMIT;

INSERT INTO "{schema_travail}"."{insee}_obligations_routes"(geom,comptcom_prop,nom_prop,adresse_prop,id_troncon,geo_parcelle)
select geom,comptcom_prop,nom_prop,adresse_prop,id_troncon,geo_parcelle
from "{schema_travail}".old_route_temp2;
COMMIT;


DROP TABLE IF EXISTS "{schema_travail}".bd_foret;
CREATE TABLE "{schema_travail}".bd_foret as 
SELECT a.*
FROM "{SCHEMA_BDTOPO}".bd_foret as a, "{SCHEMA_CADASTRE}".geo_commune as b
where b.idu = 'XXX' and st_intersects(a.geom,b.geom); 
COMMIT;

CREATE INDEX ON "{schema_travail}".bd_foret USING GIST (geom);
COMMIT;

drop table if exists "{schema_travail}".bd_foretrgr;
create table "{schema_travail}".bd_foretrgr as 
select ST_intersection(a.geom,b.geom) as geom	
from  "{schema_travail}".bd_foret as a, "{SCHEMA_PUBLIC}".old200m as b
where st_intersects(a.geom,b.geom);
COMMIT;

CREATE INDEX ON "{schema_travail}".bd_foretrgr USING GIST (geom);
COMMIT;

drop table if exists "{schema_travail}".bd_foret20m;
create table  "{schema_travail}".bd_foret20m as 
select st_union(st_buffer(a.geom,20)) as geom
from  "{schema_travail}".bd_foretrgr as a, "{SCHEMA_PUBLIC}".old200m as b
where st_intersects(a.geom,b.geom);
COMMIT;

CREATE INDEX ON "{schema_travail}".bd_foret20m USING GIST (geom);
COMMIT;

drop table if exists "{schema_travail}".vf_gl_temp0;
create table "{schema_travail}".vf_gl_temp0 as 
select a.id_vf as id_vf,
a.deb_m,
ST_Intersection(a.geom,b.geom) as geom
from  "{schema_travail}"."{insee}_voies_ferees" as a, "{schema_travail}".bd_foret20m  as b
where st_intersects(a.geom,b.geom);
COMMIT;

CREATE INDEX ON "{schema_travail}".vf_gl_temp0 USING GIST (geom);
COMMIT;

drop table if exists "{schema_travail}".vf_gl_temp1;
create table "{schema_travail}".vf_gl_temp1 as 
select a.id_vf as id_vf,
st_buffer(a.geom,(deb_m)) as geom
from  "{schema_travail}".vf_gl_temp0 as a, "{schema_travail}".bd_foret20m  as b
where st_intersects(a.geom,b.geom);
COMMIT;

CREATE INDEX ON "{schema_travail}".vf_gl_temp1 USING GIST (geom);
COMMIT;

drop table if exists "{schema_travail}".vf_gl_old_temp;
create table "{schema_travail}".vf_gl_old_temp as 
select a.id_vf as id_vf,
b.proprietaire as nom_prop, 
b.geo_parcelle,
b.comptecommunal as comptcom_prop,
b.adresse as adresse_prop, 
st_intersection(a.geom,b.geom) as geom
from "{schema_travail}".vf_gl_temp1 as a, "{SCHEMA_CADASTRE}".parcelle_info as b
where st_intersects(a.geom,b.geom);
COMMIT;


INSERT INTO "{SCHEMA_RESULTAT}"."{insee}_result_final_mcd"(nom_prop,comptcom_prop,geom_obligations_lineaires,id_troncon,geo_parcel)
SELECT nom_prop,comptcom_prop,geom,id_troncon,geo_parcelle
FROM "{schema_travail}"."{insee}_obligations_routes";
COMMIT;

UPDATE "{SCHEMA_RESULTAT}"."{insee}_result_final_mcd" as a 
SET id_gest = b.id_gest
FROM "{schema_travail}".routes as b
WHERE a.id_troncon = b.id_troncon AND a.id_troncon IS NOT NULL;
COMMIT;

UPDATE "{SCHEMA_RESULTAT}"."{insee}_result_final_mcd" as a 
SET obl_nom = b.nom_gest,
obl_statut = b.statut,
obl_adresse = b.adresse
FROM "{SCHEMA_PUBLIC}".gestionnaires as b
WHERE a.id_gest = b.id_gest AND a.id_troncon IS NOT NULL;
COMMIT;

UPDATE "{SCHEMA_RESULTAT}"."{insee}_result_final_mcd"
SET id_old = concat(id_gest,'lineaires',fid_old),
surface_m2 = st_area(geom_obligations_lineaires)
WHERE id_troncon IS NOT NULL;
COMMIT;


INSERT INTO "{SCHEMA_RESULTAT}"."{insee}_result_final_mcd"(nom_prop,comptcom_prop,geom_obligations_lineaires,id_vf,geo_parcel)
SELECT nom_prop,comptcom_prop,geom,id_vf,geo_parcelle
FROM "{schema_travail}".vf_gl_old_temp;
COMMIT;

UPDATE "{SCHEMA_RESULTAT}"."{insee}_result_final_mcd" as a 
SET id_gest = b.id_gest
FROM "{schema_travail}"."{insee}_voies_ferees" as b
WHERE a.id_vf = b.id_vf AND a.id_vf IS NOT NULL;
COMMIT;

UPDATE "{SCHEMA_RESULTAT}"."{insee}_result_final_mcd" as a 
SET obl_nom = b.nom_gest,
obl_statut = b.statut,
obl_adresse = b.adresse
FROM "{SCHEMA_PUBLIC}".gestionnaires as b
WHERE a.id_gest = b.id_gest AND a.id_vf IS NOT NULL;
COMMIT;

UPDATE "{SCHEMA_RESULTAT}"."{insee}_result_final_mcd"
SET id_old = concat(id_gest,'lineaires',fid_old),
surface_m2 = st_area(geom_obligations_lineaires)
WHERE id_vf IS NOT NULL;
COMMIT;


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

