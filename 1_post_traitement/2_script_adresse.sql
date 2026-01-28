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
----   Remplacer "26XXX" par le code INSEE de la commune                                                      ----
----   Remplacer "AA" par le code INSEE du Département         												  ----
------------------------------------------------------------------------------------------------------------------

--*------------------------------------------------------------------------------------------------------------*--
-----------------------------------------------------
--- Création du schéma							  ---
-----------------------------------------------------

DROP SCHEMA IF EXISTS "AA_adresse";
CREATE SCHEMA "AA_adresse";
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--

--- Table adresse_parcelle : joiture des tables "parcelles_info" et "lien_bati_parcelle" ---

ALTER TABLE r_bdtopo."lien_adresse-parcelle"
ADD COLUMN IF NOT EXISTS idu_cadastre VARCHAR; 
COMMIT;

UPDATE r_bdtopo."lien_adresse-parcelle"
SET idu_cadastre = concat(left("IDU",2),'0',right("IDU",12));
COMMIT;

DROP TABLE IF EXISTS "AA_adresse".adresse_parcelle1; 
CREATE TABLE "AA_adresse".adresse_parcelle1 AS 
SELECT a.geo_parcelle, 
a.comptecommunal,
b."ID_ADR"
FROM r_cadastre.parcelle_info as a, r_bdtopo."lien_adresse-parcelle" as b 
WHERE a.geo_parcelle = b."IDU"; 
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--

--- Table adresse_parcelle2 : ajout des points d'adresses ---


DROP TABLE IF EXISTS "AA_adresse".adresse_parcelle2; 
CREATE TABLE "AA_adresse".adresse_parcelle2 AS 
SELECT a.*, 
b."NUMERO" as numero,
b."REP" as rep,
b."NOM_VOIE" as nom_voie,
b."INSEE_COM" as insee_com,
b."NOM_COM" as nom_com,
b."POSITION" as position 
FROM "AA_adresse".adresse_parcelle1 as a, r_bdtopo.adresse as b 
WHERE a."ID_ADR" = b."ID_ADR"; 
COMMIT;

ALTER TABLE "AA_adresse".adresse_parcelle2 
ADD COLUMN adresse_concat TEXT;
COMMIT;

UPDATE "AA_adresse".adresse_parcelle2
SET adresse_concat = concat(case 
when numero = '0' or numero = '99999' then null 
else numero end,' ',rep,' ',nom_voie,' ',insee_com,' ',nom_com);
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--

--- Insertion de l'adresse dans la table de résultats ---

UPDATE "AA_old50m_resultat"."26XXX_result_final_mcd" AS a 
SET obl_adresse = b.adresse_concat
FROM "AA_adresse".adresse_parcelle2 as b
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

DROP SCHEMA "AA_adresse" CASCADE;
COMMIT;






