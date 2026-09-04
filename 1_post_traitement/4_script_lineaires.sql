--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--
------------------------------------- 🚆🚗 LINEAIRES 🚗🚆 ----------------------------------------------------------------
--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--
--- Identifier les obligations légales de débroussaillement (OLD) générées par les voies                       ---
--- de transport ouvertes à la circulation publique et les voies férrées.    					                                   --- 
--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--
--- Auteurs : CRIGE PACA, Communes forestières PACA                                                ---                    
--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--


--*------------------------------------------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------------------------------------------*--
----------------------------------------- Données nécéssaires ----------------------------------------------------------------------------------------
--- Tronçons de routes de la BD TOPO renommé r_bdtopo.troncon_de_route																			  ----											  ----
--- Tronçons de voies ferrées de la BD TOPO renommé r_bdtopo.troncon_de_voie_ferree 															  ----
--- Tables public.gestionnaires : 																												  ----
--- 	Table d'exemple disponible Github 																										  ----
---		script update_gestionnaires.sql pour mettre à jour la table gestionnaires depuis la BD_TOPO		 										  ----
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
--- Création du schéma et restart ---
-----------------------------------------------------

DROP SCHEMA IF EXISTS "83XXX_lineaires" CASCADE;								--- Schéma de travail
CREATE SCHEMA "83XXX_lineaires";
COMMIT;

DELETE FROM "AA_old50m_resultat"."83XXX_result_final_mcd"						--- Eviter les doublons dans la table finale
WHERE id_troncon IS NOT NULL; 
COMMIT;

DELETE FROM "AA_old50m_resultat"."83XXX_result_final_mcd"						--- Eviter les doublons dans la table finale
WHERE id_vf IS NOT NULL; 
COMMIT;


--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--
--- I. Création d'un réseau unique de routes 					   									   	       --- 
--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--

--*------------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------------*--													 
---	Résumé :																									   ---
---		1 - Selection des routes situées sur la commune 'XXX' et concernées par les OLD							   ---
---		2 - Création d'une table "83XXX_lineaires".routes contenant les informations nécéssaire à la 			   ---
---		 modélisation des OLD     																				   ---												   ---
----------------------------------------------------------------------------------------------------------------------
--*------------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------------*--

--*------------------------------------------------------------------------------------------------------------*--
--- Table "83XXX_lineaires".troncon_de_route_bdtopo ---
--*------------------------------------------------------------------------------------------------------------*--
--- Découpage du réseau r_bdtopo.troncon_de_route sur l'emprise de la commune 'XXX'							   ---
--*------------------------------------------------------------------------------------------------------------*--

ALTER TABLE r_bdtopo.troncon_de_route
ADD COLUMN IF NOT EXISTS id_zonage INTEGER; 								--- Colonne prévue pour l'identifiant du zonage old (ref : public.old200m)
COMMIT;

DROP TABLE IF EXISTS "83XXX_lineaires".troncon_de_route_bdtopo;
CREATE TABLE "83XXX_lineaires".troncon_de_route_bdtopo as
SELECT a.*
FROM r_bdtopo.troncon_de_route as a, 										--- Tronçons de route de la BD TOPO
r_cadastre.geo_commune as b 												--- Table des communes
WHERE b.idu = 'XXX' and st_intersects(a.geom,b.geom);
COMMIT;

UPDATE "83XXX_lineaires".troncon_de_route_bdtopo as a 						--- Récupération de l'identifiant du zonage informatif des old (ref : public.old200m)
SET id_zonage = b.fid														--- Si null le tronçon n'est pas concerné par les OLD
from public.old200m as b 
where st_intersects(a.geom,b.geom);
COMMIT; 

--*------------------------------------------------------------------------------------------------------------*--
--- Table "83XXX_lineaires".routes ---
--*------------------------------------------------------------------------------------------------------------*--
--- Table qui servira à la modélisation des OLD 															   ---
--*------------------------------------------------------------------------------------------------------------*--

