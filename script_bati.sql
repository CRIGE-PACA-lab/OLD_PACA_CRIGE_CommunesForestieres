----------------------------------------------------------------------------------------------
------------------------------------- 🏢 BATI 🏢 ---------------------------------------------
----------------------------------------------------------------------------------------------
---  Déterminer les obligations légales de débroussaillement (OLD) générées par les bâtiments                
---  et les propriétaires responsables de leur exécution                                      
----------------------------------------------------------------------------------------------                                               

-----------------------------------------------------
--- Création du schéma ---
-----------------------------------------------------

DROP SCHEMA IF EXISTS old_dep;
CREATE SCHEMA old_dep;

------------------------------------------------------------------------------
--- I. Identification de la parcelle et de l'adresse des bâtiments         ---
------------------------------------------------------------------------------
--- Résumé : L'adresse et/ou la parcelle de situation peut être connue -------
--- pour la majorité des bâtiments référencés dans la BD_TOPO (80% sur -------
--- le département des Alpes de Haute-Provence).					   -------
------------------------------------------------------------------------------
-------------------------------------------------------------------------
--- I-a. Jointure BDNB (adresse et parcelle) --> BD TOPO (bâtiments) ---
-------------------------------------------------------------------------

Alter table old_dep.batiments
add column bdnd_batiment_groupe_id VARCHAR(50); 

Update old_dep.batiments as a 
set bdnd_batiment_groupe_id = b.batiment_groupe_id
from old_dep."bdnb — rel_batiment_groupe_bdtopo_bat" as b 
where a.cleabs = b.bdtopo_bat_cleabs;

ALTER TABLE old_dep.batiments
ADD COLUMN bdnb_parcelle VARCHAR(50); 

Update old_dep.batiments as a 
set bdnb_parcelle = b.parcelle_id
from old_dep."bdnb — rel_batiment_groupe_parcelle" as b
where a.bdnd_batiment_groupe_id = b.batiment_groupe_id;

ALTER TABLE old_dep.batiments
ADD COLUMN bdnb_cle_interop_adr VARCHAR(255); 

Update old_dep.batiments as a 
set bdnb_cle_interop_adr = b.cle_interop_adr
from old_dep."bdnb — rel_batiment_groupe_adresse" as b
where a.bdnd_batiment_groupe_id = b.batiment_groupe_id;

ALTER TABLE old_dep.batiments
add column bdnb_numero INTEGER,
add column bdnb_rep VARCHAR,
add column bdnb_type_voie VARCHAR,
add column bdnb_nom_voie VARCHAR,
add column bdnb_libelle_adresse TEXT,
add column bdnb_code_postal VARCHAR,
add column bdnb_libelle_commune VARCHAR;

UPDATE old_dep.batiments as a
SET 
bdnb_numero = b.numero,
bdnb_rep = b.rep,
bdnb_type_voie = b.type_voie,
bdnb_libelle_adresse = b.libelle_adresse,
bdnb_nom_voie = b.nom_voie,
bdnb_code_postal =  b.code_postal,
bdnb_libelle_commune = b.libelle_commune
FROM old_dep."bdnb — adresse_compile" AS b 
where a.bdnb_cle_interop_adr = b.cle_interop_adr;

-----------------------------------------------------------
--- I-b. Jointure RNB (adresse) --> BD TOPO (bâtiments) ---
-----------------------------------------------------------

ALTER TABLE old_dep.batiments
ADD COLUMN rnb_adresses TEXT; 

Update old_dep.batiments as a 
set rnb_adresses = b.addresses
from old_dep."RNB" as b
where a.identifiants_rnb = rnb_id;

---------------------------------------------------------------------------
--- I-c. Jointure BANPLUS (adresse et parcelle) --> BD TOPO (bâtiments) ---
---------------------------------------------------------------------------

ALTER TABLE old_dep.batiments
ADD COLUMN ban_parcelle VARCHAR; 

Update old_dep.batiments as a 
set ban_parcelle = b.idu
from old_dep."lien_bati-parcelle" as b
where a.cleabs = b.id_bat;

ALTER TABLE old_dep.batiments
ADD COLUMN ban_id_adr VARCHAR; 

Update old_dep.batiments as a 
set ban_id_adr = b.id_adr
from old_dep."lien_adresse-bati" as b
where a.cleabs = b.id_bat;

ALTER TABLE old_dep.batiments
ADD COLUMN ban_numero_rue INTEGER,
ADD COLUMN ban_rep VARCHAR,
ADD COLUMN ban_nom_voie VARCHAR,
ADD COLUMN ban_insee_com VARCHAR,
ADD COLUMN ban_nom_com VARCHAR;

