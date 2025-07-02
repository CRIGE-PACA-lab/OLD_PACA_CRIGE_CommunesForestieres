---------------------------------------------------------------------------------------------------
------------------------------------- 🚗 ROUTES 🚗 ------------------------------------------------
---------------------------------------------------------------------------------------------------
---  Déterminer les obligations légales de débroussaillement (OLD) générées par les routes      ---               
---  et les gestionnaires chargés de leur exécution                      		                ---
---------------------------------------------------------------------------------------------------                                 

-----------------------------------------------------
--- Création du schéma ---
-----------------------------------------------------

DROP SCHEMA IF EXISTS old_dep;
CREATE SCHEMA old_dep;

------------------------------------------------------------------------------
--- I. Montage de la base de données -----------------------------------------
------------------------------------------------------------------------------
--- Résumé : Création des tables de la base de données (voir MCD)          ---
------------------------------------------------------------------------------

--- I-a. Table zonage_OLD ---

------------------------------------------------------------
--- NB : Reprendre celle des bâtiments si déjà existante ---
------------------------------------------------------------

DROP TABLE IF EXISTS old_dep.zonage_old;

CREATE TABLE zonage_old(
   id_zonage SERIAL,
   geom TEXT,
   source VARCHAR(50),
   PRIMARY KEY(id_zonage)
);


insert into old.old_dep.zonage_old(geom,source)
select geom,"SOURCE"
from old_dep.deb_ign;

drop table if exists old_dep.deb_ign;
);


--- I-b. Table cadastre ---

-----------------------------------------------------------
--- NB : Reprendre celle des bâtiments si déjà existante---
-----------------------------------------------------------

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
   surf_m2 float,
   geom geometry,
   PRIMARY KEY(geo_parcel));

insert into old_dep.cadastre(geo_parcel,code_insee,nom_commune,geo_section,code_parcelle,adresse,compt_com,proprietaire,proprietaire_info,surf_m2,geom)
select geo_parcel,code_insee,nomcommune,geo_sectio,code,adresse,comptecomm,proprietai,propriet_1,surface_ge,geom
from old_dep.parcelles_vf;


--- I-c. Table routes ---

----------------------------------------------------------
--- NB : Seulement les routes ouvertes à la circulation---
----------------------------------------------------------

ALTER TABLE old_dep.routes_vf
ADD COLUMN id_zonage INTEGER; 

UPDATE old_dep.routes_vf as a 
SET id_zonage = b.id_zonage
from old_dep.zonage_old as b 
where st_intersects(a.geom,b.geom); 

DROP TABLE IF EXISTS old_dep.routes;
CREATE TABLE old_dep.routes(
   id_troncon SERIAL,
   id_bdtopo VARCHAR(50),
   nature VARCHAR(50),
   importance VARCHAR(50),
   acces_vehicule_leger VARCHAR(50),
   nom_voie TEXT,
   cpx_numero VARCHAR(50),
   cpx_classement_administratif VARCHAR(50),
   cpx_gestionnaire VARCHAR(50),
   larg_m INT,
   deb_m INTEGER,
   source VARCHAR(50),
   geom GEOMETRY,
   id_gest VARCHAR,
   id_zonage INT,
   PRIMARY KEY(id_troncon),
   FOREIGN KEY(id_gest) REFERENCES old_dep.gestionnaire(id_gest),
   FOREIGN KEY(id_zonage) REFERENCES old_dep.zonage_old(id_zonage)
);

insert into old_dep.routes(id_bdtopo,nature,importance, nom_voie, cpx_numero, cpx_classement_administratif, cpx_gestionnaire,geom,id_zonage)
select cleabs,nature,importance, cpx_toponyme_route_nommee, cpx_numero,cpx_classement_administratif , cpx_gestionnaire,geom,id_zonage
from old_dep.routes_vf
where acces_vehicule_leger = 'Libre', acces_vehicule_leger = 'A préage' ;

CREATE INDEX ON old_dep.routes USING GIST (geom);

Alter table old_dep.routes
add column gest_desserte VARCHAR; 

UPDATE old_dep.routes as a
SET gest_desserte = b.gestionnai
from old_dep.desserte_massif_04 as b
where a.id_bdtopo = b.id and gestionnai is not null; 

UPDATE old_dep.routes as a
SET gest_desserte = b.gestionnai
from old_dep.limitation_tonnage_04 as b
where a.id_bdtopo = b.id and gestionnai is not null; 

UPDATE old_dep.routes 
SET cpx_gestionnaire = case when cpx_gestionnaire is null then gest_desserte 
					   when  cpx_gestionnaire is null and prive = true then 'prive'
					   else cpx_gestionnaire end;
					   
