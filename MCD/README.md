## 🔥🔥🔥 Modèle Conceptuel de Données pour les Obligations Légales de débroussaillement 🔥🔥🔥

Les Obligations légales de débroussaillement (OLD) constituent l'un des principaux outils de la prévention du risque de feu de forêt. 
Elles consistent à réduire la biomasse présente sur un terrain pour diminuer le risque de propagation des incendies et l'exposition des biens et des personnes. Elles concernent les propriétaires de constructions et les gestionnaires de réseaux dont les équipements sont situés à moins de 200 m d'un massif forestier déterminé par arrêté préfectoral.   

Dans le contexte actuel d'intensification des feux et de la propagation du risque vers des régions moins exposées et avec l’adoption de la loi de Juillet 2023 sur la défense des forêts contre les incendies, les collectivités expriment le besoin de se saisir des OLD à l'aide d'une information géographique fiable, précise et harmonisée.   

**Objectifs**

* Proposer un socle de données minimal pour traiter de la question des OLD 
* Développer des outils permettant d'harmoniser les données produites dans le cadre de l'identification des obligations (MCD). 
* Suivre l’état d’embroussaillement et les travaux engagés sur les propriétés concernées.

**Prérequis**

* QGIS avec l'extension Cadastre
* PostgreSQL avec l'extension PostGIS 

⚠️ Le montage de la base de données et son fonctionnement sont conditionnés par l'utilisation des données listées dans [import2postgres.md](https://github.com/CRIGE-PACA-lab/OLD_crige/blob/main/readme.md)

**Structure**

Les outils mis à disposition dans ce dépôt permettent de monter un schéma PostgreSQL-PostGIS référençant les enjeux (constructions, infrastructures et réseaux) concernés par les OLD 
 
* 📂 MCD 
	* [MCD_OLD.sql : Modèle conceptuel de données (MCD) utilisables pour le montage d'une base de données OLD](https://github.com/CRIGE-PACA-lab/OLD_PACA_CRIGE_CommunesForestieres/blob/main/MCD/MCD_OLD.sql)
	* [MCD_OLD.pdf : Visualisation graphique du MCD](https://github.com/CRIGE-PACA-lab/OLD_PACA_CRIGE_CommunesForestieres/blob/main/MCD/MCD_OLD.pdf)
	* [script_wold50m2mcd.sql : Conversion des couches "result_3" ou "result_4" en sortie de l'outil OLD50m (développé par la DDT26) au format du MCD](https://github.com/CRIGE-PACA-lab/OLD_PACA_CRIGE_CommunesForestieres/blob/main/MCD/script_wold50m2mcd.sql)
	* script_wold50m2mcd.py : Adaptation les tables produites par l'outil OLD50m au format établi par le modèle de données. Groupe de communes.

**A voir également :**

* [Outil OLD_50 m de cartographie et de gestion des superpositions, DDT26](https://gitlab-forge.din.developpement-durable.gouv.fr/pub/dd/ddt-26-public/old50m)
* [Déploiement de l'outil sur le département des Alpes de Haute-Provence](https://lizmap.crige-paca.org/index.php/view/map?repository=projetold&project=old_04) 
* [LOI n° 2023-580 du 10 juillet 2023 visant à renforcer la prévention et la lutte contre l'intensification et l'extension du risque incendie](https://www.legifrance.gouv.fr/jorf/id/JORFTEXT000047805414)
* [Les OLD sur le site du CRIGE PACA](https://www.crige-paca.org/projet/obligations-legales-de-debroussaillement/#presentation)
* [La prévention du risque incendie sur l'Observatoire de la forêt Méditerranéenne](https://www.ofme.org/textes.php3?IDRub=18&IDS=84)




![crige_cofor](https://www.crige-paca.org/wp-content/uploads/2025/02/logo_crige_cofor.png)