Update old_dep.batiments as a 
set 
ban_numero_rue = b.numero,
ban_rep = b.rep,
ban_nom_voie = b.nom_voie,
ban_insee_com = b.insee_com,
ban_nom_com = b.nom_com
from old_dep.adresse_ban as b
where a.ban_id_adr = b.id_adr;

-------------------------------------------------------------------------------
--- I-d. Jointure cadastre (adresse et parcelle) vers BD TOPO (bâtiments) ---
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--- NB : Les champs parcelles et adresse générés par cette opération seront ---
--- utilisés par défaut lorsqu'aucune information n'a été remonté par les   --- 
--- bases de données mobilisées ci-dessus. A utiliser avec précautions      ---
-------------------------------------------------------------------------------


CREATE INDEX ON old_dep.cadastre USING GIST (geom);
CREATE INDEX ON old_dep.batiments USING GIST (geom);

ALTER TABLE old_dep.batiments
ADD COLUMN cadastre_parcelle VARCHAR,
ADD COLUMN cadastre_adresse TEXT; 

UPDATE old_dep.batiments as a
set 
cadastre_parcelle = b.geo_parcel,
cadastre_adresse = b.adresse
from old_dep.cadastre as b 
where st_intersects(a.geom,b.geom);

-------------------------------------------------
--- I-e. Création d'un champs adresse unique ---
-------------------------------------------------
-----------------------------------------------------------------------------------
--- NB : Les informations adresses et les numérosd de parcelles collectées sont ---
--- agrégées dans les même champs selon l'ordre de priorité suivant : 		    ---
---		1. BDNB  															    ---
---		2. RNB  																---
---		3. BANPLUS  															---
---		4. Cadastre																---
-----------------------------------------------------------------------------------

ALTER TABLE old_dep.batiments
ADD COLUMN numero_rue VARCHAR,
ADD COLUMN rep VARCHAR,
ADD COLUMN nom_voie VARCHAR,
ADD COLUMN cp VARCHAR,
ADD COLUMN ville VARCHAR,
ADD COLUMN lieu_dit TEXT,
ADD COLUMN source_adr VARCHAR,
ADD COLUMN parcelle VARCHAR,
ADD COLUMN source_parcelle VARCHAR;

ALTER TABLE old_dep.batiments
ALTER COLUMN bdnb_numero TYPE VARCHAR USING bdnb_numero::VARCHAR,
ALTER COLUMN ban_numero_rue TYPE VARCHAR USING ban_numero_rue::VARCHAR;

UPDATE old_dep.batiments
SET rnb_adresses = replace(rnb_adresses,'[]',null) 
where rnb_adresses = '[]'; 

UPDATE old_dep.batiments
SET rnb_adresses = replace(rnb_adresses,'[','') 
where rnb_adresses is not null; 

UPDATE old_dep.batiments
SET rnb_adresses = replace(rnb_adresses,']','') 
where rnb_adresses is not null; 

UPDATE old_dep.batiments
SET 
numero_rue = case when bdnb_numero is not null then bdnb_numero
             when bdnb_numero is null and rnb_adresses is not null then replace(regexp_replace(
                       regexp_replace(rnb_adresses, '.* "street_number" : ', ''),', "street_rep" :.*',''),'"','') 
             when bdnb_numero is null and rnb_adresses is null then ban_numero_rue
		     when bdnb_numero is null and rnb_adresses is null and ban_numero_rue is null then substring(cadastre_adresse, '^[0-9]+')
             else null end,
rep = case when bdnb_rep is not null then bdnb_rep
           when bdnb_rep is null and rnb_adresses is not null  then replace(regexp_replace(regexp_replace(rnb_adresses, '.* "street_rep" : ', ''),', "street" :.*',''),'"','')
           when bdnb_rep is null and rnb_adresses is null then ban_rep
		   else null end, 
nom_voie = case when bdnb_nom_voie is not null or bdnb_type_voie is not null then concat(bdnb_type_voie,' ',bdnb_nom_voie)
                when bdnb_type_voie is null and bdnb_nom_voie is null and rnb_adresses is not null then replace(regexp_replace(regexp_replace(rnb_adresses, '.* "street" : ', ''),', "city_zipcode" :.*',''),'"','')
                when bdnb_type_voie is null and bdnb_nom_voie is null and rnb_adresses is null then ban_nom_voie
		        else null
		        end,
cp = case when bdnb_code_postal is not null then bdnb_code_postal
          when bdnb_code_postal is null and rnb_adresses is not null then replace(regexp_replace(regexp_replace(rnb_adresses, '.* "city_zipcode" : ', ''),', "city_name" :.*',''),'"','')
          else null end, 