ALTER TABLE old_dep.routes DROP COLUMN gest_desserte;


--- I-d. Table gestionnaire-------

-----------------------------------------------------------------------------------------------------
--- NB : Les noms et statuts des gestionnaires peuvent être changés et adaptés aux beosins locaux ---
--- Utiliser les formulaires pour la mise à jour de cette liste 								  ---
-----------------------------------------------------------------------------------------------------

drop table if exists old_dep.gestionnaire;
CREATE TABLE old_dep.gestionnaire(
   id_gest SERIAL,
   nom_gest VARCHAR(250),
   statut VARCHAR(250),
   adresse TEXT,
   PRIMARY KEY(id_gest)
);

drop table if exists old_dep.gest_temp;
create table old_dep.gest_temp as 
select 
cpx_gestionnaire
FROM old_dep.routes
group by cpx_gestionnaire ;

insert into old_dep.gestionnaire(nom_gest)
select cpx_gestionnaire
from old_dep.gest_temp;

update old_dep.gestionnaire
set statut = case when nom_gest = 'Alpes-de-Haute-Provence' 
					or nom_gest = 'Alpes-de-Haute-Provence/Alpes-Maritimes' 
 					or nom_gest ='Alpes-de-Haute-Provence/Hautes-Alpes'  
  					or nom_gest ='Alpes-de-Haute-Provence/Var' 
					or nom_gest ='Alpes-Maritimes' 
    				or nom_gest ='Alpes-Maritimes/Var' 
	 				or nom_gest ='Bouches-du-Rhône' 
	  				or nom_gest ='Conseil Départemental des AHP' 
	   				or nom_gest ='Drôme'  
					or nom_gest ='Drôme/Alpes-de-Haute-Provence' 
	    			or nom_gest ='Hautes-Alpes' 
		 			or nom_gest = 'Hautes-Alpes/Alpes-de-Haute-Provence' 
		  			or nom_gest ='Var/Alpes-de-Haute-Provence' 
		   			or nom_gest ='Vaucluse' 
		    		or nom_gest ='Var' 
					then 'departement'
				when nom_gest =  'DIR Méditerranée' then  'DIR Méditerranée' 
				when nom_gest = 'Métropole Nice Côte d''Azur' then 'Intercommunal'
				when nom_gest = 'Priv' 
					or nom_gest = 'ESCOTA' 
					then 'privé'
				when nom_gest = 'NR' then null 
				else 'commune' 
				end ;

UPDATE old_dep.routes as a 
SET id_gest = b.id_gest
from old_dep.gestionnaire as b
where a.cpx_gestionnaire = b.nom_gest;

ALTER TABLE old_dep.routes 
add column risque VARCHAR;

UPDATE old_dep.routes as a
SET risque = b."communes_concernees_04 — Feuil1_Field3"
from old_dep.com as b
where st_intersects(a.geom,b.geom);

UPDATE old_dep.routes 
SET cpx_gestionnaire = case when cpx_gestionnaire is null then gest_desserte 
					   when  cpx_gestionnaire is null and prive = true then 'prive'
					   else cpx_gestionnaire end,
	deb_m = case when cpx_classement_administratif =  'Autoroute/Route nommée' and risque =  'tres fort' then 20 
				 when cpx_classement_administratif =  'Autoroute/Route nommée' and risque =  'fort' then 20 
				 when cpx_classement_administratif =  'Autoroute/Route nommée' and risque =  'moyen' then 15 
 				 when cpx_classement_administratif = 'Départementale' or cpx_classement_administratif = 'Départementale/Route nommée' and  risque =  'tres fort'  then 10
				 when cpx_classement_administratif = 'Départementale' or cpx_classement_administratif = 'Départementale/Route nommée' and  risque =  'fort'  then 10
				 when cpx_classement_administratif = 'Départementale' or cpx_classement_administratif = 'Départementale/Route nommée' and  risque =  'moyen'  then 5
  				 when cpx_classement_administratif = 'Nationale' or cpx_classement_administratif = 'Nationale/Route nommée' and  risque =  'tres fort'  then 10
				 when cpx_classement_administratif = 'Nationale' or cpx_classement_administratif = 'Nationale/Route nommée' and  risque =  'fort'  then 10
				 when cpx_classement_administratif = 'Nationale' or cpx_classement_administratif = 'Nationale/Route nommée' and  risque =  'moyen'  then 5
 				 else 5 end ;


------------------------------------------------------------------------------------
--- II. Modélisation des Obligations 									   	     --- 
------------------------------------------------------------------------------------
--- Résumé : la modélisation des OLD se déroule en 3 étapes : 					 ---														 
--- 1. Zone tampon de x m + largeur de la chaussée autour des tronçons de routes ---
--- 2. Découpage des OLD à l'intérieur du zonage OLD 							 ---
--- 3. Intersection du cadastre     										     ---
------------------------------------------------------------------------------------

