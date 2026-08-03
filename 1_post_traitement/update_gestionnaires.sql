--*-----------------------------------------------------------------------------------------------------------------*---
--*-----------------------------------------------------------------------------------------------------------------*---
-------------------------------------  udpate_gestionnaires.sql  -------------------------------------------------------
--*-----------------------------------------------------------------------------------------------------------------*---
--*-----------------------------------------------------------------------------------------------------------------*---
--- Ce script permet de mettre à jour la table public.gestionnaire à l'aide des informations contenues 			     ---
--- dans la BD TOPO             																				     ---
--- La table public.gestionnaires recense l'ensemble des gestionnaires de réseaux 								     ---
--- (routiers, éléctriques, férroviaires...) sur un territoire. 												     ---
--- Un gabarit de la table public.gestionnaires est disponible ici : 												 ---
--- https://github.com/CRIGE-PACA-lab/OLD_PACA_CRIGE_CommunesForestieres/blob/main/1_post_traitement/gestionnaires.gpkg	---					
--*------------------------------------------------------------------------------------------------------------------*--
--- Pour les OLD d'une département donné, lancez ce script une fois. Relancez-le lorsque vous changez de département ---
--*-----------------------------------------------------------------------------------------------------------------*---
--- Auteurs : CRIGE PACA, Communes forestières PACA                                              			         ---                    
--*-----------------------------------------------------------------------------------------------------------------*---
--*-----------------------------------------------------------------------------------------------------------------*---


--*------------------------------------------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------------------------------------------*--
----------------------------------------- Données nécéssaires ----------------------------------------------------------------------------------------
--- Tronçons de routes de la BD TOPO renommé r_bdtopo.troncon_de_route																			  ----											  ----
--*------------------------------------------------------------------------------------------------------------------------------------------------*--
--*------------------------------------------------------------------------------------------------------------------------------------------------*--

-----------------------------------------------------------------------------------------------------
--- NB : Les noms et statuts des gestionnaires peuvent être changés et adaptés aux beosins locaux ---
--- Les gestionnaires des réseaux electriques et ferroviaires doivent être saisis manuellement.   ---
-----------------------------------------------------------------------------------------------------


--*------------------------------------------------------------------------------------------------------------*--
--- Table r_bdtopo.gest_temp ---
--*------------------------------------------------------------------------------------------------------------*--
--- Table temporaire ne contenant que les noms des gestionnaires de réseaux routiers						   ---
--*------------------------------------------------------------------------------------------------------------*--

drop table if exists r_bdtopo.gest_temp;
create table r_bdtopo.gest_temp as 
select 
cpx_gestionnaire
FROM r_bdtopo.troncon_de_route
group by cpx_gestionnaire ;
COMMIT;

ALTER TABLE r_bdtopo.gest_temp
ADD COLUMN IF NOT EXISTS id SERIAL,
ADD COLUMN IF NOT EXISTS id_gest INTEGER;
COMMIT; 

UPDATE r_bdtopo.gest_temp
SET id_gest = id; 
COMMIT;

UPDATE r_bdtopo.gest_temp							--- On reclasse les identifiants ci-dessous, déjà affectés aux gestionnaires des réseaux forroviaires et electriques: 
SET id_gest = case 										--- Par défaut :
				when id_gest = 15 then 151					--- 15 : Identifiant SNCF réseau  					
				when id_gest = 16 then 161 					--- 16 : Identifiant RTE
				when id_gest = 17 then 171 					--- 17 : Identifiant Enedis 
				when id_gest = 18 then 181 					--- 18 : Identifiant Région
				else id_gest 						--- Les autres gardent les identifiants distribués par la séquence.
				end ; 								--- Si besoin : ajouter ou supprimer des reclassements
COMMIT;

--*------------------------------------------------------------------------------------------------------------*--
--- Table public.gestionnaires ---
--*------------------------------------------------------------------------------------------------------------*--
--- Table temporaire ne contenant que les noms des gestionnaires de réseaux routiers						   ---
--*------------------------------------------------------------------------------------------------------------*--

insert into public.gestionnaires(id_gest,nom_gest) 									--- Insertion des noms des gestionnaires de réseaux routiers dans public.gestionnaires
select id_gest,cpx_gestionnaire
from r_bdtopo.gest_temp;
COMMIT;

update public.gestionnaires    												--- Mise à jour du statut des gestionnaires
set statut = case 															--- Exemple ci-contre pour la région PACA. A adapater au département
				when   nom_gest like '%Alpes-de-Haute-Provence%'  			
					or nom_gest like '%Alpes-Maritimes%' 
	 				or nom_gest like '%Bouches-du-Rhône%' 
					or nom_gest like  '%DFCI%' 
					or nom_gest like  '%Gard%'
	  				or nom_gest like '%Conseil Départemental des AHP%' 
	   				or nom_gest like '%Drôme%'  
	    			or nom_gest like '%Hautes-Alpes%' 
		   			or nom_gest like '%Vaucluse%' 
		    		or nom_gest like '%Var%' 
					then 'departement'
				when nom_gest =  'DIR Méditerranée' then  'DIR Méditerranée' 
				when nom_gest = 'Métropole Nice Côte d''Azur' then 'Intercommunal'
				when nom_gest = 'Priv' 
					or nom_gest = 'ESCOTA' 
					or nom_gest = 'GPMM'
					or nom_gest = 'ASF' 
					then 'privé'
				when nom_gest = 'NR' then null 
				else 'commune' 
				end ;
COMMIT;