--------------------------------------------------------------------------------------------------------------------------------------------------------------------
---- OBLIGATIONS LEGALES DE DEBROUSSAILLEMENT 																													----
---- MODELE CONCEPTUEL DE DONNEES (MCD) 																														----
--------------------------------------------------------------------------------------------------------------------------------------------------------------------
---- Auteurs : CRIGE PACA / Communes forestières PACA 																											----
--------------------------------------------------------------------------------------------------------------------------------------------------------------------
---- Ce MCD est développé dans le cadre du groupe de travail régional sur les OLD annimé par le CRIGE PACA et l'Union Régionale des Communes forestières 		----
---- Il a pour objectif d'aider à l'organisation et à l'harmonisation des données après modélisation des OLD 											 		----
---- Plusieurs outils de modélisation des OLD sont mis à disposition notamment : 																				----
----		- OLD50m (DDT 26) :  https://gitlab-forge.din.developpement-durable.gouv.fr/frederic.sarret/old_50m/-/tree/11098699e7c629ca33a306314e20a1b9c42bd728 ----
----		- Les Communes forestières : https://github.com/CRIGE-PACA-lab/OLD_PACA_CRIGE_CommunesForestieres/outils											----
---- Visualisez graphiquement le MCD avec "MCD_OLD.png" 																								    	----
--------------------------------------------------------------------------------------------------------------------------------------------------------------------

--------------------------
--- Création du schéma ---
--------------------------

DROP SCHEMA IF EXISTS old_dep;
CREATE SCHEMA old_dep;

----------------------
--- Table Adresses ---
----------------------
------------------------------------------------------------------------------
--- L'adresse et/ou la parcelle de situation peut être connue          -------
--- pour la majorité des bâtiments référencés dans la BD_TOPO (80% sur -------
--- le département des Alpes de Haute-Provence). Pour cela il faut     -------
--- préalablement agrégger les données des référentiels nationaux : BDNB, ----
--- RNB et BANPLUS. Ces aggrégations au niveau du bâtiments permettront ------
--- ensuite de constituer la table "adresse" 							------
--- Voir "script-bati.sql".												------
------------------------------------------------------------------------------

CREATE TABLE old_dep.adresse(
   ID_adresse SERIAL, --- Identifiant unique de l'adresse 
   num_rue VARCHAR(50), --- N° de l'adresse dans la rue
   rep VARCHAR(50), --- Indice de répétition qui complète une numérotation de voirie ex: bis, ter...) .
   nom_rue VARCHAR(50), --- Nom complet de la voie 
   cp VARCHAR(50), --- Code postal
   ville VARCHAR(50), --- Nom de la commune 
   lieu_dit TEXT, -- Lieu-dit éventuel de l’adresse
   source_adr VARCHAR(50), --- Nom de la base de données source (BAN / BDNB / RNB / cadastre)
   PRIMARY KEY(ID_adresse) --- Clé primaire
);


-----------------------
--- Table cadastre ----
-----------------------
--------------------------------------------------------------------------------------
--- Importer la couche "parcelle_info" générée sous Qgis avec le plugin Cadastre -----
--------------------------------------------------------------------------------------

CREATE TABLE old_dep.cadastre(
   geo_parcel VARCHAR(50),  --- Identifiant unique de la parcelle ("Code INSEE" + "000" + "section" + "numparcel")
   nom_commune VARCHAR(50),  --- Nom de la commune 
   adresse VARCHAR(50), --- extraction de l'adresse de la personne (morale ou physique) propriétaire de la parcelle (champ propriétaire_info)
   compt_com VARCHAR(50), --- compte de propriété du propriétaire de la parcelle. Une personne peut avoir plusieurs compte communaux si elle partage des propriétés avec d'autres personnes ou sur plusieurs communes.
   proprietaire TEXT, --- Nom du propriétaire
   proprietaire_info TEXT, --- Nom, date de naissance et adresse du propriétaire 
   geom GEOMETRY, --- polygone
   PRIMARY KEY(geo_parcel)
);

--------------------------
--- Table zonage OLD ----
--------------------------
------------------------------------------------------------------
--- Importer la couche "débroussaillement" publiée par l'IGN -----
------------------------------------------------------------------

CREATE TABLE old_dep.zonage_old(
   id_zonage SERIAL,  --- identifiant unique de la zone old.
   geom GEOMETRY, --- polygone 
   source VARCHAR(50), --- IGN 
   PRIMARY KEY(id_zonage)
);

-----------------------------
--- Table "doc_urbanisme" ----
-----------------------------
-----------------------------------------------------------------------
--- Importer la couche "zonage_urba" du géoportail de l'urbanisme -----
-----------------------------------------------------------------------