DROP TABLE IF EXISTS "83XXX_lineaires".routes;
CREATE TABLE "83XXX_lineaires".routes(
   id_troncon SERIAL,														--- Identifiant unique du tronçon
   cleabs VARCHAR(50),														--- Identifiant source du tronçon 
   nature VARCHAR(50),														--- Nature du tronçon 
   importance VARCHAR(50),													--- Importance du tronçon dans le graphe
   acces_vehicule_leger VARCHAR(50),										--- Voie ouverte à la circulation
   nom_voie TEXT,															--- Nom du tronçon (ex : N7) 
   cpx_numero VARCHAR(50),													--- Numéro du tronçon 
   cpx_classement_administratif VARCHAR(50),								--- Classement du tronçon (ex : départementale)
   cpx_gestionnaire VARCHAR(50),											--- Gestionnaire du tronçon (ex : département des Bouches-du-Rhône)
   nombre_de_voies INT,														--- Nombre de voies sur le tronçon 
   largeur_de_chaussee INT,													--- Largeur de la chaussée (en m) 
   deb_m INTEGER,															--- Distance de débroussaillement à effectuer depuis la ligne centrale de la chaussée  
   source VARCHAR(50),														--- Base de données source
   geom GEOMETRY,
   id_gest INT,																--- Identifiant du gestionnaire (ref : public.gestionnaire)
   id_zonage INT,															--- identifiant du zonage old (ref : public.old200m) 
   PRIMARY KEY(id_troncon)
);
COMMIT;

insert into "83XXX_lineaires".routes(cleabs,nature,importance,acces_vehicule_leger, nom_voie, cpx_numero, cpx_classement_administratif, cpx_gestionnaire, nombre_de_voies,largeur_de_chaussee,geom,id_zonage)
select cleabs,nature,importance,acces_vehicule_leger,cpx_toponyme_route_nommee, cpx_numero,cpx_classement_administratif , cpx_gestionnaire,nombre_de_voies,largeur_de_chaussee,geom,id_zonage
from "83XXX_lineaires".troncon_de_route_bdtopo
where acces_vehicule_leger = 'Libre' or acces_vehicule_leger = 'A préage' and id_zonage is not null ; --- Seulement les routes ouvertes à la circulation et soumises aux OLD
COMMIT;

CREATE INDEX ON "83XXX_lineaires".routes USING GIST (geom);
COMMIT;

UPDATE "83XXX_lineaires".routes as a 
SET id_gest = b.id_gest
from public.gestionnaires as b
where a.cpx_gestionnaire = b.nom_gest;
COMMIT;

UPDATE "83XXX_lineaires".routes 
SET cpx_gestionnaire = case 
					   when  cpx_gestionnaire is null then 'prive'																			   --- Quand aucun gestionnaire n'est identifié, la voie est classée par défaut en 'privé'
					   else cpx_gestionnaire end,
	deb_m = case when cpx_classement_administratif =  'Autoroute/Route nommée'  then 20 													   --- Distance de débroussaillement dépendant du classement administratif de la voie (voir arrêté préféectoral)
 				 when cpx_classement_administratif = 'Départementale' or cpx_classement_administratif = 'Départementale/Route nommée'  then 10 --- Distance de débroussaillement dépendant du classement administratif de la voie (voir arrêté préféectoral)
  				 when cpx_classement_administratif = 'Nationale' or cpx_classement_administratif = 'Nationale/Route nommée'  then 10 		   --- Distance de débroussaillement dépendant du classement administratif de la voie (voir arrêté préféectoral)
 				 else 5 end ;
COMMIT;



--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--
--- II. Création d'un réseau unique des voies férrées 					   									   	       --- 
--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--

--*------------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------------*--													 
---	Résumé :																									   ---
---		1 - Selection des tronçons de chemin de fer situés sur la commune 'XXX' et concernées par les OLD		   ---
---		2 - Création d'une table "83XXX_lineaires"."83XXX_voies_ferees" contenant les informations nécéssaire      ---
---         à la modélisation des OLD     		 															       ---
----------------------------------------------------------------------------------------------------------------------
--*------------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------------*--


