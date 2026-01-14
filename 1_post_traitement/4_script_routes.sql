--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--
------------------------------------- 🚗 ROUTES 🚗 ----------------------------------------------------------------
--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--
--- Identifier les obligations légales de débroussaillement (OLD) générées par les voies                       ---
--- de transport ouvertes à la circulation publique     					                                   --- 
--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--
--- Auteurs : CRIGE PACA, Communes forestières PACA                                                ---                    
--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--


--*------------------------------------------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------------------------------------------*--
----------------------------------------- Données nécéssaires ----------------------------------------------------------------------------------------
--- Tronçons de routes de la BD TOPO renommé "r_bdtopo".troncon_de_route																			  ----											  ----
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
                            
--*------------------------------------------------------------------------------------------------------------*--
-----------------------------------------------------
--- Création du schéma ---
-----------------------------------------------------

DROP SCHEMA IF EXISTS "04_routes";
CREATE SCHEMA "04_routes";
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--

--- Table routes ---

ALTER TABLE r_bdtopo.troncon_de_route
ADD COLUMN IF NOT EXISTS id_zonage INTEGER; 
COMMIT;

UPDATE r_bdtopo.troncon_de_route as a 
SET id_zonage = b.fid
from public.old200m as b 
where st_intersects(a.geom,b.geom);
COMMIT; 

DROP TABLE IF EXISTS "04_routes".routes;
CREATE TABLE "04_routes".routes(
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
   PRIMARY KEY(id_troncon)
);
COMMIT;

insert into "04_routes".routes(id_bdtopo,nature,importance, nom_voie, cpx_numero, cpx_classement_administratif, cpx_gestionnaire,geom,id_zonage)
select cleabs,nature,importance, cpx_toponyme_route_nommee, cpx_numero,cpx_classement_administratif , cpx_gestionnaire,geom,id_zonage
from r_bdtopo.troncon_de_route
where acces_vehicule_leger = 'Libre' or acces_vehicule_leger = 'A préage' ; --- Seulement les routes ouvertes à la circulation
COMMIT;

CREATE INDEX ON "04_routes".routes USING GIST (geom);
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--

--- Table gestionnaire ---

-----------------------------------------------------------------------------------------------------
--- NB : Les noms et statuts des gestionnaires peuvent être changés et adaptés aux beosins locaux ---
-----------------------------------------------------------------------------------------------------

drop table if exists "XX_old50m_resultat".gestionnaire;
CREATE TABLE "XX_old50m_resultat".gestionnaire(
   id_gest SERIAL,
   nom_gest VARCHAR(250),
   statut VARCHAR(250),
   adresse TEXT,
   PRIMARY KEY(id_gest)
);
COMMIT;

drop table if exists "04_routes".gest_temp;
create table "04_routes".gest_temp as 
select 
cpx_gestionnaire
FROM "04_routes".routes
group by cpx_gestionnaire ;
COMMIT;

insert into "XX_old50m_resultat".gestionnaire(nom_gest)
select cpx_gestionnaire
from "04_routes".gest_temp;
COMMIT;

update "XX_old50m_resultat".gestionnaire    --- A changer si besoin
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
COMMIT;

UPDATE "XX_old50m_resultat".routes as a 
SET id_gest = b.id_gest
from "XX_old50m_resultat".gestionnaire as b
where a.cpx_gestionnaire = b.nom_gest;
COMMIT;

UPDATE "04_routes".routes 
SET cpx_gestionnaire = case when cpx_gestionnaire is null then gest_desserte 
					   when  cpx_gestionnaire is null and prive = true then 'prive'
					   else cpx_gestionnaire end,
	deb_m = case when cpx_classement_administratif =  'Autoroute/Route nommée'  then 20 
 				 when cpx_classement_administratif = 'Départementale' or cpx_classement_administratif = 'Départementale/Route nommée'  then 10
  				 when cpx_classement_administratif = 'Nationale' or cpx_classement_administratif = 'Nationale/Route nommée' and  risque =  'tres fort'  then 10
 				 else 5 end ;
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--
------------------------------------------------------------------------------------
--- II. Modélisation des Obligations 									   	     --- 
------------------------------------------------------------------------------------
--- Résumé : la modélisation des OLD se déroule en 3 étapes : 					 ---														 
--- 1. Zone tampon de x m + largeur de la chaussée autour des tronçons de routes ---
--- 2. Découpage des OLD à l'intérieur du zonage OLD 							 ---
--- 3. Intersection du cadastre     										     ---
------------------------------------------------------------------------------------
--*------------------------------------------------------------------------------------------------------------*--

--*------------------------------------------------------------------------------------------------------------*--
--- Table obligations_routes ---

Drop table if exists "04_routes".old_route_temp;
Create table "04_routes".old_route_temp as 
select a.id_troncon as id_troncon,
st_buffer(a.geom,(a.deb_m + a.larg_m)) as geom
from "04_routes".routes as a, public.old200m as b
where st_intersects(a.geom,b.geom);
COMMIT;

CREATE INDEX ON "04_routes".old_route_temp USING GIST (geom);
COMMIT;

UPDATE "04_routes".old_route_temp as a 
set geom = st_intersection(a.geom,b.geom)
from public.old200m as b
where st_intersects(a.geom,b.geom);
COMMIT;

Drop table if exists "04_routes".old_route_temp2;
Create table "04_routes".old_route_temp2 as 
select a.id_troncon as id_troncon, 
b.geo_parcelle, 
b.adresse as adresse_prop, 
b.comptecommunal as comptcom_prop,
b.proprietaire as nom_prop,
st_intersection(a.geom,b.geom) as geom
from "04_routes".old_route_temp as a, r_cadastre.parcelle_info as b
where st_intersects(a.geom,b.geom);
COMMIT;

DROP TABLE IF EXISTS "XX_old50m_resultat".obligations_routes;
CREATE TABLE "XX_old50m_resultat".obligations_routes(
   id_obligation SERIAL,
   geom GEOMETRY,
   comptcom_prop VARCHAR(250),
   nom_prop TEXT,
   adresse_prop TEXT,
   surface_m2 FLOAT,
   id_troncon INT,
   geo_parcel VARCHAR(50),
   id_prop VARCHAR(50),
   PRIMARY KEY(id_obligation)
);
COMMIT;

INSERT INTO "XX_old50m_resultat".obligations_routes(geom,comptcom_prop,nom_prop,adresse_prop,surface_m2,id_troncon,geo_parcel)
select geom,comptcom_prop,nom_prop,adresse_prop,surf_m2,id_troncon,geo_parcelle
from "04_routes".old_route_temp2;
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

DROP SCHEMA "04_routes" CASCADE;
COMMIT;



