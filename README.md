## 🔥🔥🔥 Modélisation des Obligations Légales de débroussaillement 🔥🔥🔥

Les Obligations légales de débroussaillement (OLD) constituent l'un des principaux outils de la prévention du risque de feu de forêt. 
Elles consistent à réduire la biomasse présente sur un terrain pour diminuer le risque de propagation des incendies et l'exposition des biens et des personnes. Elles concernent les propriétaires de constructions et les gestionnaires de réseaux dont les équipements sont situés à moins de 200 m d'un massif forestier déterminé par arrêté préfectoral.   

Dans le contexte actuel d'intensification des feux et de la propagation du risque vers des régions moins exposées et avec l’adoption de la loi de Juillet 2023 sur la défense des forêts contre les incendies, les collectivités expriment le besoin de se saisir des OLD à l'aide d'une information géographique fiable, précise et harmonisée.   

**Objectifs**

* Proposer un socle de données minimal pour traiter de la question des OLD 
* Développer des outils permettant d'harmoniser les données produites dans le cadre de l'identification des obligations. 
* Suivre l’état d’embroussaillement et les travaux engagés sur les propriétés concernées.
* Faire connaître les outils permettant de cartographier les OLD. 

**Données requises**

- [BD_TOPO](https://geoservices.ign.fr/bdtopo#telechargementgpkgdep) (format .gpkg) avec les couches 
	- batiments 
	- batiment_rnb_lien_bdtopo
	- troncon_de_route
	- troncon_de_voie_ferre  
- [Base Nationale des Batiments (BDNB)](https://bdnb.io/download/) (format .gpkg) avec les couches 
	- bdnb — rel_batiment_groupe_bdtopo_bat
	- bdnb — rel_batiment_groupe_parcelle
	- bdnb — rel_batiment_groupe_adresse
	- bdnb — adresse_compile
- [Référentiel National des bâtiments (RNB)](https://www.data.gouv.fr/fr/organizations/referentiel-national-des-batiments/#/datasets)
- [BAN PLUS](https://geoservices.ign.fr/ban-plus) avec les couches
	- adresse
	- lien_bati-parcelle
	- lien_adresse-bati
- [Fichiers fonciers MAJIC](https://www.crige-paca.org/services/extractions/) (⚠️ réservé aux ayant droit)
- [Zonage OLD](https://geoservices.ign.fr/debroussaillement)
- [Documents d'urbanisme](https://www.geoportail-urbanisme.gouv.fr/map/#tile=1&lon=2.424722&lat=46.76305599999998&zoom=6)
	- Zones U 
- Infrastructures du réseau de transport d'éléctricté 
	- [Lignes électriques aériennes Basse Tension (BT)](https://opendata.agenceore.fr/explore/dataset/reseau-aerien-basse-tension-bt/information/?stage_theme=true&disjunctive.nom_grd&disjunctive.region&disjunctive.departement&disjunctive.epci)
	- [Lignes électriques aériennes moyenne tension (HTA)](https://opendata.agenceore.fr/explore/dataset/reseau-aerien-moyenne-tension-hta/information/?stage_theme=true&disjunctive.nom_grd&disjunctive.epci&disjunctive.departement&disjunctive.region&disjunctive.commune)
	- [Lignes électriques aériennes Haute Tension (HTB)](https://opendata.agenceore.fr/explore/dataset/reseau-aerien-haute-tension-htb/information/?stage_theme=true&disjunctive.nom_grd&disjunctive.departement&disjunctive.epci)
- Masque forestier [BD_foret V3](https://data.geopf.fr/telechargement/download/BDFORET/MASQUEFORET__BETA_GPKG_LAMB93_FXX_2024-01-01/MASQUEFORET__BETA_GPKG_LAMB93_FXX_2024-01-01.7z) (format.gpkg)

**Prérequis**

* QGIS avec l'extension Cadastre
* PostgrSQL avec l'extension PostGIS 

⚠️ Avant de lancer les scripts, veuillez vous référer au document [import2postgres.md](https://github.com/CRIGE-PACA-lab/OLD_crige/blob/main/import_postgres.md)

**Structure**

Les outils mis à disposition dans ce dépôt permettent de monter un schéma PostgreSQL-PostGIS référençant les enjeux (constructions, infrastructures et réseaux) concernés par les OLD. 
La procédure est divisée en 3 scripts qui peuvent être mobilisés séparément : 
* 📂 MCD 
	* MCD_OLD.sql : Modèle conceptuel de données (MCD) utilisables pour le montage d'une base de données OLD 
	* MCD_OLD.pdf : Visualisation graphique du MCD
* 📂 Scripts 
	* 🏢 _script_bati.sql_ : OLD générées par la présence de bâtiments (bâtiments, campings, parcs photovoltaïques...).
	* 🚗 _script_GL.sql_ : OLD générées par la présence d'infrastructures férroviaires ou du de transport d'éléctricité.
	* 🚆⚡ _script_routes.sql_ : OLD générées par la présence d'infrastructures liées au réseau routier.

Ces trois scripts permettent d'identifier les responsables de l'éxécution des OLD et les propriétés sur lesquelles ces dernières doivent être réalisées.
Ces outils ne permettent pas d'identifier un responsable de l'éxécution des OLD dans le cas où plusieurs responsables potentiels seraient identifiés pour un même terrain. 

Les résultats n'ont aucune valeur juridique ou contractuelle et ne sauraient se passer d'analyses terrain plus approfondies. 


**A voir également :**

* [Outil OLD_50 m de cartographie et de gestion des superpositions](https://gitlab-forge.din.developpement-durable.gouv.fr/frederic.sarret/old_50m)
* [Déploiement de l'outil sur le département des Alpes de Haute-Provence](https://lizmap.crige-paca.org/index.php/view/map?repository=projetold&project=old_04) 
* [LOI n° 2023-580 du 10 juillet 2023 visant à renforcer la prévention et la lutte contre l'intensification et l'extension du risque incendie](https://www.legifrance.gouv.fr/jorf/id/JORFTEXT000047805414)
* [Les OLD sur le site du CRIGE PACA](https://www.crige-paca.org/projet/obligations-legales-de-debroussaillement/#presentation)
* [La prévention du risque incendie sur l'Observatoire de la forêt Méditerranéenne](https://www.ofme.org/textes.php3?IDRub=18&IDS=84)



![crige_cofor](https://www.crige-paca.org/wp-content/uploads/2025/02/logo_crige_cofor.png)