--*------------------------------------------------------------------------------------------------------------*--
--- Table r_bdtopo.troncon_de_voie_ferree ---
--*------------------------------------------------------------------------------------------------------------*--
--- Table initale issue de la BD TOPO 			 															   ---
--*------------------------------------------------------------------------------------------------------------*--

ALTER TABLE r_bdtopo.troncon_de_voie_ferree
ADD COLUMN IF NOT EXISTS id_gest INT,									--- Identifiant unique du gestionnaire du tronçon (ref : public.gestionnaires)
ADD COLUMN IF NOT EXISTS id_zonage INT,									--- Identifiant unique du zonage informatif des old (ref : public.old200m) 	
ADD COLUMN IF NOT EXISTS larg_m INT; 									--- Largeur (en m) de la voie
COMMIT;

UPDATE r_bdtopo.troncon_de_voie_ferree as a 							--- Récupération de l'identifiant du zonage informatif des old (ref : public.old200m)
SET id_zonage = b.fid													--- Si null le tronçon n'est pas concerné par les OLD
from public.old200m as b
where st_intersects(a.geom,b.geom); 
COMMIT;

UPDATE r_bdtopo.troncon_de_voie_ferree 									--- Affection d'un gestionnaire 
SET id_gest = CASE WHEN largeur = 'Etroite' THEN 18						--- En PACA, la Région est gestionnaire de la ligne Digne-les-Bains - Nice.
WHEN largeur = 'Normale' then 15										--- Voir la table public.gestionnaires
else null end; 
COMMIT;

UPDATE r_bdtopo.troncon_de_voie_ferree  								--- Affectation d'une largeur de voie en fonction des standards d'écartement
SET larg_m = CASE WHEN largeur = 'Etroite' THEN 1
WHEN largeur = 'Normale' then 1.435
else null end; 
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--
--- Table r_bdtopo.voies_ferees ---
--*------------------------------------------------------------------------------------------------------------*--
--- Table intermédiaire (à condenser avec "83XXX_lineaires"."83XXX_voies_ferees") 			 			 															   ---
--*------------------------------------------------------------------------------------------------------------*--

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
SET deb_m = (larg_m*nb_voies)+7;  										--- Largeur de débroussaillement total depuis la ligne centrale de la voie (voir arrêté) 
COMMIT;

CREATE INDEX ON r_bdtopo.voies_ferees USING GIST (geom);
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--
--- "83XXX_lineaires"."83XXX_voies_ferees" ---
--*------------------------------------------------------------------------------------------------------------*--
--- Table qui servira à la modélisation des OLD 															   ---
--*------------------------------------------------------------------------------------------------------------*--

DROP TABLE IF EXISTS "83XXX_lineaires"."83XXX_voies_ferees";
CREATE TABLE "83XXX_lineaires"."83XXX_voies_ferees" as 
SELECT a.*
FROM r_bdtopo.voies_ferees  as a, r_cadastre.geo_commune as b
where b.idu = 'XXX' and st_intersects(a.geom,b.geom);  				--- Selection des tronçons de voies férrées situés sur la commune 'XXX'
COMMIT; 

CREATE INDEX ON "83XXX_lineaires"."83XXX_voies_ferees" USING GIST (geom); 
COMMIT;


--*------------------------------------------------------------------------------------------------------------*--
------------------------------------------------------------------------------------
--- III. Modélisation des obligations liées aux routes							 --- 
------------------------------------------------------------------------------------
--- Résumé : la modélisation des OLD se déroule en 3 étapes : 					 ---														 
--- 1. Zone tampon de x m + largeur de la chaussée autour des tronçons de routes ---
--- 2. Découpage des OLD à l'intérieur du zonage OLD 							 ---
--- 3. Intersection avec le cadastre    												 ---
------------------------------------------------------------------------------------
--*------------------------------------------------------------------------------------------------------------*--

