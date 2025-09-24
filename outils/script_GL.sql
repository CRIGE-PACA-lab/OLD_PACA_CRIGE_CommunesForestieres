------------------------------------------------------------------------------------------------------
------------------------------------- 🚆⚡ GRANDS LINEAIRES 🚆⚡ -------------------------------------
------------------------------------------------------------------------------------------------------
--- Identifier les obligations légales de débroussaillement (OLD) générées par les infrastrutures  ---
--- de transport d'éléctricité et les infrastructures férroviaires et les gestionnaires 		   ---
--- chargés de leur exécution.     						  									       ---               
------------------------------------------------------------------------------------------------------       

-----------------------------------------------------
--- Création du schéma							  ---
-----------------------------------------------------

DROP SCHEMA IF EXISTS old_dep;
CREATE SCHEMA old_dep;

------------------------------------------------------------------------------
--- I. Montage de la base de données -----------------------------------------
------------------------------------------------------------------------------
--- Résumé : Création des tables de la base de données (voir MCD)          ---
------------------------------------------------------------------------------

--- I-a. Table gestionnaire_grand_lineaires ---

-----------------------------------------------------------------------------------------------------
--- NB : Les noms et statuts des gestionnaires peuvent être changés et adaptés aux beosins locaux ---
--- Cette table recence tout les autres gestionnaires autres que communaux et privés              ---
--- Utiliser les formulaires pour la mise à jour de cette liste 								  ---
-----------------------------------------------------------------------------------------------------

CREATE TABLE gestionnaire_grand_lineaires(
   id_gest VARCHAR(50),
   nom_gest VARCHAR(50),
   statut VARCHAR(50),
   adresse TEXT,
   PRIMARY KEY(id_gest)
);

--- I-b. Table zonage_OLD ---

------------------------------------------------------------
--- NB : Reprendre celle des bâtiments si déjà existante ---
------------------------------------------------------------


DROP TABLE IF EXISTS "04".zonage_old;

CREATE TABLE zonage_old(
   id_zonage SERIAL,
   geom TEXT,
   source VARCHAR(50),
   PRIMARY KEY(id_zonage)
);


insert into old."04".zonage_old(geom,source)
select geom,"SOURCE"
from "04".deb_ign;

drop table if exists "04".deb_ign;
);

--- I-c. Table cadastre ---

-----------------------------------------------------------
--- NB : Reprendre celle des bâtiments si déjà existante---
-----------------------------------------------------------

Drop table if exists old."04".cadastre;

CREATE TABLE old."04".cadastre(
   geo_parcel VARCHAR(50),
   id_prop VARCHAR(50),
   code_insee VARCHAR(50),
   nom_commune VARCHAR(50),
   geo_section VARCHAR(50),
   code_parcelle VARCHAR(50),
   adresse VARCHAR(50),
   compt_com VARCHAR(50),
   proprietaire TEXT,
   proprietaire_info TEXT,
   personne_physique LOGICAL,
   surf_m2 float,
   geom geometry,
   PRIMARY KEY(geo_parcel));

insert into "04".cadastre(geo_parcel,code_insee,nom_commune,geo_section,code_parcelle,adresse,compt_com,proprietaire,proprietaire_info,surf_m2,geom)
select geo_parcel,code_insee,nomcommune,geo_sectio,code,adresse,comptecomm,proprietai,propriet_1,surface_ge,geom
from "04".parcelles_vf;

--- I-d. Table lignes electriques ---

ALTER TABLE "04"."reseau-aerien-haute-tension-ht"
ALTER COLUMN geom TYPE geometry(Geometry, 2154) USING ST_SetSRID(geom, 2154);

ALTER TABLE "04"."reseau-aerien-basse-tension-bt"
ALTER COLUMN geom TYPE geometry(Geometry, 2154) USING ST_SetSRID(geom, 2154);

ALTER TABLE "04"."reseau-aerien-moyenne-tension-hta"
ALTER COLUMN geom TYPE geometry(Geometry, 2154) USING ST_SetSRID(geom, 2154);

