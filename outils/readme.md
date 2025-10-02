# Couches à importer sur Postgres avant l'éxécution des scripts

⚠️ **Avant de lancer les scripts, il est nécéssaire de pousser les données suivantes sur une base Postgres.** ⚠️

## 🏢 BATI 

| Source  | Nom par défaut          | Nom d'import | Définition | Géométrie |
| :---------: |:---------:| :----------:| :--------------------:| :---------:|
| BDNB |   rel_batiment_groupe_bdtopo_bat | bdnb — rel_batiment_groupe_bdtopo_bat | Table pivôt entre les bâtiments de la BD_TOPO et la BDNB. | Non
| BDNB  | rel_batiment_groupe_parcelle  |   bdnb — rel_batiment_groupe_parcelle | Table contenant les n° de parcelle des bâtiments de la BDNB. | Non
| BDNB  | rel_batiment_groupe_adresse          |    bdnb — rel_batiment_groupe_adresse | Table pivôt entre les bâtiments de la BDNB et les adresses. | Non
| BDNB  | adresse_compile          |    bdnb — adresse_compile | Adresses des bâtiments remontées à la BDNB. | Point
| RNB  | RNB        |    RNB | Référentiel National des bâtiments. | Non
| BANPLUS  | lien_bati-parcelle          |    lien_bati-parcelle | Table pivôt entre les bâtiments de la BD_TOPO et les n° de parcelle. | Ligne
| BANPLUS | lien_adresse-bati          |    lien_adresse-bati | Table pivôt entre les bâtiments de la BD_TOPO et leur adresse à la BAN. | Ligne
| BANPLUS | adresse       |    adresse_ban | Adresses remontées à la BAN. | Point
| BD_TOPO | commune          |    commune | Table des communes permettant de stocker certaines particularités (extension de la profondeur des débroussaillement, dérrogations, niveaux de risques fixé par l'arrêté ...). | Polygone
| BD_TOPO  | batiment         |    batiments | Bâtiments référencés dans la BD_TOPO. | Polygone
| BD_TOPO  | batiment_rnb_lien_bdt          |    batiment_rnb_lien_bdt |Table pivôt entre les bâtiments de la BD_TOPO et les adresses du RNB. | Point
| GPU  |           |   zoneu |  Zones classées U dans les documents d'urbanisme. | Polygone
| Cadastre  | parcelle          |    parcelles_vf | Parcelles cadastrales issu du plugin cadastre de Qgis. | Polygone 


## 🚗 ROUTES

| Source  | Nom par défaut          | Nom d'import | Définition | Géométrie |
| :---------: |:---------:| :----------:| :--------------------:| :---------:|
| BD_TOPO  | troncon_de_route      |    routes_vf | Tronçon de routes référencés dans la BD_TOPO. | Ligne
| BD_TOPO | commune          |    commune | Table des communes permettant de stocker certaines particularités (extension de la profondeur des débroussaillement, dérrogations, niveaux de risques fixé par l'arrêté ...). | Polygone
| Debroussaillement  | Debroussaillement_light          |  deb_ign | Zones soumises aux OLD(généralement 200 m autour des massifs forestiers). | Polygone
| Cadastre  | parcelle          |    parcelles_vf | Parcelles cadastrales issu du plugin cadastre de Qgis. | Polygone


## 🚆⚡ GRANDS LINEAIRES

| Source  | Nom par défaut          | Nom d'import | Définition | Géométrie |
| :---------: |:---------:| :----------:| :--------------------:| :---------:|
| BD_TOPO  | roncon_de_voie_ferre      |    vf_temp | Tronçon de voies férrées référencés dans la BD_TOPO. | Ligne 
| BD_TOPO | commune          |    commune | Table des communes permettant de stocker certaines particularités (extension de la profondeur des débroussaillement, dérrogations, niveaux de risques fixé par l'arrêté ...). | Polygone
| ORE | reseau-aerien-haute-tension-ht          |    reseau-aerien-haute-tension-ht | Lignes éléctriques aériennes haute tension (50 kV et plus) | Ligne
| ORE | reseau-aerien-basse-tension-bt          |    reseau-aerien-basse-tension-bt | Lignes éléctriques aériennes basse tension (entre 230 et 380 V) | Ligne
| ORE | reseau-aerien-moyenne-tension-hta          |    reseau-aerien-moyenne-tension-hta | Lignes éléctriques aériennes moyenne tension (entre 1 kV et 50 kV) | Ligne
| Debroussaillement  | Debroussaillement_light          |  deb_ign | Zones soumises aux OLD(généralement 200 m autour des massifs forestiers). | Polygone
| Cadastre  | parcelle          |    parcelles_vf | Parcelles cadastrales issu du plugin cadastre de Qgis. | Polygone 

## 🌲 Forêt

| Source  | Nom par défaut          | Nom d'import | Définition | Géométrie |
| :---------: |:---------:| :----------:| :--------------------:| :---------:|
| Debroussaillement  | Debroussaillement_light          |  deb_ign | Zones soumises aux OLD(généralement 200 m autour des massifs forestiers). | Polygone
| BD_Forêt V3 | masque foret2.gpkg          |  bd_foret_fr | Masque forestier produit par l'IGN | Polygone