--*------------------------------------------------------------------------------------------------------------*--
--- "83XXX_lineaires".old_route_temp ---
--*------------------------------------------------------------------------------------------------------------*--
--- Zone tampon de distance "deb_m" (variable suivant les arrêtés prefectoraux)								   ---
--*------------------------------------------------------------------------------------------------------------*--

UPDATE "83XXX_lineaires".routes
SET nombre_de_voies = case when nombre_de_voies < 1 or nombre_de_voies is null then 1 else nombre_de_voies end,					--- 1 voie par défaut lorsque null
largeur_de_chaussee = case when largeur_de_chaussee < 1 or largeur_de_chaussee is null then 1 else largeur_de_chaussee end; 	--- La voie est large de 1 m par défaut lorsque null
COMMIT; 

Drop table if exists "83XXX_lineaires".old_route_temp;
Create table "83XXX_lineaires".old_route_temp as 
select a.id_troncon as id_troncon,
st_buffer(a.geom,																							--- Zone tampon autour des tronçons
	(a.deb_m + 																									--- Profondeur de débroussaillement depuis les bords extérieurs de la voie (voir arrêté) 
		(a.largeur_de_chaussee *  a.nombre_de_voies ))) as geom														--- Largeur de chaussée (en m) et nombre de voies 
from "83XXX_lineaires".routes as a, 																		--- Réseau routier sur la commune 'XXX'
public.old200m as b																							--- Zonage informatif des OLD 					
where st_intersects(a.geom,b.geom);																			--- Lorsque le tronçon est situé sur le zonage informatif 
COMMIT;

CREATE INDEX ON "83XXX_lineaires".old_route_temp USING GIST (geom);
COMMIT;

UPDATE "83XXX_lineaires".old_route_temp as a 																--- Découpage des zones tampon sur le zonage OLD. 
set geom = st_intersection(a.geom,b.geom)												
from public.old200m as b
where st_intersects(a.geom,b.geom);
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--
--- "83XXX_lineaires".old_route_temp2 ---
--*------------------------------------------------------------------------------------------------------------*--
--- Affectation des informations cadastrales des propriétés qui doivent être débroussaillées par les 		   ---
--- gestionnaires des réseaux routiers. 												   ---
--*------------------------------------------------------------------------------------------------------------*--

Drop table if exists "83XXX_lineaires".old_route_temp2;
Create table "83XXX_lineaires".old_route_temp2 as 
select a.id_troncon as id_troncon, 
b.geo_parcelle, 																						--- N° de la parcelle à débroussailler 
b.adresse as adresse_prop, 																				--- Adresse du propriétaire de la parcelle
b.comptecommunal as comptcom_prop,																		--- Compte communal du propriétaire de la parcelle
b.proprietaire as nom_prop,																				--- Nom du propriétaire
st_intersection(a.geom,b.geom) as geom																	--- Intersection entre la zone tampon et la table r_cadastre.parcelle_info
from "83XXX_lineaires".old_route_temp as a, r_cadastre.parcelle_info as b
where st_intersects(a.geom,b.geom);
COMMIT;

CREATE INDEX ON "83XXX_lineaires".old_route_temp2 USING GIST (geom);
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--
--- "83XXX_lineaires"."83XXX_obligations_routes" ---
--*------------------------------------------------------------------------------------------------------------*--
--- Insertion des résultats dans une table temporaire conforme au modèle de données					 		   ---
--*------------------------------------------------------------------------------------------------------------*--