ALTER TABLE "04"."reseau-aerien-basse-tension-bt"
ADD COLUMN id_gest INTEGER,
ADD COLUMN id_zonage INTEGER,		
ADD COLUMN deb_m INTEGER; 

ALTER TABLE "04"."reseau-aerien-moyenne-tension-hta"
ADD COLUMN id_gest INTEGER,
ADD COLUMN id_zonage INTEGER,
ADD COLUMN deb_m INTEGER;

ALTER TABLE "04"."reseau-aerien-haute-tension-ht"
ADD COLUMN id_gest INTEGER,
ADD COLUMN id_zonage INTEGER,
ADD COLUMN deb_m INTEGER; 

UPDATE "04"."reseau-aerien-basse-tension-bt"
SET 
id_gest = 17,
deb_m = 2 ; 

UPDATE "04"."reseau-aerien-moyenne-tension-hta"
SET 
id_gest = 17,
deb_m = 2; 

UPDATE "04"."reseau-aerien-haute-tension-ht"
SET 
id_gest = 16,
deb_m = case when voltage = '400 kV' then 40 else 20 end; 

UPDATE "04"."reseau-aerien-basse-tension-bt" as a 
SET id_zonage = b.id_zonage
from "04".zonage_old as b
where st_within(a.geom,b.geom); 

UPDATE "04"."reseau-aerien-moyenne-tension-hta" as a 
SET id_zonage = b.id_zonage
from "04".zonage_old as b
where st_within(a.geom,b.geom); 

UPDATE "04"."reseau-aerien-haute-tension-ht" as a 
SET id_zonage = b.id_zonage
from "04".zonage_old as b
where st_within(a.geom,b.geom); 

DROP TABLE IF EXISTS "04".ligne_electrique;
CREATE TABLE "04".ligne_electrique(
   id_ligne_elec SERIAL,
   id_source VARCHAR(50),
   voltage_kv VARCHAR,
   fonctionnement VARCHAR,
   source VARCHAR(50),
   deb_m INTEGER,
   geom GEOMETRY,
   id_zonage INT,
   id_gest INT,
   PRIMARY KEY(id_ligne_elec),
   FOREIGN KEY(id_zonage) REFERENCES "04".zonage_old(id_zonage),
   FOREIGN KEY(id_gest) REFERENCES "04".gestionnaire_gl(id_gest)
);

INSERT INTO "04".ligne_electrique( id_source,deb_m,geom, id_zonage, id_gest)
select id, deb_m, geom, id_zonage, id_gest
from "04"."reseau-aerien-basse-tension-bt";

INSERT INTO "04".ligne_electrique( id_source,deb_m,geom, id_zonage, id_gest)
select id, deb_m, geom, id_zonage, id_gest
from "04"."reseau-aerien-moyenne-tension-hta";

INSERT INTO "04".ligne_electrique(id_source,voltage_kv,fonctionnement,deb_m,geom, id_zonage, id_gest)
select cleabs,voltage,etat_de_l_objet,deb_m,geom,id_zonage,id_gest
from "04"."reseau-aerien-haute-tension-ht";

UPDATE "04".ligne_electrique AS a
SET source = CASE WHEN voltage_kv is null then 'ore' else 'bd_topo' end;

CREATE INDEX ON "04".ligne_electrique USING GIST (geom);

DROP TABLE IF EXISTS "04"."reseau-aerien-haute-tension-ht"; 
DROP TABLE IF EXISTS "04"."reseau-aerien-basse-tension-bt";
DROP TABLE IF EXISTS "04"."reseau-aerien-moyenne-tension-hta";


--- I-e. Table voies_ferees ---


ALTER TABLE "04".vf_temp
ADD COLUMN id_gest INT,
ADD COLUMN id_zonage INT; 

UPDATE "04".vf_temp as a 
SET id_zonage = b.id_zonage
from "04".zonage_old as b
where st_intersects(a.geom,b.geom); 

UPDATE "04".vf_temp 
SET id_gest = CASE WHEN "LARGEUR" = 'Etroite' THEN 18
WHEN "LARGEUR" = 'Normale' then 15
else null end; 