CREATE TABLE old_dep.plu(
   id_zone SERIAL, --- Identifiant unique de la zone du document d'urbanisme 
   type_zone VARCHAR(50), --- zone U 
   geom GEOMETRY, --- polygone
   PRIMARY KEY(id_zone)
);

-----------------------------
--- Table "ajout_bati" ----
-----------------------------
--------------------------------------------------------------------------------------------------------------------------
--- table de contribution permettanr la remontée par les utilisateur de constructions non référencées dans la BDTOPO -----
--------------------------------------------------------------------------------------------------------------------------

CREATE TABLE old_dep.ajout_bati(
   Id_ajout_bati SERIAL, --- Identifiant unique du bâtiment ajouté
   nature VARCHAR(50), --- Nature du bâtiment
   geo_parcel VARCHAR(50), --- Identifiant unique de la parcelle
   date_ajout DATE, --- Date d'ajout du bâtiment
   utilisateur VARCHAR(50), --- Identifiant de l'utilisateur
   adresse_mail VARCHAR(50), --- Adresse mail de l'utilisateur
   geom GEOMETRY, --- polygone
   PRIMARY KEY(Id_ajout_bati)
);

-----------------------------
--- Table "gestionnaire" ----
-----------------------------
----------------------------------------------------
--- table listant les gestionnaire de voiries  -----
----------------------------------------------------

CREATE TABLE old_dep.gestionnaire(
   id_gest SERIAL, --- Identifiant unique du gestionnaire 
   nom_gest VARCHAR(50), --- Nom du gestionnaire 
   statut VARCHAR(50), --- Statut du gestionnaire (Particulier / Entreprise / Etat / Département / Commune / Intercommunalité) 
   adresse VARCHAR(50), --- Adresse du gestionnaire 
   PRIMARY KEY(id_gest)
);

-----------------------------
--- Table "point_de_repere" ----
-----------------------------
---------------------------------------------
--- table des points de repère routiers -----
---------------------------------------------


CREATE TABLE old_dep.Point_de_repère(
   id_pt SERIAL, --- Identifiant unique du point
   geom GEOMETRY, --- Points 
   PRIMARY KEY(id_pt)
);

