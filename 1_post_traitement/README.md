## 🔥🔥🔥 Utilisation des outils de post-traitement OLD50m proposés par le CRIGE PACA 🔥🔥🔥

## Structure du projet

Le traitement repose sur 4 scripts complémentaires à exécuter dans l'ordre suivant :

| Ordre | Fichier                       | Rôle                                                     |
--------------------------------|--------------------------------|----------------------------------------------------------|
1 | script_wold50m2mcd.sql | Ajout des informations majic aux résultats de l'outil OLD50m. Utiliser script_wold50m2mcd.py pour automatiser sur plusieurs communes
2 | script_adresse.sql | Ajouter l'adresse de l'obligé   |
3 | script_GL.sql    | Modélisation des OLD générées par les infrastructures éléctriques et les voies férrées           |
4 | script_routes.sql |  Modélisation des OLD générées par les voies ouvertes à la circulation   |
__|gestionnaire_gl.csv        | Fichier-type listant les gestionnaires de grands linéaires mis à disposition par le CRIGE PACA. Peut être utilisé pour le montage de la base de données                   |
     
---

## Environnement requis

- PostgreSQL 16 ou version ultérieure  
- PostGIS 3.5.3  
- GEOS 3.13.1  
- QGIS 3.34 ou supérieur (extension Cadastre recommandée)

Les scripts doivent être exécutés avec un utilisateur disposant des droits de création de schémas et d’exécution de blocs PL/pgSQL.

---

## Données nécessaires

## Données généralistes

| Source  | Nom par défaut    | Schéma d'import | Nom d'import | Définition | Géométrie | 
| :---------: |:---------:| :----------:| :--------------------:| :---------:| :---------:|
| [Debroussaillement](https://geoservices.ign.fr/telechargement-api/DEBROUSSAILLEMENT?format=GPKG)  | Debroussaillement         | public | old200m | Zones soumises aux OLD(généralement 200 m autour des massifs forestiers). | Polygone
| [Cadastre](https://www.crige-paca.org/)  | parcelle          | r_cadastre  | parcelles_info | Parcelles cadastrales issu du plugin cadastre de Qgis. (⚠️ réservé aux ayant droit) | Polygone 
| [BD_TOPO (format .gpkg)](https://geoservices.ign.fr/telechargement-api/BDTOPO?format=GPKG) | commune          |  r_bdtopo  |  commune | Table des communes permettant de stocker certaines particularités (extension de la profondeur des débroussaillement, dérrogations, niveaux de risques fixé par l'arrêté ...). | Polygone
| [BD_Foret (format .gpkg)](https://geoservices.ign.fr/telechargement-api/BDFORET) | FORMATION_VEGETALE          |  r_bdtopo  |  bd_foret | Contours forestiers | Polygone


### 🚗 ROUTES

| Source  | Nom par défaut    | Schéma d'import  | Nom d'import | Définition | Géométrie |
| :---------: |:---------:| :----------:| :--------------------:| :---------:| :---------:|
| [BD_TOPO (format .gpkg)](https://geoservices.ign.fr/telechargement-api/BDTOPO?format=GPKG)  | troncon_de_route  |   r_bdtopo  |    troncon_de_routes | Tronçon de routes référencés dans la BD_TOPO. | Ligne


### 🚆⚡ GRANDS LINEAIRES

| Source  | Nom par défaut          | Schéma d'import  | Nom d'import | Définition | Géométrie |
| :---------: | :---------: |:---------:| :----------:| :--------------------:| :---------:|
| [BD_TOPO (format .gpkg)](https://geoservices.ign.fr/telechargement-api/BDTOPO?format=GPKG)  | troncon_de_voie_ferre  | r_bdtopo     |    troncon_de_voie_ferre | Tronçon de voies férrées référencés dans la BD_TOPO. | Ligne 
| [BD_TOPO (format .gpkg)](https://geoservices.ign.fr/telechargement-api/BDTOPO?format=GPKG) | ligne_electrique       | r_bdtopo  |    reseau-aerien-haute-tension-ht | Lignes éléctriques aériennes haute tension (50 kV et plus) | Ligne
| [ORE](https://portail.agenceore.fr/pages/explore?explorepath=datasets%2Freseau-aerien-basse-tension-bt&stage_theme=true&disjunctive.nom_grd&disjunctive.region&disjunctive.departement&disjunctive.epci) | reseau-aerien-basse-tension-bt | r_bdtopo         |    reseau-aerien-basse-tension-bt | Lignes éléctriques aériennes basse tension (entre 230 et 380 V) | Ligne
| [ORE](https://portail.agenceore.fr/pages/explore?explorepath=datasets%2Freseau-aerien-moyenne-tension-hta&stage_theme=true&disjunctive.nom_grd&disjunctive.epci&disjunctive.departement&disjunctive.region&disjunctive.commune) | reseau-aerien-moyenne-tension-hta   | r_bdtopo       |    reseau-aerien-moyenne-tension-hta | Lignes éléctriques aériennes moyenne tension (entre 1 kV et 50 kV) | Ligne

### ADRESSES


| Source  | Nom par défaut          | Schéma d'import  | Nom d'import | Définition | Géométrie |
| :---------: | :---------: |:---------:| :----------:| :--------------------:| :---------:|
| [BAN_PLUS](https://geoservices.ign.fr/ban-plus#telechargement)  | Adresse  | r_bdtopo     |    adresse | Points d'adresse contenant le numéro, l'indice de répétition, le nom de la voie... | Point
| [BAN_PLUS](https://geoservices.ign.fr/ban-plus#telechargement) | Lien adresse-parcelle        | r_bdtopo  |   lien_adresse-parcelle | Couche permettant de relier le point d'adresse à la parcelle adréssée | Ligne

Toutes les couches doivent être en système de coordonnées Lambert-93 (EPSG:2154).



