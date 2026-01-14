--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--
------------------------------------- 🚆⚡ GRANDS LINEAIRES 🚆⚡ -------------------------------------
--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--
--- Identifier les obligations légales de débroussaillement (OLD) générées par les infrastrutures  ---
--- de transport d'éléctricité et les infrastructures férroviaires et les gestionnaires 		   ---
--- chargés de leur exécution.     						  									       --- 
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
--- Tronçons de voies ferrées de la BD TOPO renommé "r_bdtopo".vf_temp																			  ----
--- Contours forestiers de la BD Foret téléchargeable sur le site de l'IGN "r_bdtopo"."bd_foret"												  ----
--*------------------------------------------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------------------------------------------*--

--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--
----   INTEGRATION DU CODE INSEE DU DEPARTEMENT CONCERNEE                                                     ----
----                                                                                                          ----
----   Remplacer "04" avec le code INSEE du département                                                       ----                                        
----   Remplacer XX   avec le code INSEE du département                                                       ----
----                                                                                                          ----
----   Exemple pour le département du VAR dont le code INSEE est 83                                           ----
----   Rechercher - remplacer "04" par "83" (CTRL+f)                                                          ----
----   Rechercher - remplacer XX par "83" (CTRL+f)  														  ---- 
--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--

-----------------------------------------------------
--- Création du schéma							  ---
-----------------------------------------------------

DROP SCHEMA IF EXISTS "04_gl";
CREATE SCHEMA "04_gl";

CREATE INDEX ON r_bdtopo.bd_foret USING GIST (geom);
COMMIT;

CREATE INDEX ON public.old200m USING GIST (geom); 
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--
--- Montage de la base de données -----------------------------------------
------------------------------------------------------------------------------
--- Résumé : Création des tables de la base de données (voir MCD)          ---
------------------------------------------------------------------------------

--*------------------------------------------------------------------------------------------------------------*--

---- Table gestionnaire_grand_lineaires --

--- NB : Les noms et statuts des gestionnaires peuvent être changés et adaptés aux besoins locaux ---
--- Une table d'exemple est disponible sur Github ---

CREATE TABLE gestionnaire_grand_lineaires(
   id_gest VARCHAR(50),
   nom_gest VARCHAR(50),
   statut VARCHAR(50),
   adresse TEXT,
   PRIMARY KEY(id_gest)
);
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--

--- Table lignes electriques ---

ALTER TABLE r_bdtopo."reseau-aerien-haute-tension-ht"
ALTER COLUMN geom TYPE geometry(Geometry, 2154) USING ST_SetSRID(geom, 2154);
COMMIT;

ALTER TABLE r_bdtopo."reseau-aerien-basse-tension-bt"
ALTER COLUMN geom TYPE geometry(Geometry, 2154) USING ST_SetSRID(geom, 2154);
COMMIT;

ALTER TABLE r_bdtopo."reseau-aerien-moyenne-tension-hta"
ALTER COLUMN geom TYPE geometry(Geometry, 2154) USING ST_SetSRID(geom, 2154);
COMMIT;

ALTER TABLE r_bdtopo."reseau-aerien-basse-tension-bt"
ADD COLUMN IF NOT EXISTS id_gest INTEGER,
ADD COLUMN IF NOT EXISTS id_zonage INTEGER,		
ADD COLUMN IF NOT EXISTS deb_m INTEGER; 
COMMIT;

ALTER TABLE r_bdtopo."reseau-aerien-moyenne-tension-hta"
ADD COLUMN IF NOT EXISTS id_gest INTEGER,
ADD COLUMN IF NOT EXISTS id_zonage INTEGER,
ADD COLUMN IF NOT EXISTS deb_m INTEGER;
COMMIT;

ALTER TABLE r_bdtopo."reseau-aerien-haute-tension-ht"
ADD COLUMN IF NOT EXISTS id_gest INTEGER,
ADD COLUMN IF NOT EXISTS id_zonage INTEGER,
ADD COLUMN IF NOT EXISTS deb_m INTEGER; 
COMMIT;

UPDATE r_bdtopo."reseau-aerien-basse-tension-bt"
SET 
id_gest = 17,
deb_m = 2 ; 
COMMIT;

UPDATE r_bdtopo."reseau-aerien-moyenne-tension-hta"
SET 
id_gest = 17,
deb_m = 2; 
COMMIT;

UPDATE r_bdtopo."reseau-aerien-haute-tension-ht"
SET 
id_gest = 16,
deb_m = case when voltage = '400 kV' then 40 else 20 end; 
COMMIT;

UPDATE r_bdtopo."reseau-aerien-basse-tension-bt" as a 
SET id_zonage = b.fid
from  public.old200m  as b
where st_within(a.geom,b.geom); 
COMMIT;

