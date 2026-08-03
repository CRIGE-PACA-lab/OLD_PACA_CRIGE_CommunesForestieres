# -*- coding: utf-8 -*-
"""
MODULE_OLD50m_2_MCD.py — Exécution automatisée du module d'adaptation des tables produites par l'outil OLD50m au format établi par le modèle de données issu du GT OLD.
Auteurs : CRIGE PACA / DDT26
Documentation de l'outil OLD50m : https://gitlab-forge.din.developpement-durable.gouv.fr/frederic.sarret/old_50m/ 												 ---	
Modèle de données OLD : https://github.com/CRIGE-PACA-lab/OLD_PACA_CRIGE_CommunesForestieres 
"""

import os, logging, pandas as pd
from sqlalchemy import create_engine, text

# =============================================================================
# CONFIGURATION DU CONTEXTE DEPARTEMENTAL 
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

LOG_FILE = r"C:\Users\NomUtilisateur\Documents\WOLD50M\log\log_outil_old50m.log"
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
            -- Filtrer pour garder seulement celles significativement impactées
            ST_Area(ST_Intersection(c.geom, o.geom)) / ST_Area(c.geom) > 0.01
            -- ou un seuil absolu en m²
            -- ST_Area(ST_Intersection(c.geom, o.geom)) > 5000
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
        'code_commune': f"{DEPT}0{idu}",
        'schema_travail': f"{insee}_wold50m",
        
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
        
# =============================================================================
# MODULE SQL EMBARQUE (a completer)
# =============================================================================