DROP TABLE IF EXISTS "83XXX_lineaires"."83XXX_obligations_routes";
CREATE TABLE "83XXX_lineaires"."83XXX_obligations_routes"(
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

INSERT INTO "83XXX_lineaires"."83XXX_obligations_routes"(geom,comptcom_prop,nom_prop,adresse_prop,id_troncon,geo_parcelle)
select geom,comptcom_prop,nom_prop,adresse_prop,id_troncon,geo_parcelle
from "83XXX_lineaires".old_route_temp2;
COMMIT;

CREATE INDEX ON "83XXX_lineaires"."83XXX_obligations_routes" USING GIST (geom);
COMMIT;


--*------------------------------------------------------------------------------------------------------------*--
------------------------------------------------------------------------------------
--- IV. Modélisation des obligations liées aux voies férrées					 --- 
-------------------------------------------------------------------------------------------
--- Résumé : la modélisation des OLD se déroule en 3 étapes : 					 		---														 
--- 1. Zone tampon de x m + largeur de la chaussée autour des tronçons de voies férrées ---
--- 2. Découpage des OLD à l'intérieur des forêts concernées par le zonage OLD 			---
--- 3. Intersection avec le cadastre    												 		---
-------------------------------------------------------------------------------------------
--*------------------------------------------------------------------------------------------------------------*--

--*------------------------------------------------------------------------------------------------------------*--
--- Table "83XXX_lineaires".bd_foret ---
--*------------------------------------------------------------------------------------------------------------*--
--- Découpage du masque forestier BD_foret sur l'emprise de la commune XXX ---
--*------------------------------------------------------------------------------------------------------------*--

DROP TABLE IF EXISTS "83XXX_lineaires".bd_foret;
CREATE TABLE "83XXX_lineaires".bd_foret as 
SELECT a.*
FROM r_bdtopo.bd_foret as a, r_cadastre.geo_commune as b
where b.idu = 'XXX' and st_intersects(a.geom,b.geom); 
COMMIT;

CREATE INDEX ON "83XXX_lineaires".bd_foret USING GIST (geom);
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--
--- Table "83XXX_lineaires".bd_foretrgr ---
--*------------------------------------------------------------------------------------------------------------*--
--- Intersection des patchs forestier BD_foret sur l'emprise des zonage informatif des OLD (ref : public.old200m) ---
--- A supprimer si on veut calculer les OLD pour les voies férrées situées à 20m de toutes les forêts 			  ---
--*------------------------------------------------------------------------------------------------------------*--

drop table if exists "83XXX_lineaires".bd_foretrgr;
create table "83XXX_lineaires".bd_foretrgr as 
select ST_intersection(a.geom,b.geom) as geom									--- Intersection des géométries 
from  "83XXX_lineaires".bd_foret as a, public.old200m as b
where st_intersects(a.geom,b.geom);												--- Là où la bd_foret intersecte le zonage informatif des OLD 
COMMIT;

CREATE INDEX ON "83XXX_lineaires".bd_foretrgr USING GIST (geom);
COMMIT;


--*------------------------------------------------------------------------------------------------------------*--
--- Table "83XXX_lineaires".bd_foret20m ---
--*------------------------------------------------------------------------------------------------------------*--
--- Zone tampon de 20 m autour des massifs forestiers concernés par les OLD 								   ---
--*------------------------------------------------------------------------------------------------------------*--

drop table if exists "83XXX_lineaires".bd_foret20m;
create table  "83XXX_lineaires".bd_foret20m as 
select st_union(st_buffer(a.geom,20)) as geom
from  "83XXX_lineaires".bd_foretrgr as a, public.old200m as b
where st_intersects(a.geom,b.geom);
COMMIT;

CREATE INDEX ON "83XXX_lineaires".bd_foret20m USING GIST (geom);
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--
--- Table "83XXX_lineaires".vf_gl_temp0 ---
--*------------------------------------------------------------------------------------------------------------*--
--- Découpage du réseau "83XXX_lineaires"."83XXX_voies_ferees" sur l'emprise de la zone tampon de 20 m autour  ---
--- des forêts situées dans un zonage OLD.  																   ---
--*------------------------------------------------------------------------------------------------------------*--

drop table if exists "83XXX_lineaires".vf_gl_temp0;
create table "83XXX_lineaires".vf_gl_temp0 as 
select a.id_vf as id_vf, 										--- Identifiant unique du tronçon
a.deb_m,														--- Surface à débroussailler autour du tronçon 
ST_Intersection(a.geom,b.geom) as geom							--- Intersection 
from  "83XXX_lineaires"."83XXX_voies_ferees" as a, 				--- Réseau férroviaire en zone OLD sur la commune 'XXX'
"83XXX_lineaires".bd_foret20m  as b								--- Masque forestier + 20 m en zone OLD sur la commune 'XXX'
where st_intersects(a.geom,b.geom);
COMMIT;

CREATE INDEX ON "83XXX_lineaires".vf_gl_temp0 USING GIST (geom);
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--
--- Table "83XXX_lineaires".vf_gl_temp1 ---
--*------------------------------------------------------------------------------------------------------------*--
--- Zone tampon de distance "deb_m"																	 		   ---
--*------------------------------------------------------------------------------------------------------------*--

drop table if exists "83XXX_lineaires".vf_gl_temp1;
create table "83XXX_lineaires".vf_gl_temp1 as 
select a.id_vf as id_vf,
st_buffer(a.geom,(deb_m)) as geom								--- Zone tampon
from  "83XXX_lineaires".vf_gl_temp0 as a, 						--- Tronçon concernés par les OLD 
"83XXX_lineaires".bd_foret20m  as b								--- Forêt situées dans le zonage OLD + 20m 
where st_intersects(a.geom,b.geom);
COMMIT;

CREATE INDEX ON "83XXX_lineaires".vf_gl_temp1 USING GIST (geom);
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--
--- "83XXX_lineaires".vf_gl_old_temp ---
--*------------------------------------------------------------------------------------------------------------*--
--- Affectation des informations cadastrales des propriétés qui doivent être débroussaillées par les 		   ---
--- gestionnaires des réseaux férroviaires. 												   ---
--*------------------------------------------------------------------------------------------------------------*--


drop table if exists "83XXX_lineaires".vf_gl_old_temp;
create table "83XXX_lineaires".vf_gl_old_temp as 
select a.id_vf as id_vf,
b.proprietaire as nom_prop, 									--- Nom du propriétaire
b.geo_parcelle,													--- N° de la parcelle à débroussailler 
b.comptecommunal as comptcom_prop,								--- Compte de propriété du propriétaire de la parcelle
b.adresse as adresse_prop, 										--- Adresse du propriétaire
st_intersection(a.geom,b.geom) as geom							--- Intersection entre la zone tampon et la table r_cadastre.parcelle_info
from "83XXX_lineaires".vf_gl_temp1 as a, r_cadastre.parcelle_info as b
where st_intersects(a.geom,b.geom);
COMMIT;

CREATE INDEX ON "83XXX_lineaires".vf_gl_old_temp USING GIST (geom);
COMMIT;


--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--
--- III. Insertion des résultats dans la couche "AA_old50m_resultat"."83XXX_result_final_mcd"     			   --- 
--*------------------------------------------------------------------------------------------------------------*--
--------------------------------------------------------------------------------------------------------------------------------------------
--- Résumé  : 																															---														 
--- 1. Insertion des OLD générées par les routes dans la table   "AA_old50m_resultat"."83XXX_result_final_mcd"							---
--- 2. Insertion des OLD générées par les voies férrées dans la table 	 "AA_old50m_resultat"."83XXX_result_final_mcd"			        ---
--- Les deux tables partageront le même champs de géométrie dans la table de destination. 												---
--------------------------------------------------------------------------------------------------------------------------------------------
--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--

--*------------------------------------------------------------------------------------------------------------*--
--- Routes ---
--*------------------------------------------------------------------------------------------------------------*--

INSERT INTO "AA_old50m_resultat"."83XXX_result_final_mcd"(nom_prop,comptcom_prop,geom_obligations_lineaires,id_troncon,geo_parcel)
SELECT nom_prop,comptcom_prop,geom,id_troncon,geo_parcelle
FROM "83XXX_lineaires"."83XXX_obligations_routes";
COMMIT;

UPDATE "AA_old50m_resultat"."83XXX_result_final_mcd" as a 
SET id_gest = b.id_gest											--- Identifiant du gestionnaire (ref : public.gestionnaires)
FROM "83XXX_lineaires".routes as b
WHERE a.id_troncon = b.id_troncon AND a.id_troncon IS NOT NULL;	--- Jointure depuis la table "83XXX_lineaires".routes
COMMIT;

UPDATE "AA_old50m_resultat"."83XXX_result_final_mcd" as a 
SET obl_nom = b.nom_gest,										--- Nom du gestionnaire
obl_statut = b.statut,											--- Statut du gestionnaire (privé, départemental...)
obl_adresse = b.adresse											--- Adresse du gestionnaire
FROM public.gestionnaires as b
WHERE a.id_gest = b.id_gest AND a.id_troncon IS NOT NULL;
COMMIT;

UPDATE "AA_old50m_resultat"."83XXX_result_final_mcd"
SET id_old = concat(id_gest,'lineaires',fid_old),				--- Identifiant unique et stable de l'OLD 
surface_m2 = st_area(geom_obligations_lineaires)				--- Surface à débroussailler
WHERE id_troncon IS NOT NULL;
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--
--- Voies férrées ---
--*------------------------------------------------------------------------------------------------------------*--

INSERT INTO "AA_old50m_resultat"."83XXX_result_final_mcd"(nom_prop,comptcom_prop,geom_obligations_lineaires,id_vf,geo_parcel)
SELECT nom_prop,comptcom_prop,geom,id_vf,geo_parcelle
FROM "83XXX_lineaires".vf_gl_old_temp;
COMMIT;

UPDATE "AA_old50m_resultat"."83XXX_result_final_mcd" as a 
SET id_gest = b.id_gest											--- Identifiant du gestionnaire (ref : public.gestionnaires)
FROM "83XXX_lineaires"."83XXX_voies_ferees" as b
WHERE a.id_vf = b.id_vf AND a.id_vf IS NOT NULL;				--- Jointure depuis la table"83XXX_lineaires"."83XXX_voies_ferees"
COMMIT;

UPDATE "AA_old50m_resultat"."83XXX_result_final_mcd" as a 
SET obl_nom = b.nom_gest,										--- Nom du gestionnaire
obl_statut = b.statut,											--- Statut du gestionnaire (privé, départemental...)
obl_adresse = b.adresse											--- Adresse du gestionnaire
FROM public.gestionnaires as b
WHERE a.id_gest = b.id_gest AND a.id_vf IS NOT NULL;
COMMIT;

UPDATE "AA_old50m_resultat"."83XXX_result_final_mcd"
SET id_old = concat(id_gest,'lineaires',fid_old),				--- Identifiant unique et stable de l'OLD 
surface_m2 = st_area(geom_obligations_lineaires)				--- Surface à débroussailler
WHERE id_vf IS NOT NULL;
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--


--*-----------------------------------------------------------------------------------------------------------*--
--*-----------------------------------------------------------------------------------------------------------*--
----                                 NETTOYAGE DU SCHÉMA DE TRAVAIL                                          ----
--*-----------------------------------------------------------------------------------------------------------*--
-- Description : Suppression complète du schéma de travail et de TOUTES ses tables (CASCADE).                ----
--               ATTENTION : Opération IRRÉVERSIBLE. À n''exécuter QUE si :                                  ----
--               • La table finale a été vérifiée et validée                                                 ----
--               • Les exports nécessaires ont été réalisés                                                  ----
--               • Aucun besoin de traçabilité/debug des tables intermédiaires                               ----
--               Libère l''espace disque occupé par les tables temporaires de calcul.                        ----
--*-----------------------------------------------------------------------------------------------------------*--

DROP SCHEMA "83XXX_lineaires" CASCADE;
COMMIT;