DROP TABLE IF EXISTS "04".voies_ferees;
CREATE TABLE "04".voies_ferees(
   id_vf SERIAL,
   id_bdtopo VARCHAR(50),
   largeur INT,
   nb_voies INT, 
   deb_m FLOAT(50),
   source VARCHAR(50),
   geom GEOMETRY,
   id_gest INT,
   id_zonage INT,
   PRIMARY KEY(id_vf),
   FOREIGN KEY(id_gest) REFERENCES "04".gestionnaire_gl(id_gest),
   FOREIGN KEY(id_zonage) REFERENCES "04".zonage_old(id_zonage)
);

INSERT INTO "04".voies_ferees(id_bdtopo,largeur,nb_voies,deb_m,geom,id_gest,id_zonage)
select "ID",larg_m,nb_voies,"DEB",geom,id_gest,id_zonage
from "04".vf_temp;

UPDATE "04".voies_ferees
SET deb_m = (larg_m*nb_voies)+7;

CREATE INDEX ON "04".voies_ferees USING GIST (geom);

DROP TABLE IF EXISTS "04".vf_temp;

--- I-f. Table bd_foret ---

----------------------------------------------------------------------------------------------------
--- Importer dans le schéma le masque forestier de la bd forêt v3 sous l'intitulé 'masqueforet2' ---
----------------------------------------------------------------------------------------------------

Drop table if exists "04".bd_foret; 
Create table "04".bd_foret as 
select 
St_MemUnion(a.geom) as geom
from "04".masqueforet2 as a, "04".com as b 
where st_intersects(a.geom,b.geom); 

CREATE INDEX ON "04".bd_foret USING GIST (geom);

---------------------------------------------------------------------------------------
--- II. Modélisation des Obligations 									   	     	--- 
---------------------------------------------------------------------------------------
--- Résumé : la modélisation des OLD se déroule en 3 grandes étapes (II-a) : 		---														 
--- 1. Modélisation des OLD générées par les electriques : 							---
---		- Zone tampon de x m autour des lignes electriques 							---
---		- Découpage des OLD à l'intérieur du masque forestier    				 	---
---		- Intersection avec le cadastre 										 	---
--- 2. Modélisation des OLD générées par les voies férrées (II-b) : 				---
---		-Zone tampon de x m + largeur de la voie autour des lignes de chemin de fer ---
---		- Découpage des OLD à l'intérieur du masque forestier + 20 m  			    ---
---		- Intersection avec le cadastre 											---
--- 3. Aggrégation des deux couches OLD (II-c)     								    ---
---------------------------------------------------------------------------------------

--- II-a. Lignes electriques ---

drop table if exists "04".rte_ligne_temp;
create table "04".rte_ligne_temp as 
select a.id_ligne_elec as id_ligne_elec,
st_buffer(a.geom,a.deb_m) as geom
from "04".ligne_electrique  as a, "04".bd_foret as b 
where st_intersects(a.geom,b.geom);

CREATE INDEX ON "04".rte_ligne_temp USING GIST (geom);
CREATE INDEX ON "04".zonage_old USING GIST (geom);

UPDATE "04".rte_ligne_temp as a
set geom = st_intersection(a.geom,b.geom)
from "04".bd_foret as b
where st_intersects(a.geom,b.geom);

drop table if exists "04".rte_ligne2_temp;
create table "04".rte_ligne2_temp as 
select a.id_ligne_elec as id_ligne_elec,
b.proprietaire as nom_prop, 
b.geo_parcel as geo_parcel,
b.compt_com as comptcom_prop,
b.adresse as adresse_prop, 
st_intersection(a.geom,b.geom) as geom
from "04".rte_ligne_temp as a, "04".cadastre as b
where st_intersects(a.geom,b.geom);


--- II-b. Voies férrées ---

drop table if exists "04".bdforet20m;
create table "04".bdforet20m as 
select st_buffer(geom,20) as geom
from "04".bd_foret;

CREATE INDEX ON "04".bdforet20m USING GIST (geom);

drop table if exists "04".vf_gl_temp;
create table "04".vf_gl_temp as 
select a.id_vf as id_vf,
st_buffer(a.geom,(deb_m)) as geom
from  "04".voies_ferees as a, "04".bdforet20m as b 
where st_intersects(a.geom,b.geom);