ville = case when bdnb_libelle_commune is not null then bdnb_libelle_commune
             when bdnb_libelle_commune is null and rnb_adresses is not null then replace(regexp_replace(regexp_replace(rnb_adresses, '.* "city_name" : ', ''),', "cle_interrop_ban" :.*',''),'"','')
             when bdnb_libelle_commune is null and rnb_adresses is null then ban_nom_com
			 else null end, 
lieu_dit = case when bdnb_libelle_adresse is null and rnb_adresses is null and ban_id_adr is null then cadastre_adresse else null end,
source_adr = case when bdnb_libelle_adresse is not null then 'bdnb'
                  when bdnb_libelle_adresse is null and rnb_adresses is not null then 'rnb'
				  when bdnb_libelle_adresse is null and rnb_adresses is null and ban_id_adr is not null then 'banplus'
				  when bdnb_libelle_adresse is null and rnb_adresses is null and ban_id_adr is null and cadastre_adresse is not null then 'cadastre'
				  else null end,
parcelle = case when  ban_parcelle is not null then ban_parcelle
				when ban_parcelle is null and bdnb_parcelle is not null then bdnb_parcelle 
				else cadastre_parcelle end ,
source_parcelle = case when ban_parcelle is not null then 'banplus'
                       when ban_parcelle is null and bdnb_parcelle is not null then 'bdnb'
					   else 'cadastre' end;

CREATE INDEX ON old_dep.commune USING GIST (geom);

Update old_dep.batiments
set ville = replace(ville,'}','');

Update old_dep.batiments as a 
set ville = b.nom_officiel
from old_dep.commune as b
where a.ville is null or a.ville = '' and st_within(a.geom,b.geom);

Update old_dep.batiments as a 
set cp = b.code_postal
from old_dep.commune as b
where a.cp is null or a.cp = '' and st_within(a.geom,b.geom);

UPDATE old_dep.batiments
SET parcelle = case when source_parcelle = 'banplus' or source_parcelle = 'bdnb' then concat(left(parcelle,2),'0',right(parcelle,12)) else  parcelle end;

ALTER TABLE old_dep.batiments
ADD COLUMN cadastre_geo_parcel VARCHAR;

UPDATE old_dep.batiments as a 
set cadastre_geo_parcel = b.geo_parcel
from old_dep.cadastre as b
where a.parcelle = b.geo_parcel;

UPDATE old_dep.batiments 
set parcelle = case when cadastre_geo_parcel is null then null else parcelle end; 

drop table if exists old_dep."RNB";
drop table if exists old_dep.adresse_ban;
drop table if exists old_dep.batiment_rnb_lien_bdt;
drop table if exists old_dep."bdnb — adresse_compile";
drop table if exists old_dep."bdnb — rel_batiment_groupe_adresse";
drop table if exists old_dep."bdnb — rel_batiment_groupe_bdtopo_bat";
drop table if exists old_dep."bdnb — rel_batiment_groupe_parcelle";
drop table if exists old_dep.commune;
drop table if exists old_dep."lien_adresse-bati";
drop table if exists old_dep."lien_bati-parcelle";

------------------------------------------------------------------------------
---II. Montage de la base de données -----------------------------------------
------------------------------------------------------------------------------
--- Résumé : Création des tables de la base de données (voir MCD)          ---
------------------------------------------------------------------------------

--- II-a. Table adresse ---

Drop table if exists old.old_dep.adresse;
CREATE TABLE old.old_dep.adresse(
   ID_adresse SERIAL,
   ID_bd_topo VARCHAR,
   num_rue VARCHAR(50),
   rep VARCHAR(50),
   nom_rue VARCHAR(200),
   cp VARCHAR(50),
   ville VARCHAR(200),
   lieu_dit TEXT,
   source_adr VARCHAR(50),
   PRIMARY KEY(ID_adresse)
);

drop table if exists old_dep.adr_intermediaire; 
create table old_dep.adr_intermediaire  as 
	select * from old_dep.batiments
	where source_adr is not null ;

insert into old.old_dep.adresse(id_bd_topo,num_rue, rep, nom_rue, cp, ville, lieu_dit, source_adr)
select  cleabs,numero_rue,rep,nom_voie,cp,ville,lieu_dit,source_adr
from old_dep.adr_intermediaire;

drop table if exists old_dep.adr_intermediaire; 

----------------------------
--- II-b. Table cadastre ---
----------------------------

Drop table if exists old.old_dep.cadastre;

CREATE TABLE old.old_dep.cadastre(
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
   surf_m2 int,
   geom geometry,
   PRIMARY KEY(geo_parcel,id_prop));

insert into old_dep.cadastre(geo_parcel,code_insee,nom_commune,geo_section,code_parcelle,adresse,compt_com,proprietaire,proprietaire_info,surf_m2,geom)
select geo_parcel,code_insee,nomcommune,geo_sectio,code,adresse,comptecomm,proprietai,propriet_1,surface_ge,geom
from old_dep.parcelles_vf;

