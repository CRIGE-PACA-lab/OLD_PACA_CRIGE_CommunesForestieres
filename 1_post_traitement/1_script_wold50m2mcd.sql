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
----   Remplacer "26XXX" par le code INSEE de la commune                                                      ----
----   Remplacer "XXX" par les 3 derniers chiffres de ce code INSEE         								  ----
---    Remplacer "AA" par le code INSEE du département      	              ----
------------------------------------------------------------------------------------------------------------------

-----------------------------------
--- Création des index en amont ---
-----------------------------------

CREATE INDEX 
ON  r_cadastre.parcelle_info
USING gist (geom); 
COMMIT;

CREATE INDEX 
ON  r_cadastre.geo_commune
USING gist (geom); 
COMMIT;

---------------------------------------------------------------
--- Création d'une table vide conforme au standard régional ---
---------------------------------------------------------------

Drop table if exists "AA_old50m_resultat"."26xxx_result_final_mcd";
CREATE TABLE  "AA_old50m_resultat"."26xxx_result_final_mcd"(
   id_obligation SERIAL,  --- identifiant de la zone à débroussailler (en série)
   geom GEOMETRY,  --- géométrie
   situation VARCHAR(250), --- situation géographique au regard du document d'urbanisme
   comptcom_prop VARCHAR(250), --- compte communal du propriétaire de la parcelle à débroussailler
   nom_prop TEXT, --- nom du propriétaire de la parcelle à débroussailler
   adresse_prop TEXT, --- adresse de la parcelle à débroussailler
   obl_comptcom VARCHAR(250), --- compte communal de l'obligé
   obl_nom TEXT, --- nom de l'obligé 
   obl_id_adresse TEXT, --- identifiant de l'adresse de l'obligé (se reporter à la table "adresse" du MCD pour obtenir l'adresse complète)
   obl_statut VARCHAR(250), --- statut juridique de l'obligé 
   surface_m2 FLOAT, --- surface à débroussailer en m²
   geo_parcelle VARCHAR(250), --- n° de la parcelle à débroussailler
   ID_bati INT, --- identifiant de la construction à l'origine du débroussaillement
   PRIMARY KEY(id_obligation)
);
COMMIT;

-----------------------------------------------------------------------------------------------------------------------------------------------------
--- Intersection des résultats de l'outil OLD_50m avec le cadastre pour remonter les informations du propriétaire de la parcelle à débroussailler ---
--- Création d'une table temporaire 																											  ---
-----------------------------------------------------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS  "AA_old50m_resultat"."26xxx_result_final_temp"; --- table temporaire
CREATE TABLE  "AA_old50m_resultat"."26xxx_result_final_temp" AS
select a.comptecommunal as obl_comptcom,  --- compte communal de l'obligé
b.comptecommunal as comptcom_prop, --- compte communal du propriétaire de la parcelle à débroussailler
b.proprietaire as nom_prop, --- nom du propriétaire de la parcelle à débroussailler
b.geo_parcelle, --- parcelle à débroussailler
  ST_Multi(                             -- Convertit en MultiPolygon
           ST_CollectionExtract(             -- Extrait uniquement les polygones (type 3)
               ST_MakeValid(                 -- Corrige les géométries invalides
                   ST_intersection(a.geom,b.geom)),      -- intersecte les géométries 
       3)) AS geom                           -- Géométrie finale 
from  "AA_old50m_resultat"."26xxx_result_final" as a join r_cadastre.parcelle_info as b --- sources : résultats de OLD50m ; cadastre
on st_intersects(a.geom, b.geom)
where b.codecommune = 'XXX';
COMMIT;

CREATE INDEX 
ON  "AA_old50m_resultat"."26xxx_result_final_temp"
USING gist (geom); 
COMMIT;

----------------------------------------------------------------------
--- Remontée des informations cadastrales du débroussailleur       ---
--- Jointure des tables "cadastre" et "bati" à la table temporaire ---
----------------------------------------------------------------------

ALTER TABLE  "AA_old50m_resultat"."26xxx_result_final_temp"
ADD COLUMN obl_nom TEXT, --- nom de l'obligé 
ADD COLUMN id_bati INT,  --- identifiant de la construction à l'origine du débroussaillement
ADD COLUMN obl_id_adresse VARCHAR;  --- identifiant de l'adresse de l'obligé 

UPDATE  "AA_old50m_resultat"."26xxx_result_final_temp" as a
SET obl_nom = b.proprietaire --- nom de l'obligé 
from r_cadastre.parcelle_info as b --- source : cadastre
where a.obl_comptcom = b.comptecommunal;  


----------------------------------------------------------------------------------------------------------
--- Insertion de la table temporaire dans la table finale conforme au format du standard régional PACA ---
----------------------------------------------------------------------------------------------------------

insert into "AA_old50m_resultat"."26xxx_result_final_mcd"(geom,comptcom_prop,nom_prop,obl_comptcom,obl_nom,obl_id_adresse,geo_parcelle,id_bati)
select geom,comptcom_prop,nom_prop,obl_comptcom,obl_nom,obl_id_adresse,geo_parcelle,id_bati
from  "AA_old50m_resultat"."26xxx_result_final_temp";
COMMIT;

-----------------------------------------------------------------------------
--- Définition de la situation de l'OLD au regard du document d'urbanisme ---
--- Facultatif si la commune n'est pas couverte par un PLU 				  ---
-----------------------------------------------------------------------------

Update "AA_old50m_resultat"."26xxx_result_final_mcd" as a
set situation = case 
when st_within(a.geom,b.geom) then 'dans la zone U'
when st_disjoint(a.geom,b.geom) then 'en dehors de la zone U'
else 'chevauchant une zone U' end 
from  "AA_old50m_resultat"."AA_zonage_global" as b; --- source : zonage du PLU
COMMIT;

--------------------------------------------------------
--- Calcul de la surface des zones à débroussailler  ---
--------------------------------------------------------

Update "AA_old50m_resultat"."26xxx_result_final_mcd" as a
set surface_m2 = case when a.geom is not null then st_area(a.geom)
else st_area(a.geom)
end ; 
COMMIT;

------------------------------------------------------------
--- Statut juridique de l'obligé 						 ---
--- Reclassification adaptables aux spécificités locales ---
------------------------------------------------------------

UPDATE "AA_old50m_resultat"."26xxx_result_final_mcd"
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

---------------------------------------------------------------------
--- Suppression de la table intermédiaire et des géométries vides ---
---------------------------------------------------------------------

DELETE FROM "AA_old50m_resultat"."26xxx_result_final_mcd"
WHERE ST_IsEmpty(geom) or surface_m2 = 0; 
COMMIT;

DROP TABLE IF EXISTS  "AA_old50m_resultat"."26xxx_result_final_temp";
COMMIT;