CREATE INDEX ON "04".vf_gl_temp USING GIST (geom);

drop table if exists "04".vf_gl_old_temp;
create table "04".vf_gl_old_temp as 
select a.id_vf as id_vf,
b.proprietaire as nom_prop, 
b.geo_parcel as geo_parcel,
b.compt_com as comptcom_prop,
b.adresse as adresse_prop, 
st_intersection(a.geom,b.geom) as geom
from "04".vf_gl_temp as a, "04".cadastre as b
where st_intersects(a.geom,b.geom);

CREATE INDEX ON "04".vf_gl_old_temp USING GIST (geom);

UPDATE "04".vf_gl_old_temp as a 
set geom = st_intersection(a.geom,st_buffer(b.geom,20))
from "04".bd_foret as b
where st_intersects(a.geom,b.geom);

--- II-c. Aggrégation des OLD ---

CREATE TABLE "04".obligations_gl(
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
   PRIMARY KEY(id_obligation),
   FOREIGN KEY(id_vf) REFERENCES "04".voies_ferees(id_vf),
   FOREIGN KEY(geo_parcel) REFERENCES "04".cadastre(geo_parcel),
   FOREIGN KEY(id_ligne_elec) REFERENCES "04".ligne_electrique
   );

INSERT INTO "04".obligations_gl(nom_prop,adresse_prop,comptcom_prop,geom,id_vf,geo_parcel)
select nom_prop,adresse_prop,comptcom_prop,geom,id_vf,geo_parcel
from "04".vf_gl_old_temp;

insert into "04".obligations_gl(nom_prop,adresse_prop,comptcom_prop,geom,id_ligne_elec,geo_parcel)
select nom_prop,adresse_prop,comptcom_prop,geom,id_ligne_elec,geo_parcel
from "04".rte_ligne2_temp;

UPDATE "04".obligations_gl
SET surface_m2 = st_area(geom);

DROP TABLE IF EXISTS "04".old_ligne2_temp; 
DROP TABLE IF EXISTS "04".old_pylone_temp;
DROP TABLE IF EXISTS "04".rte_ligne2_temp;
DROP TABLE IF EXISTS "04".rte_ligne_temp;
DROP TABLE IF EXISTS "04".rte_pylone_temp;
DROP TABLE IF EXISTS "04".rte_temp;
DROP TABLE IF EXISTS "04".vf_gl_old_temp;
DROP TABLE IF EXISTS "04".vf_gl_old_temp2;
DROP TABLE IF EXISTS "04".vf_gl_temp;
DROP TABLE IF EXISTS "04".rte_pylone2_temp;
DROP TABLE IF EXISTS "04".bdforet20m;


------------------------------------------------
--- III. Cartographie et outils collaboratifs ---
----------------------------------------------------------------------------------------------------------
-- Résumé : 																						   ---
----------------------------------------------------------------------------------------------------------

--- III-a. Table contrôle ---

------------------------------------------------------------------
--- NB : Table permettant la remontée d'informmations terrain. ---
--- Reprendre celle des bâtiments si déjà existante            ---
------------------------------------------------------------------

CREATE TABLE controle(
   Id_controle SERIAL,
   date_dernier_controle DATE,
   description TEXT,
   doc1 VARCHAR(255),
   doc2 VARCHAR(255),
   photo1 VARCHAR(255),
   photo2 VARCHAR(255),
   photo3 VARCHAR(255),
   photo4 VARCHAR(255),
   pseudo VARCHAR(50),
   nom VARCHAR(255),
   prenom VARCHAR(255),
   organisme VARCHAR(255),
   mail VARCHAR(255),
   id_obligation SERIAL NOT NULL,
   PRIMARY KEY(Id_controle),
   UNIQUE(id_obligation),
   FOREIGN KEY(id_obligation) REFERENCES obligations_gl(id_obligation)
);


---ou---

ALTER TABLE "04".controle
add column id_obligation_gl INTEGER,
add constraint obligations_gl
foreign key(id_obligation_gl) references "04".obligations_gl(id_obligation); 