ALTER TABLE old_dep.cadastre
ADD COLUMN id_prop VARCHAR; 

UPDATE old_dep.cadastre
SET id_prop = left(proprietaire,6);

CREATE INDEX ON old_dep.cadastre USING gist (geom); 

-------------------------------
--- II-c. Table zonage_old ---
-------------------------------

DROP TABLE IF EXISTS old_dep.zonage_old;
CREATE TABLE old_dep.zonage_old(
   id_zonage SERIAL,
   geom GEOMETRY,
   PRIMARY KEY(id_zonage)
);


insert into old_dep.zonage_old(geom)
select geom
from old_dep.deb_ign;

drop table if exists old_dep.deb_ign;


CREATE INDEX ON old_dep.zonage_old USING gist (geom); 

------------------------
--- II-d. Table PLU ---
------------------------
------------------------------------------------------------------------------------------
--- Sur Qgis selectionner les zone U uniquement -----------------------------------
--- Importer la couche "zoneu" dans PostgreSQL avec transformation en EPSG:2154 ---
------------------------------------------------------------------------------------------

drop table if exists old_dep.plu;
CREATE TABLE old_dep.plu AS
WITH union_zu AS (
SELECT ST_Multi(						  --  Converties en MultiPolygon
          ST_MakeValid(					  --  Valide les géométries
             ST_Union(z.geom))) AS geom,  -- Fusionne les géométries
             z.typezone					  -- Type de zone (par exemple "U" pour urbain)
FROM old_dep.zoneu  z			          -- Source : données de zonage
WHERE z.typezone = 'U'					  -- Filtre : inclut uniquement les zones de type "U" (urbaines)
GROUP BY z.typezone						  -- Regroupement des géométries par type de zone
),

-- 1) Épuration des épines externes 
epine_externe AS (
	SELECT uzu.typezone,                         -- 
        ST_SetSRID(                                   -- Définit le système de coordonnées EPSG:2154
		  ST_Multi(                                   -- Convertit en MultiPolygon
			ST_CollectionExtract(                     -- Extrait uniquement les géométries de type 3
  			  ST_MakeValid(
   				ST_Snap(                              -- Aligne le tampon de la géométrie sur la géométrie d'origine
     			  ST_RemoveRepeatedPoints(
					ST_Buffer(
					  uzu.geom, 
					  -0.0001,                        -- Ajout d'un tampon négatif de l'ordre de 10 nm
					  'join=mitre mitre_limit=5.0'),  -- 
					  0.0003),			              -- Suppression des noeuds consécutifs proches de plus de 30 nm
				  uzu.geom,
                  0.0006)),3)),                       -- Avec une distance d'accrochage de l'ordre de 60 nm
		  2154) AS geom                               -- Géométries résultantes
    FROM union_zu uzu           -- Source : 
	),
-- 2) Épuration des épines internes
epine_interne AS (
	SELECT epext.typezone,                      -- 
        ST_SetSRID(                                   -- Définit le système de coordonnées EPSG:2154
		  ST_Multi(                                   -- Convertit en MultiPolygon
			ST_CollectionExtract(                     -- Extrait uniquement les géométries de type 3
   			  ST_MakeValid(
   				ST_Snap(                              -- Aligne le tampon de la géométrie sur la géométrie d'origine
     			  ST_RemoveRepeatedPoints(
					ST_Buffer(
					  epext.geom, 
					  0.0001,                         -- Ajout d'un tampon positif de l'ordre de 10 nm [**param**]
					  'join=mitre mitre_limit=5.0'),  -- 
					  0.0003),			              -- Suppression des noeuds consécutifs proches de plus de 30 nm
				  uzu.geom,
                  0.0006)),3)),                       -- Avec une distance d'accrochage de l'ordre de 60 nm
		  2154) AS geom                               -- Géométries résultantes
    FROM epine_externe epext                          -- Source : Zones corrigées sans épines extérieures
	JOIN union_zu uzu
	ON epext.typezone = uzu.typezone
	)
-- 3) Résultat final : on convertit la géométrie en MultiPolygon valide
SELECT epint.typezone,                          -- 
       ST_SetSRID(                                    -- Définit le système de coordonnées EPSG:2154
          ST_Multi(                                   -- Convertit en MultiPolygon
			 ST_CollectionExtract(                    -- Extrait uniquement les géométries de type 3
   				ST_MakeValid(epint.geom),             -- Corrige les géométries invalides                                    
			 3)),
	    2154) AS geom                                 -- Géométries résultantes
FROM epine_interne epint;                             -
--WHERE (ST_MakeValid(epint.geom) IS NOT NULL  
--	AND ST_IsEmpty(ST_MakeValid(epint.geom)) = false
--	AND ST_IsValid(ST_MakeValid(epint.geom)) = true);