UPDATE r_bdtopo."reseau-aerien-moyenne-tension-hta" as a 
SET id_zonage = b.fid
from public.old200m as b
where st_within(a.geom,b.geom); 
COMMIT;

UPDATE r_bdtopo."reseau-aerien-haute-tension-ht" as a 
SET id_zonage = b.fid
from public.old200m as b
where st_within(a.geom,b.geom); 
COMMIT;

DROP TABLE IF EXISTS r_bdtopo.ligne_electrique;
CREATE TABLE r_bdtopo.ligne_electrique(
   id_ligne_elec SERIAL,
   id_source VARCHAR(50),
   voltage_kv VARCHAR,
   fonctionnement VARCHAR,
   source VARCHAR(50),
   deb_m INTEGER,
   geom GEOMETRY,
   id_zonage INT,
   id_gest INT,
   PRIMARY KEY(id_ligne_elec)
);
COMMIT;

INSERT INTO r_bdtopo.ligne_electrique( id_source,deb_m,geom, id_zonage, id_gest)
select id, deb_m, geom, id_zonage, id_gest
from r_bdtopo."reseau-aerien-basse-tension-bt";
COMMIT;

INSERT INTO r_bdtopo.ligne_electrique( id_source,deb_m,geom, id_zonage, id_gest)
select id, deb_m, geom, id_zonage, id_gest
from r_bdtopo."reseau-aerien-moyenne-tension-hta";
COMMIT;

INSERT INTO r_bdtopo.ligne_electrique(id_source,voltage_kv,fonctionnement,deb_m,geom, id_zonage, id_gest)
select cleabs,voltage,etat_de_l_objet,deb_m,geom,id_zonage,id_gest
from r_bdtopo."reseau-aerien-haute-tension-ht";
COMMIT;

UPDATE r_bdtopo.ligne_electrique AS a
SET source = CASE WHEN voltage_kv is null then 'ore' else 'bd_topo' end;
COMMIT;

CREATE INDEX ON r_bdtopo.ligne_electrique USING GIST (geom);
COMMIT;

DROP TABLE IF EXISTS r_bdtopo."reseau-aerien-haute-tension-ht"; 
DROP TABLE IF EXISTS r_bdtopo."reseau-aerien-basse-tension-bt";
DROP TABLE IF EXISTS r_bdtopo."reseau-aerien-moyenne-tension-hta";

--*------------------------------------------------------------------------------------------------------------*--

--- Table voies_ferees ---

ALTER TABLE r_bdtopo.troncon_de_voie_ferree
ADD COLUMN IF NOT EXISTS id_gest INT,
ADD COLUMN IF NOT EXISTS id_zonage INT,
ADD COLUMN IF NOT EXISTS larg_m INT; 
COMMIT;

UPDATE r_bdtopo.troncon_de_voie_ferree as a 
SET id_zonage = b.fid
from public.old200m as b
where st_intersects(a.geom,b.geom); 
COMMIT;

UPDATE r_bdtopo.troncon_de_voie_ferree 
SET id_gest = CASE WHEN largeur = 'Etroite' THEN 18
WHEN largeur = 'Normale' then 15
else null end; 
COMMIT;

UPDATE r_bdtopo.troncon_de_voie_ferree  
SET larg_m = CASE WHEN largeur = 'Etroite' THEN 1
WHEN largeur = 'Normale' then 1.435
else null end; 
COMMIT;

