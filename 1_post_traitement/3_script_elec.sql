--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--
------------------------------------- ⚡ LIGNES ELECTRIQUES ⚡ -------------------------------------
--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--
--- Identifier les obligations légales de débroussaillement (OLD) générées par les infrastrutures  ---
--- de transport d'éléctricité les gestionnaires chargés de leur exécution.	   ---
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
--- Contours forestiers de la BD Foret téléchargeable sur le site de l'IGN "r_bdtopo"."bd_foret"												  ----
--- Tables gestionnaires public.gestionnaires (voir la table d'exemple disponible Github) 														  -----
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

-----------------------------------------------------
--- Création du schéma et restart			      ---
-----------------------------------------------------

DROP SCHEMA IF EXISTS "83XXX_elec" CASCADE; 				--- Schéma de travail
CREATE SCHEMA "83XXX_elec";
COMMIT;

CREATE INDEX ON r_bdtopo.bd_foret USING GIST (geom);
COMMIT;

CREATE INDEX ON public.old200m USING GIST (geom); 
COMMIT;

DELETE FROM "AA_old50m_resultat"."83XXX_result_final_mcd" 	--- Eviter les doublons dans la table finale
WHERE id_ligne_elec IS NOT NULL; 
COMMIT;


--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--
--- I. Création d'un réseau unique de lignes éléctriques		   									   	       --- 
--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--

--*------------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------------*--
--- Le réseau éléctrique initial est constitué de trois tables de 2 sources différentes : 						   ---	
---		- Les lignes aérienne haute tension (source : BD_TOPO) : table r_bdtopo."reseau-aerien-haute-tension-ht"   ---
---		- Les lignes aérienne moyenne tension (source : ORE) : table r_bdtopo."reseau-aerien-moyenne-tension-hta"  ---
---		- Les lignes aérienne basse tension (source : ORE) : table r_bdtopo."reseau-aerien-basse-tension-bt"       ---														 
---	Cette étape a pour objectif d'harmoniser ces 3 base de données en 4 phases : 								   ---
---		1- Normaliser les géométries (Linestring2D projetées en 2154											   ---
---		2- Affecter un gestionnaire, une puissance éléctrique et une distance de débroussaillement aux tronçons    ---
---		3- Désigner les tronçons concernés par les OLD sur la commune 'XXX' 									   ---
---		4- Insérer les champs communs et les géométries dans la table "83XXX_elec"."83XXX_ligne_electrique"        ---
---			qui servira ensuite à la modélisation des OLD 														   ---
----------------------------------------------------------------------------------------------------------------------
--*------------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------------*--


--*------------------------------------------------------------------------------------------------------------*--
--- Table  "83XXX_elec"."83XXX_ligne_electrique" ---
--*------------------------------------------------------------------------------------------------------------*--


ALTER TABLE  r_bdtopo."reseau-aerien-haute-tension-ht"
ALTER COLUMN geom
TYPE geometry(Geometry, 2154)												  --- Reprojection
USING ST_Force2D(geom); 
COMMIT;

ALTER TABLE r_bdtopo."reseau-aerien-haute-tension-ht"
ALTER COLUMN geom TYPE geometry(Geometry, 2154) USING ST_SetSRID(geom, 2154); --- Reprojection
COMMIT;

ALTER TABLE r_bdtopo."reseau-aerien-basse-tension-bt"
ALTER COLUMN geom TYPE geometry(Geometry, 2154) USING ST_SetSRID(geom, 2154); --- Reprojection
COMMIT;

ALTER TABLE r_bdtopo."reseau-aerien-moyenne-tension-hta"
ALTER COLUMN geom TYPE geometry(Geometry, 2154) USING ST_SetSRID(geom, 2154); --- Reprojection
COMMIT;

ALTER TABLE r_bdtopo."reseau-aerien-basse-tension-bt"
ADD COLUMN IF NOT EXISTS id_gest INTEGER, 									  --- Ajout d'une colonne identifiant gestionnaire (ref : table public.gestionnaires)
ADD COLUMN IF NOT EXISTS id_zonage INTEGER,									  --- Ajout d'une colonne identifiant zonage OLD (ref : table public.old200m)	
ADD COLUMN IF NOT EXISTS deb_m INTEGER; 									  --- Ajout d'une colonne de distance du débroussaillement 
COMMIT;

ALTER TABLE r_bdtopo."reseau-aerien-moyenne-tension-hta"
ADD COLUMN IF NOT EXISTS id_gest INTEGER, 									  --- Ajout d'une colonne identifiant gestionnaire (ref : table public.gestionnaires)
ADD COLUMN IF NOT EXISTS id_zonage INTEGER, 								  --- Ajout d'une colonne identifiant zonage OLD (ref : table public.old200m)	
ADD COLUMN IF NOT EXISTS deb_m INTEGER; 									  --- Ajout d'une colonne de distance du débroussaillement 
COMMIT;

ALTER TABLE r_bdtopo."reseau-aerien-haute-tension-ht"
ADD COLUMN IF NOT EXISTS id_gest INTEGER, 									  --- Ajout d'une colonne identifiant gestionnaire (ref : table public.gestionnaires)
ADD COLUMN IF NOT EXISTS id_zonage INTEGER, 								  --- Ajout d'une colonne identifiant zonage OLD (ref : table public.old200m)	
ADD COLUMN IF NOT EXISTS deb_m INTEGER; 									  --- Ajout d'une colonne de distance du débroussaillement 
COMMIT;

UPDATE r_bdtopo."reseau-aerien-basse-tension-bt"
SET 
id_gest = 17, 																  --- Identifiant du gestionnaire (se référer à la table public.gestionnaires)
deb_m = 2 ; 																  --- Distance de débroussaillement en mètres sous les lignes basse tension (se référer à l'arrêté départemental)
COMMIT;

UPDATE r_bdtopo."reseau-aerien-moyenne-tension-hta"
SET 
id_gest = 17,																  --- Identifiant du gestionnaire (se référer à la table public.gestionnaires)
deb_m = 2; 																      --- Distance de débroussaillement en mètres sous les lignes basse tension (se référer à l'arrêté départemental)
COMMIT;

UPDATE r_bdtopo."reseau-aerien-haute-tension-ht"
SET 
id_gest = 16, 																  --- Identifiant du gestionnaire (se référer à la table public.gestionnaires)
deb_m = case when voltage = '400 kV' then 40 else 20 end; 					  --- Distance de débroussaillement en mètres sous les lignes basse tension (se référer à l'arrêté départemental)
COMMIT;

UPDATE r_bdtopo."reseau-aerien-basse-tension-bt" as a 
SET id_zonage = b.fid  														  --- Identifiant du zonage OLD (ref : public.old200m)
from  public.old200m  as b
where st_within(a.geom,b.geom); 											  --- Null si le tronçon n'est pas dans old200m.
COMMIT;

UPDATE r_bdtopo."reseau-aerien-moyenne-tension-hta" as a 
SET id_zonage = b.fid 														  --- Identifiant du zonage OLD (ref : public.old200m)
from public.old200m as b
where st_within(a.geom,b.geom);  											  --- Null si le tronçon n'est pas dans old200m.
COMMIT;

UPDATE r_bdtopo."reseau-aerien-haute-tension-ht" as a 
SET id_zonage = b.fid 														  --- Identifiant du zonage OLD (ref : public.old200m)
from public.old200m as b
where st_within(a.geom,b.geom);  											  --- Null si le tronçon n'est pas dans old200m.
COMMIT;

DROP TABLE IF EXISTS r_bdtopo.ligne_electrique;
CREATE TABLE  r_bdtopo.ligne_electrique(
   id_ligne_elec SERIAL, 													  --- Identifiant unique du tronçon
   id_source VARCHAR(50), 													  --- Identifiant unique du tronçon dans la base de données source (IGN ou ORE)
   voltage_kv VARCHAR, 														  --- Voltage en kv
   fonctionnement VARCHAR, 													  --- Etat de fonctionnement de la ligne (oui/non) 
   source VARCHAR(50), 														  --- Nom de la base de données source 
   deb_m INT, 																  --- Profondeur de débrousaillement (en m) à réaliser sous la ligne 
   geom GEOMETRY, 
   id_gest INT, 															  --- Identifiant du gestionnaire du tronçon (ref : public.gestionnaires)
   id_zonage INT, 															  --- Identifiant de la zone d'application des OLD (ref: public.old200m). Si null : tronçon non concerné par les OLD
   PRIMARY KEY(id_ligne_elec)
);

COMMIT;

INSERT INTO r_bdtopo.ligne_electrique( id_source,deb_m,geom,id_gest,id_zonage) 
select id, deb_m, geom, id_gest, id_zonage
from r_bdtopo."reseau-aerien-basse-tension-bt";
COMMIT;

INSERT INTO r_bdtopo.ligne_electrique( id_source,deb_m,geom,id_gest,id_zonage)
select id, deb_m, geom, id_gest, id_zonage
from r_bdtopo."reseau-aerien-moyenne-tension-hta";
COMMIT;

INSERT INTO r_bdtopo.ligne_electrique(id_source,voltage_kv,fonctionnement,deb_m,geom,id_gest,id_zonage)
select cleabs,voltage,etat_de_l_objet,deb_m,geom,id_gest,id_zonage
from r_bdtopo."reseau-aerien-haute-tension-ht";
COMMIT;

UPDATE r_bdtopo.ligne_electrique AS a
SET source = CASE WHEN voltage_kv is null then 'ore' else 'bd_topo' end; 	--- Source 
COMMIT;

CREATE INDEX ON r_bdtopo.ligne_electrique USING GIST (geom);
COMMIT;

DROP TABLE IF EXISTS "83XXX_elec"."83XXX_ligne_electrique";  				--- Selection des tronçons situés sur la commune 'XXX'
CREATE TABLE "83XXX_elec"."83XXX_ligne_electrique" as 
SELECT a.*
FROM r_bdtopo.ligne_electrique  as a, r_cadastre.geo_commune as b
where b.idu = 'XXX' and st_intersects(a.geom,b.geom); 
COMMIT; 

CREATE INDEX ON "83XXX_elec"."83XXX_ligne_electrique" USING GIST (geom);
COMMIT;


--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--
--- II. Modélisation des Obligations sous les lignes electriques									   	     --- 
--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--

--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--
--- La modélisation des OLD se déroule en 3 grandes étapes  : 									   	   ---														 
---		1- Zone tampon de x m autour des lignes electriques 												   ---
---		2- Découpage des OLD à l'intérieur du zonage OLD 						 							   ---
---		3- Intersection avec le cadastre 										 							   ---
---------------------------------------------------------------------------------------
--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--


--*------------------------------------------------------------------------------------------------------------*--
--- Table "83XXX_elec".bd_foret ---
--*------------------------------------------------------------------------------------------------------------*--
--- Découpage du masque forestier BD_foret sur l'emprise de la commune XXX ---
--*------------------------------------------------------------------------------------------------------------*--

DROP TABLE IF EXISTS "83XXX_elec".bd_foret;
CREATE TABLE "83XXX_elec".bd_foret as 
SELECT a.*
FROM r_bdtopo.bd_foret as a, r_cadastre.geo_commune as b
where b.idu = 'XXX' and st_intersects(a.geom,b.geom); 
COMMIT;

CREATE INDEX ON "83XXX_elec".bd_foret USING GIST (geom);
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--
--- Table "83XXX_elec".bd_foretrgr ---
--*------------------------------------------------------------------------------------------------------------*--
--- Aggrégation des patchs forestier BD_foret sur l'emprise des zonage informatif des OLD (ref : public.old200m) ---
--*------------------------------------------------------------------------------------------------------------*--

drop table if exists "83XXX_elec".bd_foretrgr;
create table "83XXX_elec".bd_foretrgr as 
select ST_Union(a.geom) as geom  											--- Union des géométries 		
from  "83XXX_elec".bd_foret as a, public.old200m as b
where st_intersects(a.geom,b.geom);											--- Là où la bd_foret intersecte le zonage informatif des OLD 
COMMIT;

CREATE INDEX ON "83XXX_elec".bd_foretrgr USING GIST (geom);
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--
--- Table "83XXX_elec".rte_ligne_temp0 ---
--*------------------------------------------------------------------------------------------------------------*--
--- Découpage du réseau "83XXX_elec"."83XXX_ligne_electrique" sur l'emprise des forêts situées dans 		   ---
--- un zonage OLD   																						   ---
--*------------------------------------------------------------------------------------------------------------*--

drop table if exists "83XXX_elec".rte_ligne_temp0;
create table "83XXX_elec".rte_ligne_temp0 as 
select a.id_ligne_elec, 												   --- Identifiant unique du tronçon
a.deb_m,																   --- Surface à débroussailler sous le tronçon 
st_intersection(a.geom,b.geom) as geom									   --- Intersection 
from "83XXX_elec"."83XXX_ligne_electrique"  as a, 						   --- Réseau de distribution d'éléctricité en zone OLD sur la commune 'XXX'
"83XXX_elec".bd_foretrgr as b 											   --- Masque forestier en zone OLD sur la commune 'XXX'
where st_intersects(a.geom,b.geom);
COMMIT;

CREATE INDEX ON "83XXX_elec".rte_ligne_temp0 USING GIST (geom);
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--
--- Table "83XXX_elec".rte_ligne_temp1 ---
--*------------------------------------------------------------------------------------------------------------*--
--- Zone tampon de distance "deb_m"																	 		   ---
--*------------------------------------------------------------------------------------------------------------*--

drop table if exists "83XXX_elec".rte_ligne_temp1;
create table "83XXX_elec".rte_ligne_temp1 as 
select a.id_ligne_elec as id_ligne_elec,
st_buffer(a.geom,a.deb_m) as geom										--- Zone tampon
from "83XXX_elec".rte_ligne_temp0 as a, 								--- Tronçon concernés par les OLD 
"83XXX_elec".bd_foretrgr as b											--- Forêt situées dans le zonage OLD 
where st_intersects(a.geom,b.geom);
COMMIT;

CREATE INDEX ON "83XXX_elec".rte_ligne_temp1 USING GIST (geom);
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--
--- Table "83XXX_elec".rte_ligne2_temp ---
--*------------------------------------------------------------------------------------------------------------*--
--- Affectation des informations cadastrales des propriétés qui doivent être débroussaillées par les 		   ---
--- gestionnaires des réseaux de distribution d'éléctricité. 												   ---
--*------------------------------------------------------------------------------------------------------------*--


drop table if exists "83XXX_elec".rte_ligne2_temp;
create table "83XXX_elec".rte_ligne2_temp as 
select a.id_ligne_elec as id_ligne_elec,
b.proprietaire as nom_prop, 											--- Nom du propriétaire
b.geo_parcelle,															--- N° de la parcelle à débroussailler 
b.comptecommunal as comptcom_prop,										--- Compte de propriété du propriétaire de la parcelle
b.adresse as adresse_prop, 												--- Adresse du propriétaire
st_intersection(a.geom,b.geom) as geom									--- Intersection entre la zone tampon et la table r_cadastre.parcelle_info
from "83XXX_elec".rte_ligne_temp1 as a, r_cadastre.parcelle_info as b
where st_intersects(a.geom,b.geom);
COMMIT;

CREATE INDEX ON "83XXX_elec".rte_ligne2_temp USING GIST (geom);
COMMIT;



--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--
--- III. Insertion des résultats dans la couche "AA_old50m_resultat"."83XXX_result_final_mcd"     			   --- 
--*------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------*--



INSERT INTO "AA_old50m_resultat"."83XXX_result_final_mcd"(nom_prop,comptcom_prop,geom_obligations_elec,id_ligne_elec,geo_parcel)
SELECT nom_prop,comptcom_prop,geom,id_ligne_elec,geo_parcelle
FROM "83XXX_elec".rte_ligne2_temp; 
COMMIT;

ALTER TABLE "AA_old50m_resultat"."83XXX_result_final_mcd" 
ADD COLUMN IF NOT EXISTS id_gest INT; 
COMMIT;

UPDATE "AA_old50m_resultat"."83XXX_result_final_mcd" as a 
SET id_gest = b.id_gest													--- Identifiant du gestionnaire 
FROM "83XXX_elec"."83XXX_ligne_electrique"  as b
WHERE a.id_ligne_elec = b.id_ligne_elec;								--- Jointure depuis la table "83XXX_elec"."83XXX_ligne_electrique"
COMMIT;

UPDATE "AA_old50m_resultat"."83XXX_result_final_mcd" as a 
SET obl_nom = b.nom_gest,												--- Nom du gestionnaire
obl_statut = b.statut,													--- Statut du gestionnaire (privé, départemental...)
obl_adresse = b.adresse													--- Adresse du gestionnaire
FROM public.gestionnaires as b
WHERE a.id_gest = b.id_gest;
COMMIT;

UPDATE "AA_old50m_resultat"."83XXX_result_final_mcd"
SET id_old = concat(id_gest,'elec',fid_old),							--- Identifiant unique et stable de l'OLD 
surface_m2 = st_area(geom_obligations_elec)								--- Surface à débroussailler	
WHERE id_ligne_elec IS NOT NULL;
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

DROP SCHEMA "83XXX_elec" CASCADE;
COMMIT;