MODULE_SQL = """
--------------------------------------------------
----------------- OLD50m2MCD_PACA ----------------
-------------------------------------------------- 

------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- Ce script permet d'adapter les tables produites par l'outil OLD50m au format établi par le modèle de données issu du GT OLD animé par le CRIGE PACA et l'URCOFOR ---
--- Traitements sous PostgreSQL/PostGIS 																															 ---
--- Documentation de l'outil OLD50m : https://gitlab-forge.din.developpement-durable.gouv.fr/frederic.sarret/old_50m/ 												 ---	
--- Modèle de données OLD : https://github.com/CRIGE-PACA-lab/OLD_PACA_CRIGE_CommunesForestieres 																	 ---
----  Auteurs : Luc Mabire, 																						                                                 ---
----  Version : 1.00                                                                                 																 ---
------------------------------------------------------------------------------------------------------------------------------------------------------------------------																	

------------------------------------------------------------------------------------------------------------------
----   Remplacer "26xxx" par le code INSEE de la commune                                                      ----
----   Remplacer "XXX" par les 3 derniers chiffres de ce code INSEE         								  ----
---    Remplacer "AA" par le code INSEE du département      	              ----
------------------------------------------------------------------------------------------------------------------

----------------------------------------------
--- Création des index en amont et restart ---
-----------------------------------------------

CREATE INDEX 
ON  {SCHEMA_CADASTRE}.parcelle_info
USING gist (geom); 
COMMIT;

CREATE INDEX 
ON  {SCHEMA_CADASTRE}.geo_commune
USING gist (geom); 
COMMIT;

---------------------------------------------------------------
--- Création d'une table vide conforme au standard régional ---
---------------------------------------------------------------

Drop table if exists "{SCHEMA_RESULTAT}"."{insee}_result_final_mcd";
CREATE TABLE  "{SCHEMA_RESULTAT}"."{insee}_result_final_mcd"(
   fid_old SERIAL, --- Identifiant de l'objet, en série
   id_old VARCHAR(50), --- Concaténation du compte communal de l'obligé ou de l'identifiant de gestionnaire et du numéro de parcelle de l'OLD 
   situation VARCHAR(50), --- Situation de l'obligation au regarde de la reglementation spécifique liée aux zones U du PLU.
   obl_comptcom VARCHAR(50), --- Compte de propriété de l'obligé
   obl_nom TEXT, --- Nom de la personne (morale ou physique) responsable de l'exécution de l'obligation.
   obl_statut VARCHAR(50), --- statut de la personne (morale ou physique) responsable de l'exécution de l'obligation.
   nom_prop TEXT, --- Nom de la personne (morale ou physique) chez qui l'obligation doit être exécutée.
   comptcom_prop VARCHAR(50), --- Compte de propriété du propriétaire de la parcelle
   geom_obligations_bati GEOMETRY, --- Surfaces à débroussailler par un seul et unique obligé autour d'une construction
   geom_obligations_lineaires GEOMETRY, --- Surfaces à débroussailler par un seul et unique obligé autour d'une route ou d'une voie de chemin de fer
   geom_obligations_elec GEOMETRY, --- Surfaces à débroussailler par un seul et unique obligé autour des infrastrcutures des réseaux de transport et distribution d'éléctricité
   id_troncon INTEGER, --- Identifiant unique du tronçon de route
   id_vf INTEGER, --- Identifiant unique du tronçon de voie férrée
   id_ligne_elec INTEGER, --- Identifiant unique du tronçon de ligne electrique
   id_zone INTEGER, --- Identifiant de la zone U (facultatif)
   ID_bati INTEGER, --- Identifiant unique du batiment causant l'OLD
   geo_parcel VARCHAR(50), --- Identifiant unique de la parcelle à débroussailler
   PRIMARY KEY(fid_old)
);
COMMIT;

CREATE INDEX 
ON  "{SCHEMA_RESULTAT}"."{insee}_result_final_mcd"
USING gist (geom_obligations_bati); 
COMMIT;

CREATE INDEX 
ON  "{SCHEMA_RESULTAT}"."{insee}_result_final_mcd"
USING gist (geom_obligations_lineaires); 
COMMIT;

CREATE INDEX 
ON  "{SCHEMA_RESULTAT}"."{insee}_result_final_mcd"
USING gist (geom_obligations_elec); 
COMMIT;

-----------------------------------------------------------------------------------------------------------------------------------------------------
--- Intersection des résultats de l'outil OLD_50m avec le cadastre pour remonter les informations du propriétaire de la parcelle à débroussailler ---
--- Création d'une table temporaire 																											  ---
-----------------------------------------------------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS  "{SCHEMA_RESULTAT}"."{insee}_result_final_temp"; --- table temporaire
CREATE TABLE  "{SCHEMA_RESULTAT}"."{insee}_result_final_temp" AS
select a.comptecommunal as obl_comptcom,  --- compte communal de l'obligé
b.comptecommunal as comptcom_prop, --- compte communal du propriétaire de la parcelle à débroussailler
b.proprietaire as nom_prop, --- nom du propriétaire de la parcelle à débroussailler
b.geo_parcelle, --- parcelle à débroussailler
  ST_Multi(                             -- Convertit en MultiPolygon
           ST_CollectionExtract(             -- Extrait uniquement les polygones (type 3)
               ST_MakeValid(                 -- Corrige les géométries invalides
                   ST_intersection(a.geom,b.geom)),      -- intersecte les géométries 
       3)) AS geom                           -- Géométrie finale 
from  "{SCHEMA_RESULTAT}"."{insee}_result_final" as a join {SCHEMA_CADASTRE}.parcelle_info as b --- sources : résultats de OLD50m ; cadastre
on st_intersects(a.geom, b.geom)
where b.codecommune = right('{insee}',3);
COMMIT;

CREATE INDEX 
ON  "{SCHEMA_RESULTAT}"."{insee}_result_final_temp"
USING gist (geom); 
COMMIT;

----------------------------------------------------------------------
--- Remontée des informations cadastrales du débroussailleur       ---
--- Jointure des tables "cadastre" et "bati" à la table temporaire ---
----------------------------------------------------------------------

ALTER TABLE  "{SCHEMA_RESULTAT}"."{insee}_result_final_temp"
ADD COLUMN obl_nom TEXT, --- nom de l'obligé 
ADD COLUMN id_bati INT;  --- identifiant de la construction à l'origine du débroussaillement

UPDATE  "{SCHEMA_RESULTAT}"."{insee}_result_final_temp" as a
SET obl_nom = b.proprietaire --- nom de l'obligé 
from {SCHEMA_CADASTRE}.parcelle_info as b --- source : cadastre
where a.obl_comptcom = b.comptecommunal;  


----------------------------------------------------------------------------------------------------------
--- Insertion de la table temporaire dans la table finale conforme au format du standard régional PACA ---
----------------------------------------------------------------------------------------------------------

insert into "{SCHEMA_RESULTAT}"."{insee}_result_final_mcd"(obl_comptcom,obl_nom,nom_prop,comptcom_prop,geom_obligations_bati,geo_parcel)
select obl_comptcom,obl_nom,nom_prop,comptcom_prop,geom,geo_parcelle
from  "{SCHEMA_RESULTAT}"."{insee}_result_final_temp";
COMMIT;

-----------------------------------------------------------------------------
--- Définition de la situation de l'OLD au regard du document d'urbanisme ---
--- Facultatif si la commune n'est pas couverte par un PLU 				  ---
-----------------------------------------------------------------------------

Update "{SCHEMA_RESULTAT}"."{insee}_result_final_mcd" as a
set situation = case 
when st_within(a.geom_obligations_bati,b.geom) then 'dans la zone U'
when st_disjoint(a.geom_obligations_bati,b.geom) then 'en dehors de la zone U'
else 'chevauchant une zone U' end 
from  "{SCHEMA_RESULTAT}"."AA_zonage_global" as b; --- source : zonage du PLU
COMMIT;

--------------------------------------------------------
--- Calcul de la surface des zones à débroussailler  ---
--------------------------------------------------------

ALTER TABLE "{SCHEMA_RESULTAT}"."{insee}_result_final_mcd"
ADD COLUMN surface_m2 INT;

Update "{SCHEMA_RESULTAT}"."{insee}_result_final_mcd" as a
set surface_m2 = case when a.geom_obligations_bati is not null then st_area(a.geom_obligations_bati)
else st_area(a.geom_obligations_bati)
end ; 
COMMIT;

------------------------------------------------------------
--- Statut juridique de l'obligé 						 ---
--- Reclassification adaptables aux spécificités locales ---
------------------------------------------------------------

UPDATE "{SCHEMA_RESULTAT}"."{insee}_result_final_mcd"
SET obl_statut = (
CASE 
WHEN obl_nom like '%COMMUNE%' OR obl_nom like '%MAIRIE%'
THEN 'Communal'
WHEN obl_nom like '%COMMUNAUTE%' OR obl_nom like '%COM COM%' OR obl_nom like '%CC %' or obl_nom like '%COMMUN URBAIN%' 
or obl_nom like '%METROPOLE%' or obl_nom like '%AGGLOMERATION%' OR obl_nom like '%SAN OUEST PROVENCE%' 
THEN 'EPCI'
WHEN obl_nom like '%DEPARTEMENT%' or obl_nom like '%CONSEIL GENERAL%' 
THEN 'Departemental'
WHEN obl_nom like '%ETAT%' OR obl_nom like '%ONF OFFICE NATIONAL DES FORETS%' OR obl_nom like '%OFFICE NATIONAL DES FORETS%'
OR obl_nom like '%DOUANES%' OR obl_nom like '%DIRECTION REGIONALE DE L''ENVIRONNEMENT DE L''AMENAGEMENT%' 
OR obl_nom like '%DIRECTION REGIONALE DE L AGRICULTURE ET DE LA FORET%' OR obl_nom like '%DIRECTION REGIONALE DE L ALIMENTATION AGRICULTURE ET FORET%'
OR obl_nom like '%DREAL%' OR obl_nom like '%MINISTERE%' 
OR obl_nom like 'UNITE DE SOUTIEN D''INFRASTRUCTURE DE LA DEF%'
THEN 'Etat'		       
WHEN obl_nom like '%M%' OR obl_nom like '%MME%'
THEN 'Prive'
WHEN obl_nom like '%SCE DEPARTEMENTAL INCENDIE ET SECOURS%'
OR obl_nom like '%REGIE DEPARTEMENTALE DE TRANSPORTS%' 
OR obl_nom like '%OEUVRE GENERALE DU CANAL%' OR obl_nom like '%COMMUNAUTE HOSPITALIERE MISSIONNAIRE%'
OR obl_nom like '%EDF%' OR obl_nom like '%ASS SYNDICALE DU CANAL%' 
OR obl_nom like '%DELACOMMUNE%' OR obl_nom like '%COOP VINICOLE%' 
OR obl_nom like '%SYNDICAT DES VIDANGES%' 
OR obl_nom like '%STE EAU DE MARSEILLE%' 
OR obl_nom like '%SNCF%' 
OR obl_nom like 'SOCIETE AMENAGEMENT FONCIER%'
OR obl_nom like 'RTM'
OR obl_nom like '%REGION PROVENCE-ALPES-COTE%'
THEN 'Autre public' 
ELSE 'Prive' 
END
);
COMMIT;

------------------------------------------------------------
--- Identifiant de l'OLD						 ---
------------------------------------------------------------

UPDATE "{SCHEMA_RESULTAT}"."{insee}_result_final_mcd"
SET id_old = concat(geo_parcel,'bat',fid_old);
COMMIT; 



---------------------------------------------------------------------
--- Suppression de la table intermédiaire et des géométries vides ---
---------------------------------------------------------------------

DELETE FROM "{SCHEMA_RESULTAT}"."{insee}_result_final_mcd"
WHERE ST_IsEmpty(geom_obligations_bati) or surface_m2 = 0; 
COMMIT;

DROP TABLE IF EXISTS  "{SCHEMA_RESULTAT}"."{insee}_result_final_temp";
COMMIT;
"""

# =============================================================================
# EXECUTION PRINCIPALE
# =============================================================================

if __name__ == "__main__":
    logging.info(f"===== Lancement module OLD50m - Département {DEPT} =====")
    communes = get_communes() 
    for _, row in communes.iterrows():
        idu = str(row['idu']).zfill(3)
        insee = f"{DEPT}{idu}"
        code_commune = f"{DEPT}0{idu}"
        execute_module(insee, idu, row['tex2'], MODULE_SQL)
    logging.info("===== Fin de traitement départemental =====")