DROP TABLE IF EXISTS r_bdtopo.voies_ferees;
CREATE TABLE r_bdtopo.voies_ferees(
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

INSERT INTO r_bdtopo.voies_ferees(id_bdtopo,larg_m,nb_voies,geom,id_gest,id_zonage)
select cleabs,larg_m,nombre_de_voies,geom,id_gest,id_zonage
from r_bdtopo.troncon_de_voie_ferree;
COMMIT;

UPDATE r_bdtopo.voies_ferees
SET deb_m = (larg_m*nb_voies)+7;
COMMIT;

CREATE INDEX ON r_bdtopo.voies_ferees USING GIST (geom);
COMMIT;

CREATE INDEX ON r_bdtopo.voies_ferees USING GIST (geom); 
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

drop table if exists "04_gl".bd_foretrgr;
create table "04_gl".bd_foretrgr as 
select a.geom as geom
from  r_bdtopo.bd_foret as a, public.old200m as b
where st_intersects(a.geom,b.geom);
COMMIT;

CREATE INDEX ON "04_gl".bd_foretrgr USING GIST (geom);
COMMIT;

drop table if exists "04_gl".rte_ligne_temp0;
create table "04_gl".rte_ligne_temp0 as 
select a.id_ligne_elec,
a.deb_m,
st_intersection(a.geom,b.geom) as geom
from r_bdtopo.ligne_electrique  as a, "04_gl".bd_foretrgr as b 
where st_intersects(a.geom,b.geom);
COMMIT;

CREATE INDEX ON "04_gl".rte_ligne_temp0 USING GIST (geom);
COMMIT;

drop table if exists "04_gl".rte_ligne_temp1;
create table "04_gl".rte_ligne_temp1 as 
select a.id_ligne_elec as id_ligne_elec,
st_buffer(a.geom,a.deb_m) as geom
from "04_gl".rte_ligne_temp0 as a, "04_gl".bd_foretrgr as b
where st_intersects(a.geom,b.geom);
COMMIT;

CREATE INDEX ON "04_gl".rte_ligne_temp1 USING GIST (geom);
COMMIT;

drop table if exists "04_gl".rte_ligne2_temp;
create table "04_gl".rte_ligne2_temp as 
select a.id_ligne_elec as id_ligne_elec,
b.proprietaire as nom_prop, 
b.geo_parcelle,
b.comptecommunal as comptcom_prop,
b.adresse as adresse_prop, 
st_intersection(a.geom,b.geom) as geom
from "04_gl".rte_ligne_temp1 as a, r_cadastre.parcelle_info as b
where st_intersects(a.geom,b.geom);
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--
--- Voies férrées ---

drop table if exists "04_gl".bd_foret20m;
create table  "04_gl".bd_foret20m as 
select st_union(st_buffer(a.geom,20)) as geom
from  r_bdtopo.bd_foret as a, public.old200m as b
where st_intersects(a.geom,b.geom);
COMMIT;

CREATE INDEX ON "04_gl".bd_foret20m USING GIST (geom);
COMMIT;

drop table if exists "04_gl".vf_gl_temp0;
create table "04_gl".vf_gl_temp0 as 
select a.id_vf as id_vf,
a.deb_m,
ST_Intersection(a.geom,b.geom) as geom
from  r_bdtopo.voies_ferees as a, "04_gl".bd_foret20m  as b
where st_intersects(a.geom,b.geom);
COMMIT;

CREATE INDEX ON "04_gl".vf_gl_temp0 USING GIST (geom);
COMMIT;

drop table if exists "04_gl".vf_gl_temp1;
create table "04_gl".vf_gl_temp1 as 
select a.id_vf as id_vf,
st_buffer(a.geom,(deb_m)) as geom
from  "04_gl".vf_gl_temp0 as a, "04_gl".bd_foret20m  as b
where st_intersects(a.geom,b.geom);
COMMIT;

CREATE INDEX ON "04_gl".vf_gl_temp1 USING GIST (geom);
COMMIT;

drop table if exists "04_gl".vf_gl_old_temp;
create table "04_gl".vf_gl_old_temp as 
select a.id_vf as id_vf,
b.proprietaire as nom_prop, 
b.geo_parcelle,
b.comptecommunal as comptcom_prop,
b.adresse as adresse_prop, 
st_intersection(a.geom,b.geom) as geom
from "04_gl".vf_gl_temp1 as a, r_cadastre.parcelle_info as b
where st_intersects(a.geom,b.geom);
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--
--- Aggrégation des OLD ---

DROP TABLE IF EXISTS "XX_old50m_resultat".obligations_gl;
CREATE TABLE "XX_old50m_resultat".obligations_gl(
   id_obligation SERIAL,
   nom_prop TEXT,
   adresse_prop TEXT,
   comptcom_prop VARCHAR(250),
   surface_m2 FLOAT,
   geom GEOMETRY,
   id_vf INT,
   geo_parcel VARCHAR(50),
   id_infra_pt INT,
   id_ligne_elec INT,
   PRIMARY KEY(id_obligation)
   );
COMMIT;

INSERT INTO "XX_old50m_resultat".obligations_gl(nom_prop,adresse_prop,comptcom_prop,geom,id_vf,geo_parcel)
select nom_prop,adresse_prop,comptcom_prop,geom,id_vf,geo_parcel
from "04_gl".vf_gl_old_temp;
COMMIT;

insert into "XX_old50m_resultat".obligations_gl(nom_prop,adresse_prop,comptcom_prop,geom,id_ligne_elec,geo_parcel)
select nom_prop,adresse_prop,comptcom_prop,geom,id_ligne_elec,geo_parcel
from "04_gl".rte_ligne2_temp;
COMMIT;

UPDATE "XX_old50m_resultat".obligations_gl
SET surface_m2 = st_area(geom);
COMMIT;

CREATE INDEX ON "XX_old50m_resultat".obligations_gl USING GIST (geom);
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

DROP SCHEMA "04_gl" CASCADE;
COMMIT;