-- Créer un index spatial sur la colonne "geom" pour optimiser les requêtes spatiales 
CREATE INDEX  
ON old_dep.plu
USING gist (geom); 

---- Création de la table "plu_corr"  : Géométries corrigées pour le zonage urbain
-- Description : Cette table contient les géométries corrigées et alignées des zones urbaines (type "U").
-- 				 Les géométries des zones de zonage urbain sont corrigées avec un alignement précis sur celles 
--				 des parcelles cadastrales.
-- Objectif : Assurer une compatibilité géométrique pour des analyses géospatiales précises et fiables.

-- Créer la table "plu_corr_fin"  avec les géométries corrigées
-- Les géométries des zones urbaines sont alignées sur les géométries des parcelles, corrigées et fusionnées.
DROP TABLE IF EXISTS old_dep.plu_corr_fin ;
CREATE TABLE old_dep.plu_corr_fin  AS
SELECT DISTINCT ST_Multi(  -- Convertit les résultats en MultiPolygon pour garantir la cohérence géométrique
					ST_Snap(  -- Aligne les points des géométries des zones urbaines sur celles des parcelles
						z.geom, ST_Collect(ST_MakeValid(p.geom)),  -- Corrige les géométries des parcelles
						0.05  -- Tolérance d'alignement : 50 centimètres
					)
				) AS geom  -- Géométrie finale corrigée
FROM old_dep.cadastre AS p  -- Table des parcelles cadastrales
INNER JOIN old_dep.plu AS z  -- Table des zones urbaines corrigées
ON ST_DWithin(z.geom, p.geom, 1)  -- Condition : les zones urbaines doivent être à 1 mètre des parcelles
GROUP BY z.geom;  -- Groupement par géométrie de zone pour garantir des résultats distincts

-- Définir le système de coordonnées Lambert93 (EPSG:2154)
-- Cette étape garantit que toutes les géométries utilisent le même système de coordonnées.
ALTER TABLE old_dep.plu_corr_fin
ALTER COLUMN geom TYPE geometry(MultiPolygon, 2154) 
USING ST_SetSRID(geom, 2154);  -- Applique EPSG:2154 comme système de coordonnées

CREATE INDEX 
ON old_dep.plu_corr_fin
USING gist (geom);  


--- II-e. Table batiments ---

ALTER TABLE old_dep.batiments
ADD COLUMN id_zonage INT,
ADD COLUMN id_adresse INT;

UPDATE old_dep.batiments as a 
SET id_zonage = b.id_zonage
from old_dep.zonage_old as b
where st_intersects(a.geom,b.geom);

UPDATE old_dep.batiments AS a
set id_adresse = b.id_adresse 
from old_dep.adresse as b
where a.cleabs = b.id_bd_topo; 

CREATE TABLE old_dep.bati(
   ID_bati SERIAL,
   id_bdtopo VARCHAR(50),
   nature VARCHAR(50),
   geom GEOMETRY,
   id_zonage INT,
   geo_parcel VARCHAR(50),
   ID_adresse INT,
   PRIMARY KEY(ID_bati),
   FOREIGN KEY(id_zonage) REFERENCES old_dep.zonage_old(id_zonage),
   FOREIGN KEY(geo_parcel) REFERENCES old_dep.cadastre(geo_parcel),
   FOREIGN KEY(ID_adresse) REFERENCES old_dep.adresse(ID_adresse)
);


insert into  old_dep.bati(id_bdtopo,nature,geom,id_zonage,geo_parcel,id_adresse)
select cleabs,nature,geom,id_zonage,parcelle,id_adresse
from old_dep.batiments;

CREATE INDEX ON old_dep.bati USING gist (geom); 