---------------------------------------------
--- Table "gestionnaire_grand_lineaires" ----
---------------------------------------------
-------------------------------------------------------------------------------------------------------
--- table listant les gestionnaire de grand linéaires (ferroviaire ou distribution d'éléctricité) -----
-------------------------------------------------------------------------------------------------------

CREATE TABLE old_dep.gestionnaire_grand_lineaires(
   id_gest SERIAL, --- Identifiant unique du gestionnaire 
   nom_gest VARCHAR(50), --- Nom du gestionnaire 
   statut VARCHAR(50),  --- Statut du gestionnaire (Entreprise / Etat / Département / Commune / Intercommunalité...) 
   adresse TEXT, --- Adresse du gestionnaire 
   PRIMARY KEY(id_gest)
);

----------------------------------
--- Table "ligne_electrique" ----
---------------------------------


CREATE TABLE old_dep.ligne_electrique(
   id_ligne_elec SERIAL, --- Identifiant unique de la ligne
   id_source VARCHAR(50), --- Identifiant unique de la ligne dans la bd source
   voltage_kv INT, --- Puissance transportée par la ligne en KV. Cete puissance détermine la profondeur de débroussaillement. 
   fonctionnement LOGICAL, --- Etat de fonctionnement de la ligne (arrêté ou en fonctionnement)
   source VARCHAR(50), --- Nom de la base de données source
   deb_m VARCHAR(50), --- Profondeur de débroussaillement en mètres
   geom GEOMETRY, --- Ligne
   id_zonage INT, --- Identifiant unique de la zone de débroussaillement 
   id_gest INT, --- Identifiant unique du gestionnaire
   PRIMARY KEY(id_ligne_elec)
);

---------------------
--- Table "bati" ----
---------------------
-------------------------------------
--- Batiments issus de la BD Topo ---
-------------------------------------

CREATE TABLE old_dep.Bati(
   ID_bati SERIAL, --- Identifiant unique du batiment
   id_bdtopo VARCHAR(50), --- Identifiant unique du batiment dans la BD topo
   nature VARCHAR(50), --- Nature du bâtiment
   geom GEOMETRY, --- Polygone
   id_zonage INT, --- Identifiant unique de la zone de débroussaillement 
   PRIMARY KEY(ID_bati)
);

---------------------------------
--- Table "obligations_bati" ----
---------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- Zone à débroussailler générées par les bâtiments dont la responsabilité échoie à 'obl_comptcom' sur la parcelle n° 'geo_parcel' appartenant à 'nom_prop' -----
------------------------------------------------------------------------------------------------------------------------------------------------------------------

CREATE TABLE old_dep.obligations_bati(
   id_obligation SERIAL, --- Identifiant unique de la zone à débroussailer (obligation)
   geom GEOMETRY, --- Polygone 
   situation VARCHAR(50), --- Situation de l'obligation au regarde de la reglementation spécifique liée aux zones U du PLU.
   comptcom_prop VARCHAR(50), --- Compte de propriété du propriétaire de la parcelle
   nom_prop VARCHAR(50), --- Nom de la personne (morale ou physique) chez qui l'obligation doit être exécutée.
   adresse_prop VARCHAR(50), --- concaténation de l'adresse de la personne (morale ou physique) chez qui l'obligation doit être exécutée.
   obl_comptcom VARCHAR(50), --- Compte de propriété de l'obligé
   obl_nom VARCHAR(50), --- Nom de l'obligé 
   obl_adresse VARCHAR(50), --- concaténation de l'adresse de la personne (morale ou physique) responsable de l'exécution de l'obligation.
   obl_statut VARCHAR(50), --- statut de la personne (morale ou physique) responsable de l'exécution de l'obligation (Particulier ; entreprise ; Etat ; commune ; interco ; département ; région....)
   surface_m2 DOUBLE, --- surface (en m2) à débroussailler
   id_zone INT, --- Identifiant de la zone U (facultatif)
   geo_parcel VARCHAR(50), --- Identifiant unique de la parcelle à débroussailler
   ID_bati INT, --- Identifiant unique du batiment
   ID_adresse INT, --- Identifiant unique de l'adresse 
   PRIMARY KEY(id_obligation)
);

---------------------
--- Table "routes" ----
---------------------
---------------------------------------------------------------------------
--- Tronçons de routes issus de la couche "troncon_route" de la BD Topo ---
---------------------------------------------------------------------------

CREATE TABLE old_dep.routes(
   id_troncon SERIAL, --- Identifiant unique du tronçon
   id_bdtopo VARCHAR(50), --- Identifiant unique du tronçon contenu dans la BD topo
   nature VARCHAR(50), --- Attribut permettant de classer un tronçon de route ou de chemin suivant ses caractéristiques physiques (" Bretelle | Chemin | Piste cyclable | Rond-point | Route à 1 chaussée | Route à 2 chaussées | Route empierrée)
   importance VARCHAR(50), --- L’attribut 'Importance' matérialise une hiérarchisation du réseau routier, non pas sur un critère administratif, mais sur l'importance des tronçons de route pour le trafic routier.
   acces_vehicule_leger VARCHAR(50), ---  L'attribut 'Accès véhicule léger' précise les conditions d'accès des véhicules légers sur chaque tronçon.
   nom_voie TEXT, --- nom de la voie (facultatif)
   cpx_numero VARCHAR(50), --- Numéro(s) de(s) (la) route(s) à laquelle (auxquelles) appartient ce tronçon
   cpx_classement_adminsitratif VARCHAR(50), --- "Classement administratif du tronçon issu du champ 'Type de route' de l'objet complexe Route numérotée ou nommée lié au tronçon"
   cpx_gestionnaire VARCHAR(50), --- Gestionnaire du tronçon issu du champ 'Gestionnaire' de l'objet Route numérotée ou nommée lié au tronçon
   larg_m INT, --- Largeur de la chaussée en mètre
   deb_m INT, --- Largeur de débroussaillement en mètre à partir des bordures exterieures de la voirie (deb_m + larg_m)
   source VARCHAR(50), --- Nom de la base de donnée mère du tronçon
   geom GEOMETRY, --- Ligne 
   id_gest INT, --- Identifiant du gestionnaie du tronçon 
   id_zonage INT, --- Identifiant unique de la zone de débroussaillement 
   PRIMARY KEY(id_troncon)
);

-----------------------------------
--- Table "obligations_routes" ----
-----------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- Zone à débroussailler générées par les routes dont la responsabilité échoie à 'id_gest' du 'id_troncon' sur la parcelle n° 'geo_parcel' appartenant à 'nom_prop' -----
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------

CREATE TABLE old_dep.obligations_routes(
   id_obligation SERIAL, --- Identifiant unique de l'obligation
   geom GEOMETRY, --- Polygone
   nom_prop VARCHAR(50), --- Nom de la personne (morale ou physique) chez qui l'obligation doit être exécutée.
   adresse_prop VARCHAR(50), --- concaténation de l'adresse de la personne (morale ou physique) chez qui l'obligation doit être exécutée.
   surface_m2 DOUBLE, --- surface (en m2) à débroussailler
   id_troncon INT, --- Identifiant unique du tronçon
   geo_parcel VARCHAR(50), --- Identifiant unique de la parcelle
   PRIMARY KEY(id_obligation)
);

-----------------------------
--- Table "voies_ferees" ----
-----------------------------
---------------------------------------------------------------------------
--- Tronçons de routes issus de la couche "voies_ferres" de la BD Topo ---
---------------------------------------------------------------------------

CREATE TABLE old_dep.voies_ferees(
   id_vf SERIAL, --- Identifiant unique du tronçon
   id_bdtopo VARCHAR(50), --- Identifiant unique du tronççon contenu dans la BD topo
   largeur VARCHAR(50), --- "Voie étroite : largeur < 1,435 m.
						--- Voie large : largeur > 1,435 m.
						--- Voie normale :  largeur = 1,435 m."
   nb_voies INT, --- Nombre de voies modélisées par le tronçon de voie ferrée.
   larg_m DECIMAL(15,2), --- Largeur de la voie en valeur numérique
   deb_m VARCHAR(50), --- Largeur de débroussaillement à partir des bordures exterieures de la voie : (larg_m * nb_voies) + 7
   source VARCHAR(50), --- Nom de la base de donnée mère du tronçon
   geom GEOMETRY, --- Ligne
   id_gest INT, --- Identifiant unique du gestionnaire
   id_zonage INT, --- Identifiant unique de la zone de débroussaillement 
   PRIMARY KEY(id_vf)
);

-------------------------------
--- Table "obligations_gl" ----
-------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- Zone à débroussailler générées par les routes dont la responsabilité échoie à 'id_gest' du 'id_ligne_elec' ou 'id_vf' sur la parcelle n° 'geo_parcel' appartenant à 'nom_prop' -----
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

CREATE TABLE old_dep.obligations_gl(
   id_obligation SERIAL, --- Identifiant unique de l'obligation
   nom_prop VARCHAR(50), --- Nom de la personne (morale ou physique) chez qui l'obligation doit être exécutée.
   comptcom_prop VARCHAR(50), --- Compte de propriété du propriétaire de la parcelle
   surface_m2 DOUBLE, --- surface (en m2) à débroussailler
   geom GEOMETRY, --- Polygone
   id_vf INT, --- Identifiant unique du tronçon de voie férrée
   geo_parcel VARCHAR(50), --- Identifiant unique de la parcelle à débroussailler
   id_ligne_elec INT, --- Identifiant unique du tronçon de la ligne électrique
   PRIMARY KEY(id_obligation)
);

-------------------------------
--- Table "controle" ----------
-------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------
--- Table de contribution mise à disposition des contrôleur OLD. Modifiable et aggrémentable selon les spécificités des  arrêtés départementaux -----
-----------------------------------------------------------------------------------------------------------------------------------------------------

CREATE TABLE old_dep.controle(
   Id_controle SERIAL, --- Identifiant unique de la fiche contrôle
   date_ DATE, --- Date du dernier contrôle
   description TEXT, --- Commentaire (libre) du contrôleur 
   doc1 VARCHAR(255), --- document joint au contrôle (facultatif)
   doc2 VARCHAR(255), --- document joint au contrôle (facultatif)
   photo1 VARCHAR(255), --- image jointe au contrôle (facultatif)
   photo2 VARCHAR(255), --- image jointe au contrôle (facultatif)
   photo3 VARCHAR(255), --- image jointe au contrôle (facultatif)
   photo4 VARCHAR(255), --- image jointe au contrôle (facultatif)
   nom VARCHAR(255), --- nom du contrôleur 
   prenom VARCHAR(255), --- prénom du contrôleur 
   organisme VARCHAR(255), --- organisme du contrôleur 
   mail VARCHAR(255), --- adresse mail du contrôleur 
   id_obligation INT, --- Identifiant unique de l'obligation (bati)
   id_obligation_1 INT, --- Identifiant unique de l'obligation (routes)
   id_obligation_2 INT, --- Identifiant unique de l'obligation (grands linéaires)
   PRIMARY KEY(Id_controle)
);

--------------------------------------
--- Table "lien_poi_routes" ----------
--------------------------------------
-------------------------------------------------------------------------------------------------
--- Table de relations entre les routes et les points d'intérêts routiers des gestionnaires -----
-------------------------------------------------------------------------------------------------

CREATE TABLE old_dep.lien_poi_routes(
   id_troncon INT, --- Identifiant unique du tronçon de route
   id_pt INT, --- Identifiant unique du point de repère
   PRIMARY KEY(id_troncon, id_pt)
);

--------------------------------------
--- Table "gestionnaire_prive" -------
--------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- Table de relations entre la table des gestionnaires de réseaux routiers et le cadastre permettant la remontée des informations des propriétaires privés de voiries -----
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

CREATE TABLE old_dep.gestionnaire_prive(
   geo_parcel VARCHAR(50), --- Identifiant unique de la parcelle
   id_gest SERIAL, --- Identifiant unique du gestionnaire. Serial nécéssaire pour la création de nouveaux gestionnaires. 
   PRIMARY KEY(geo_parcel, id_gest)
);