--- II-a. Table obligations_routes ---

Drop table if exists old_dep.old_route_temp;
Create table old_dep.old_route_temp as 
select a.id_troncon as id_troncon,
st_buffer(a.geom,(a.deb_m + a.larg_m)) as geom
from old_dep.routes as a, old_dep.zonage_old as b
where st_intersects(a.geom,b.geom);

CREATE INDEX ON old_dep.old_route_temp USING GIST (geom);

UPDATE old_dep.old_route_temp as a 
set geom = st_intersection(a.geom,b.geom)
from old_dep.zonage_old as b
where st_intersects(a.geom,b.geom);

Drop table if exists old_dep.old_route_temp2;
Create table old_dep.old_route_temp2 as 
select a.id_troncon as id_troncon, 
b.geo_parcel as geo_parcel, 
b.adresse as adresse_prop, 
b.compt_com as comptcom_prop,
b.proprietaire as nom_prop,
st_intersection(a.geom,b.geom) as geom,
st_area(st_intersection(a.geom,b.geom)) as surf_m2
from old_dep.old_route_temp as a, old_dep.cadastre as b
where st_intersects(a.geom,b.geom);

DROP TABLE IF EXISTS old_dep.obligations_routes;
CREATE TABLE old_dep.obligations_routes(
   id_obligation SERIAL,
   geom GEOMETRY,
   comptcom_prop VARCHAR(250),
   nom_prop TEXT,
   adresse_prop TEXT,
   surface_m2 FLOAT,
   id_troncon INT,
   geo_parcel VARCHAR(50),
   id_prop VARCHAR(50),
   PRIMARY KEY(id_obligation),
   FOREIGN KEY(id_troncon) REFERENCES old_dep.routes(id_troncon),
   FOREIGN KEY(geo_parcel) REFERENCES old_dep.cadastre(geo_parcel)
);

INSERT INTO old_dep.obligations_routes(geom,comptcom_prop,nom_prop,adresse_prop,surface_m2,id_troncon,geo_parcel)
select geom,comptcom_prop,nom_prop,adresse_prop,surf_m2,id_troncon,geo_parcel
from old_dep.old_route_temp2;


------------------------------------------------
--- III. Cartographie et outils collaboratifs ---
----------------------------------------------------------------------------------------------------------
-- Résumé : 																						   ---
----------------------------------------------------------------------------------------------------------

--- III-a. Table point de repères ---

------------------------------------------------------------------------------------------------
-- NB : Table facultative permettant l'ajout de points de repères connus le long des voiries ---
------------------------------------------------------------------------------------------------

CREATE TABLE Point_de_repère(
   id_pt SERIAL,
   geom GEOMETRY,
   PRIMARY KEY(id_pt)
);


--- III-b. Table lien_poi_routes ---

--------------------------------------------------------------------------------------------
-- NB : Table facultative faisant le lien entre les de points de repères et les  voiries ---
--------------------------------------------------------------------------------------------

CREATE TABLE lien_poi_routes(
   id_troncon SERIAL,
   id_pt SERIAL,
   PRIMARY KEY(id_troncon, id_pt),
   FOREIGN KEY(id_troncon) REFERENCES routes(id_troncon),
   FOREIGN KEY(id_pt) REFERENCES Point_de_repère(id_pt)
);


--- III-c. Table contrôle ---

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
   FOREIGN KEY(id_obligation) REFERENCES obligations_routes(id_obligation)
);

---ou---

ALTER TABLE old_dep.controle
add column id_obligation_routes INTEGER,
add constraint obligations_routes
foreign key(id_obligation_routes) references old_dep.obligations_routes(id_obligation); 


--- III-d. Table gestionnaire privés ---

--------------------------------------------------------
--- NB : Table pour l'ajout manuel de gestionnaires  ---
--------------------------------------------------------

CREATE TABLE old_dep.gestionnaire_prive(
   id_gest INT,
   geo_parcel VARCHAR(50),
   PRIMARY KEY(id_gest, geo_parcel),
   FOREIGN KEY(id_gest) REFERENCES old_dep.gestionnaire(id_gest),
   FOREIGN KEY(geo_parcel) REFERENCES old_dep.cadastre(geo_parcel)
);

drop table if exists old_dep.desserte_massif_04;
drop table if exists old_dep.old_route_temp;
drop table if exists old_dep.old_route_temp2;
drop table if exists old_dep.routes_vf;
drop table if exists old_dep.gest_temp;
drop table if exists old_dep.limitation_tonnage_04;