--------------------------------------------------------------------------------------------------------------------------------------------
--- III. Modélisation des Obligations 									   																 --- 
--------------------------------------------------------------------------------------------------------------------------------------------
--- Résumé : la modélisation des OLD se déroule en 3 étapes : 																			 ---
--- 1. Zone tampon de 50 m autour des bâtiments et intersection du cadastre (III-a)													 ---
--- 2. Identification des obligations sans superpositions (III-b , III-c, III-e)														 ---
--- 3. Identification des obligations avec superpositions, soit le restant des oblifgations modélisées en 1 et non relevées en 2 (III-f) ---
--------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------
--- III-a. Ensemble des OLD ---
---------------------------------
-------------------------------------------------------------------------------------------------------------------
--- NB : Cette première étape consiste à créer une zone tampon de 50 m autour de tout les bâtiments.           ---
--- La remontée des n° de parcelles à débroussailler se fait par intersection du cadastre. 					   ---
--- La différenciation (superposition d'obligation ou non) est réalisée par les étapes III-b , III-c et III-d. ---
--- Ces trois étapes viennent successivement extraire les entités dans la table 'bati_soumis_temp2' .          ---
--- Importer la couche commune de la BD TOPO																   ---
------------------------------------------------------------------------------------------------------------------

alter table old_dep.bati
add column obl_comptcom VARCHAR(50),
add column obl_nom TEXT,
add column obl_adresse INT;

Update old_dep.bati as a 
set obl_comptcom = b.compt_com,
    obl_nom = b.proprietaire
from old_dep.cadastre as b 
where a.geo_parcel = b.geo_parcel;

Update old_dep.bati as a 
set obl_adresse = id_adresse;

--- Zones tampon de 50 m ---

drop table if exists old_dep.bati_soumis_temp; 
create table old_dep.bati_soumis_temp as 
select 
a.obl_comptcom as obl_comptcom,
a.obl_nom as obl_nom,
  ST_CollectionExtract(  st_union(st_buffer(a.geom,50)),3) as geom
from old_dep.bati  as a, old_dep.com as b  
where id_zonage IS NOT NULL and st_intersects(a.geom,b.geom) and b.code_insee = '04112'
group by obl_comptcom, obl_nom;

CREATE INDEX ON old_dep.bati_soumis_temp USING GIST (geom);

--- Difference avec les zone U ---

Drop table if exists old_dep.plu_com; 
Create table old_dep.plu_com as 
select a.type_zone,
st_Union(a.geom) as geom
from old_dep.plu_corr_fin as a, old_dep.com as b 
where st_intersects(a.geom,b.geom) and b.code_insee = '04112'
group by a.type_zone;

Drop table if exists old_dep.bati_soumis_temp1 ;
Create table old_dep.bati_soumis_temp1 as 
select 
a.obl_comptcom as obl_comptcom,
a.obl_nom as obl_nom,                    		      
	       ST_CollectionExtract(      		      
             ST_MakeValid(st_difference(a.geom, b.geom))3) as geom 
from old_dep.bati_soumis_temp as a, old_dep.plu_com as b;

CREATE INDEX ON old_dep.bati_soumis_temp1 USING GIST (geom);

--- Intersection entre les zones tampon de 50 m hors zone U et le cadastre ---

drop table if exists old_dep.bati_soumis_temp2 ; 
create table old_dep.bati_soumis_temp2 as
select
a.obl_comptcom as obl_comptcom,
a.obl_nom as obl_nom,
b.geo_parcel as geo_parcel,
b.compt_com as prop_comptcom,
st_intersection(a.geom,b.geom) as geom 
from old_dep.bati_soumis_temp1 as a, old_dep.cadastre as b 
where st_intersects(a.geom,b.geom); 

CREATE INDEX ON old_dep.bati_soumis_temp2 USING GIST (geom);

---------------------------------------------------------------------------
--- III-b. Les propriétaires qui doivent débroussailler leur propriété  ---
---------------------------------------------------------------------------

drop table if exists old_dep.bati_old_is_prop;
create table old_dep.bati_old_is_prop as
select * from old_dep.bati_soumis_temp2
where obl_comptcom = prop_comptcom;

--- Suppression des entités identifiées dans la table "old_is_prop" (environ 8 minutes) ---

delete from old_dep.bati_soumis_temp2
where obl_comptcom = prop_comptcom;

drop table if exists old_dep.old_seultemp1;
create table old_dep.old_seultemp1 as 
select
st_memunion(geom) as geom 
from old_dep.bati_old_is_prop;

CREATE INDEX ON old_dep.old_seultemp1 USING GIST (geom);

drop table if exists old_dep.bati_soumis_temp3;
create table old_dep.bati_soumis_temp3 as 
select a.obl_comptcom, 
a.obl_nom, 
a.geo_parcel, 
a.prop_comptcom,                     		      
	       ST_CollectionExtract(      		      
             ST_MakeValid(
			   ST_Difference(a.geom,b.geom)),3) as geom 
from old_dep.bati_soumis_temp2 as a, old_dep.old_seultemp1 as b; 

CREATE INDEX ON old_dep.bati_soumis_temp3 USING GIST (geom);

DELETE FROM  old_dep.bati_soumis_temp3
WHERE ST_IsEmpty(geom);

--------------------------------------------------------------------------------------------------------------------------------------------
--- III-c. Les propriétaires responsables du débroussaillement d'une parcelle tierce sans qu'un autre propriétaire n'aient été identifié ---
--------------------------------------------------------------------------------------------------------------------------------------------

drop table if exists old_dep.count_obl;
create table old_dep.count_obl as
select geo_parcel as geo_parcel,
count(obl_comptcom) as nb_deb
from old_dep.bati_soumis_temp3
group by geo_parcel;

alter table old_dep.bati_soumis_temp3
add column nb_deb INT; 

update old_dep.bati_soumis_temp3 as a
set nb_deb = b.nb_deb
from old_dep.count_obl as b 
where a.geo_parcel = b.geo_parcel;

drop table if exists old_dep.bati_old_is_seul;
create table old_dep.bati_old_is_seul as 
select * from old_dep.bati_soumis_temp3
where nb_deb = 1 or nb_deb = 0; 

delete from old_dep.bati_soumis_temp3
where nb_deb = 1 or nb_deb = 0;

----------------------------------------------------------------------------------
--- III-d. Les propriétaires qui doivent débroussailler une parcelle en zone U ---
----------------------------------------------------------------------------------

drop table if exists  old_dep.bati_old_zone_u;
create table old_dep.bati_old_zone_u as 
select a.compt_com as obl_comptcom,
a.proprietaire as obl_nom,
a.geo_parcel as geo_parcel,
a.compt_com as prop_comptcom,
a.proprietaire as prop_nom,
st_intersection(a.geom,b.geom) as geom
from old_dep.cadastre as a, old_dep.plu_com as b, old_dep.zonage_old as c
where st_intersects(a.geom,c.geom) and st_intersects(a.geom,b.geom);

-----------------------------------------------------------------------------------------------------------------
--- III-e. Les OLD ne faisant pas l'objet de superposition au sens de l'article 12 de loi du 10 juillet 2023  ---
-----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------
--- NB : Cette table est une fusion des 3 table créees aux étapes III-b , III-c et III-d ---
----------------------------------------------------------------------------------------------

Drop table if exists old_dep.obligations_bati_simple cascade;
CREATE TABLE old_dep.obligations_bati_simple(
   id_obligation SERIAL,
   geom GEOMETRY,
   situation VARCHAR(250),
   comptcom_prop VARCHAR(250),
   nom_prop TEXT,
   adresse_prop TEXT,
   obl_comptcom VARCHAR(250),
   obl_nom TEXT,
   obl_adresse TEXT,
   obl_statut VARCHAR(250),
   surface_m2 FLOAT,
   id_zone INT,
   geo_parcel VARCHAR(250),
   id_prop VARCHAR(50),
   ID_bati INT,
   nb_obl INTEGER, 
   PRIMARY KEY(id_obligation),
   FOREIGN KEY(id_zone) REFERENCES  old_dep.plu_corr_fin(id_zone),
   FOREIGN KEY(geo_parcel) REFERENCES  old_dep.cadastre(geo_parcel),
   FOREIGN KEY(ID_bati) REFERENCES  old_dep.Bati(ID_bati)
);

insert into old_dep.obligations_bati_simple(geom,comptcom_prop,obl_comptcom,obl_nom,geo_parcel)
select geom,prop_comptcom,obl_comptcom,obl_nom,geo_parcel
from old_dep.bati_old_is_prop;

insert into old_dep.obligations_bati_simple(geom,comptcom_prop,obl_comptcom,obl_nom,geo_parcel)
select geom,prop_comptcom,obl_comptcom,obl_nom,geo_parcel
from old_dep.bati_old_is_seul;

insert into old_dep.obligations_bati_simple(geom,comptcom_prop,obl_comptcom,obl_nom,geo_parcel)
select geom,prop_comptcom,obl_comptcom,obl_nom,geo_parcel
from old_dep.bati_old_zone_u;

CREATE INDEX ON old_dep.obligations_bati_simple USING GIST (geom);

--- Enrichissement (facultatif) de la table ---

update old_dep.obligations_bati_simple
set nb_obl = 1,
surface_m2 = st_area(geom);

Update old_dep.obligations_bati_simple as a
set situation = case 
when st_within(a.geom,b.geom) then 'dans la zone U'
when st_disjoint(a.geom,b.geom) then 'en dehors de la zone U'
else 'chevauchant une zone U' end 
from  old_dep.plu_com as b
where st_intersects(a.geom,b.geom); 

update old_dep.obligations_bati_simple as a 
set nom_prop = b.proprietaire,
adresse_prop = b.adresse 
from old_dep.cadastre as b 
where a.comptcom_prop = b.compt_com; 

update old_dep.obligations_bati_simple as a 
set obl_adresse = b.obl_adresse,
id_bati = b.id_bati 
from old_dep.bati as b 
where a.obl_comptcom = b.obl_comptcom;


UPDATE old_dep.obligations_bati_simple
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

----------------------------------------------------------
--- III-f. Les obligations multiples (superpositions) ---
----------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------
--- NB : Version "nétoyée" de la table générée lors de l'étape III-a. Les obligations (à plusieurs) sont stockées ---
--- dans une autre table 'old_dep.obligations_bati_multi'.									      				 ---
---------------------------------------------------------------------------------------------------------------------

Drop table if exists old_dep.obligations_bati_multi cascade;
CREATE TABLE old_dep.obligations_bati_multi(
   id_obligation SERIAL,
   geom GEOMETRY,
   situation VARCHAR(250),
   comptcom_prop VARCHAR(250),
   nom_prop TEXT,
   adresse_prop TEXT,
   obl_comptcom VARCHAR(250),
   obl_nom TEXT,
   obl_adresse TEXT,
   obl_statut VARCHAR(250),
   surface_m2 FLOAT,
   id_zone INT,
   geo_parcel VARCHAR(250),
   id_prop VARCHAR(50),
   ID_bati INT,
   nb_obl INTEGER, 
   PRIMARY KEY(id_obligation),
   FOREIGN KEY(id_zone) REFERENCES  old_dep.plu_corr_fin(id_zone),
   FOREIGN KEY(geo_parcel) REFERENCES  old_dep.cadastre(geo_parcel),
   FOREIGN KEY(ID_bati) REFERENCES  old_dep.Bati(ID_bati)
);


insert into old_dep.obligations_bati_multi(comptcom_prop,obl_comptcom,obl_nom,geo_parcel,nb_obl,geom)
select prop_comptcom,obl_comptcom,obl_nom,geo_parcel,nb_deb,geom
from old_dep.bati_soumis_temp3;

--- Enrichissement (facultatif) de la table ---

update old_dep.obligations_bati_multi
set nb_obl = 1,
surface_m2 = st_area(geom);

Update old_dep.obligations_bati_multi as a
set situation = case 
when st_within(a.geom,b.geom) then 'dans la zone U'
when st_disjoint(a.geom,b.geom) then 'en dehors de la zone U'
else 'chevauchant une zone U' end 
from  old_dep.plu_com as b
where st_intersects(a.geom,b.geom); 

update old_dep.obligations_bati_multi as a 
set nom_prop = b.proprietaire,
adresse_prop = b.adresse 
from old_dep.cadastre as b 
where a.comptcom_prop = b.compt_com; 

update old_dep.obligations_bati_multi as a 
set obl_adresse = b.obl_adresse,
id_bati = b.id_bati 
from old_dep.bati as b 
where a.obl_comptcom = b.obl_comptcom;


UPDATE old_dep.obligations_bati_multi
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

--- Suppression des tables temporaires ---

Drop table if exists old_dep.bati_old_is_prop ;
Drop table if exists old_dep.bati_old_is_seul;
Drop table if exists old_dep.bati_old_zone_u;
Drop table if exists old_dep.bati_soumis_temp;
Drop table if exists old_dep.bati_soumis_temp1;
Drop table if exists old_dep.bati_soumis_temp2;
Drop table if exists old_dep.bati_soumis_temp3; 
Drop table if exists old_dep.count_obl;
Drop table if exists old_dep.plu_reg;
drop table if exists old_dep.old_seultemp1;
Drop table if exists old_dep.plu_com; 

----------------------------
--- IV-b. Table contrôle ---
----------------------------
------------------------------------------------------------------
--- NB : Table permettant la remontée d'informmations terrain. ---
------------------------------------------------------------------

CREATE TABLE old_dep.controle(
   Id_controle SERIAL,
   date_ DATE,
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
   geom geometry (point,2154),
   id_obligation integer,
   PRIMARY KEY(Id_controle),
   FOREIGN KEY(id_obligation) REFERENCES old_dep.obligations_bati(id_obligation)
);

------------------------------
--- IV-c. Table ajout-bati ---
------------------------------
---------------------------------------------------------------------------------
--- NB : Table pour ajouter des constructions non référencées à la BD_TOPO ---
--------------------------------------------------------------------------------

drop table if exists old_dep.ajout_bati;
CREATE TABLE old_dep.ajout_bati(
   id_ajout_bati SERIAL,
   nature VARCHAR(50),
   code_insee VARCHAR(5),
   code_section VARCHAR(5),
   geo_parcel VARCHAR(50),
   num_adresse VARCHAR,
   rep_adresse VARCHAR,
   nom_voie_adresse TEXT,
   lieu_dit_adresse TEXT,
   cp_adresse VARCHAR,
   ville_adresse TEXT,
   photo_1 TEXT,
   photo_2 TEXT, 
   commentaire TEXT,
   date_ajout DATE,
   nom VARCHAR(150),
   prenom VARCHAR (150),
   organisme VARCHAR (150),
   adresse_mail TEXT,
   geom GEOMETRY(polygon,2154),
   PRIMARY KEY(id_ajout_bati)
);
