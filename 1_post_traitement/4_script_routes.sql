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
----   Remplacer 83XXX   avec le code INSEE de la commune                                                       ----
----   Remplacer XXX par les 3 dernier chiffres du code commune
----   Remplacer AA par le code INSEE du département
----                                                                                                       ----
----   Exemple pour le département du VAR dont le code INSEE est 83                                           ----
----   Rechercher - remplacer "83XXX" par "83" (CTRL+f)                                                          ----
--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--
                            
--*------------------------------------------------------------------------------------------------------------*--
-----------------------------------------------------
--- Création du schéma ---
-----------------------------------------------------

DROP SCHEMA IF EXISTS "83XXX_routes" CASCADE;
CREATE SCHEMA "83XXX_routes";
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--

--- Table gestionnaire (à ne faire tourner qu'une seule fois) ---

-----------------------------------------------------------------------------------------------------
--- NB : Les noms et statuts des gestionnaires peuvent être changés et adaptés aux beosins locaux ---
-----------------------------------------------------------------------------------------------------

drop table if exists "AA_old50m_resultat".gestionnaire;
CREATE TABLE "AA_old50m_resultat".gestionnaire(
   id_gest SERIAL,
   nom_gest VARCHAR(250),
   statut VARCHAR(250),
   adresse TEXT,
   PRIMARY KEY(id_gest)
);
COMMIT;

drop table if exists "83XXX_routes".gest_temp;
create table "83XXX_routes".gest_temp as 
select 
cpx_gestionnaire
FROM r_bdtopo.troncon_de_route
group by cpx_gestionnaire ;
COMMIT;

insert into "AA_old50m_resultat".gestionnaire(nom_gest)
select cpx_gestionnaire
from "83XXX_routes".gest_temp;
COMMIT;

update "AA_old50m_resultat".gestionnaire    --- A changer si besoin
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

--*------------------------------------------------------------------------------------------------------------*--

--- Table routes ---

ALTER TABLE r_bdtopo.troncon_de_route
ADD COLUMN IF NOT EXISTS id_zonage INTEGER; 
COMMIT;

DROP TABLE IF EXISTS "83XXX_routes".troncon_de_route_bdtopo;
CREATE TABLE "83XXX_routes".troncon_de_route_bdtopo as
SELECT a.*
FROM r_bdtopo.troncon_de_route as a, r_cadastre.geo_commune as b 
WHERE b.idu = 'XXX' and st_intersects(a.geom,b.geom);
COMMIT;

UPDATE "83XXX_routes".troncon_de_route_bdtopo as a 
SET id_zonage = b.fid
from public.old200m as b 
where st_intersects(a.geom,b.geom);
COMMIT; 

DROP TABLE IF EXISTS "83XXX_routes".routes;
CREATE TABLE "83XXX_routes".routes(
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
   id_gest VARCHAR,
   id_zonage INT,
   PRIMARY KEY(id_troncon)
);
COMMIT;

insert into "83XXX_routes".routes(cleabs,nature,importance,acces_vehicule_leger, nom_voie, cpx_numero, cpx_classement_administratif, cpx_gestionnaire, nombre_de_voies,largeur_de_chaussee,geom,id_zonage)
select cleabs,nature,importance,acces_vehicule_leger,cpx_toponyme_route_nommee, cpx_numero,cpx_classement_administratif , cpx_gestionnaire,nombre_de_voies,largeur_de_chaussee,geom,id_zonage
from "83XXX_routes".troncon_de_route_bdtopo
where acces_vehicule_leger = 'Libre' or acces_vehicule_leger = 'A préage' and id_zonage is not null ; --- Seulement les routes ouvertes à la circulation et soumises aux OLD
COMMIT;

CREATE INDEX ON "83XXX_routes".routes USING GIST (geom);
COMMIT;

UPDATE "83XXX_routes".routes as a 
SET id_gest = b.id_gest
from "AA_old50m_resultat".gestionnaire as b
where a.cpx_gestionnaire = b.nom_gest;
COMMIT;

UPDATE "83XXX_routes".routes 
SET cpx_gestionnaire = case 
					   when  cpx_gestionnaire is null then 'prive'
					   else cpx_gestionnaire end,
	deb_m = case when cpx_classement_administratif =  'Autoroute/Route nommée'  then 20 
 				 when cpx_classement_administratif = 'Départementale' or cpx_classement_administratif = 'Départementale/Route nommée'  then 10
  				 when cpx_classement_administratif = 'Nationale' or cpx_classement_administratif = 'Nationale/Route nommée'  then 10
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

UPDATE "83XXX_routes".routes
SET nombre_de_voies = case when nombre_de_voies < 1 or nombre_de_voies is null then 1 else nombre_de_voies end,
largeur_de_chaussee = case when largeur_de_chaussee < 1 or largeur_de_chaussee is null then 1 else largeur_de_chaussee end; 
COMMIT; 

Drop table if exists "83XXX_routes".old_route_temp;
Create table "83XXX_routes".old_route_temp as 
select a.cleabs as cleabs,
st_buffer(a.geom,(a.deb_m + (a.largeur_de_chaussee *  a.nombre_de_voies ))) as geom
from "83XXX_routes".routes as a, public.old200m as b
where st_intersects(a.geom,b.geom);
COMMIT;

CREATE INDEX ON "83XXX_routes".old_route_temp USING GIST (geom);
COMMIT;

UPDATE "83XXX_routes".old_route_temp as a 
set geom = st_intersection(a.geom,b.geom)
from public.old200m as b
where st_intersects(a.geom,b.geom);
COMMIT;

Drop table if exists "83XXX_routes".old_route_temp2;
Create table "83XXX_routes".old_route_temp2 as 
select a.cleabs as cleabs, 
b.geo_parcelle, 
b.adresse as adresse_prop, 
b.comptecommunal as comptcom_prop,
b.proprietaire as nom_prop,
st_intersection(a.geom,b.geom) as geom
from "83XXX_routes".old_route_temp as a, r_cadastre.parcelle_info as b
where st_intersects(a.geom,b.geom);
COMMIT;

DROP TABLE IF EXISTS "AA_old50m_resultat"."83XXX_obligations_routes";
CREATE TABLE "AA_old50m_resultat"."83XXX_obligations_routes"(
   id_obligation SERIAL,
   geom GEOMETRY,
   comptcom_prop VARCHAR(250),
   nom_prop TEXT,
   adresse_prop TEXT,
   surface_m2 FLOAT,
   cleabs VARCHAR,
   geo_parcelle VARCHAR(50),
   id_prop VARCHAR(50),
   PRIMARY KEY(id_obligation)
);
COMMIT;

INSERT INTO "AA_old50m_resultat"."83XXX_obligations_routes"(geom,comptcom_prop,nom_prop,adresse_prop,cleabs,geo_parcelle)
select geom,comptcom_prop,nom_prop,adresse_prop,cleabs,geo_parcelle
from "83XXX_routes".old_route_temp2;
COMMIT;

ALTER TABLE "AA_old50m_resultat"."83XXX_obligations_routes"
ADD COLUMN IF NOT EXISTS gestionnaire TEXT; 

UPDATE "AA_old50m_resultat"."83XXX_obligations_routes" as a 
SET gestionnaire = b.cpx_gestionnaire
FROM r_bdtopo.troncon_de_route as b 
WHERE a.cleabs = b.cleabs;


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

DROP SCHEMA "83XXX_routes" CASCADE;
COMMIT;






