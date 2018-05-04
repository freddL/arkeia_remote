
#!/bin/bash
#
#########################################################################
##############  Pré-requis  #############################################
#########################################################################
#
# 0. Mise à part la partie 2 ( connexion ssh sans mot de passe ), les
#     pré-requis concerne le serveur distant.
#
# 1. Le fichier /opt/arkeia/arkc/arkc.param doit être configuré
#     NODE    "localhost"
#     LOGIN   "Rentrez_votre_identifiant"
#     PASSWORD  "Rentrez_votre_mot_de_passe"
#
# 2. La connexion SSH doit pouvoir se faire sans mot de passe
#     cf : ssh-copy-id
#
# 3. Il doit y avoir un et un seul savePack comportant la référence
#     "total" autrement vous devez fixer la valeur de la variable sp_name
#
# 4. Il doit également y avoir un et un seul diskstorage, autrement vous
#     devez fixer la valeur de la variable dk_name
#
#########################################################################
##############  Explications  ###########################################
#########################################################################
#
# Ce script permet de lancer la sauvegarde d'un savepack sur un serveur
#  distant, via son IP, hostame ou nom DNS.
#
# Incrémental ou total ?
#  - Sauvegarde différentiel si lancé entre Lundi et jeudi.
#  - Sinon, sauvegarde TOTAL.
#
# Politique de sauvegarde :
#
#    Deux sauvegardes totales le week-end car :
#      - Nous avons une licence de 5To pour les diskstorages, il
#         est donc interéssant de limiter l'occupation de cette
#	  espace.
#      - Lors d'une sauvegarde, Arkeia va vérifier s'il a besoin de
#         créer des données de déduplication. S'il en créer,
#         l'espace de ces données sera rajouté à l'espace occupé
#         sur le diskstorage.
#      - Si vous supprimez une sauvegarde, ces données de déduplications
#         ne sont pas supprimez.
#      - Vous pouvez alors relancer une sauvegarde qui occupera moins
#         d'espace car elle ne recréra pas les données de déduplication.
#      - Vous supprimerez donc la sauvegarde du vendredi soir, pour
#         gagner de l'espace, sans perdre de données, grace à la
#         sauvegarde du dimanche.
#
#########################################################################
##############  Utilisation #############################################
#########################################################################
#
# Utilisation du script : ./nom-du_script réference_du_serveur 
#
# exemple : ./arkeia_chainage 192.168.0.21
# exemple : ./arkeia_chainage monserveur.monDomaine
# exemple : ./arkeia_chainage monserveur
#
# Le script test si il est lancé en semaine entre 7H et 20H, si c'est le
#  cas, il ne se lance pas, cela afin de permettre de lancer un
#  sauvegarde qui aurait échoué, sans que le chainage se lance.
#
#########################################################################
#########################################################################

# Précision du "chemin" de la commande arkc 

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Creation des variables jour & heure
jour=$(date +%u)
heure=$(date +%H)

# Test sur l'horaire pour éviter un chainage lors d'un lancement manuel.
if [[ $jour -lt 5 ]] && [[ $heure -gt 7 ]] && [[ $heure -lt 20 ]]
 then
# Envoie d'un mail d'avertissement.
# adminmail=Rentrez votre mail et décommentez
# mail "Le chainage ne c'est pas lancé, merci de le lancé à la main et de résoudre le soucis, car cela ne semble pas normal." -s "Echec du chainage arkeia" $adminmail
 exit 0
fi

# Création de la variable serveur correspondant au premier argument du script.
serveur=$1

# Création des variables indispensables à la commande arkc
sp_name=$(ssh root@$serveur arkc -savepack -list  | grep total | sed 's/=/ /' | awk {'print $2'})
dk_name=$(ssh root@$serveur arkc -drivepack -list  | sed 's/=/ /' | awk {'print $2'})
pl_name=pool_diskstorage

# Test de l'existance du pool et création si besoin.
pl_test=$(ssh root@$serveur arkc -pool -list |grep pool_diskstorage | sed 's/=/ /' | awk {'print $2'})
if [[ ! $pl_test == $pl_name ]]
 then
 ssh root@$serveur arkc -pool -create -D name=$pl_name
fi

# Activer l'envoie de mail
mail_value='YES'

# Durée de rétention
ret_value=6
retunit_value=MONTH

# Sauvegarde différentiel basé sur la dernière total du même savePack, si jour de la semaine sauf vendredi
if [ $jour -lt 5 ]
 then
 backup_type=INCREMENTAL
 ssh root@$serveur arkc -backup -start -D skname=$sp_name plname=$pl_name dkname=$dk_name email=$mail_value retention=$ret_value retunit=$retunit_value type=$backup_type based_on_tag=$sp_name -moreinfo

# Sauvegarde total, si jour = vendredi ou week-end.
elif [[ $jour -gt 4 ]]
 then
 backup_type=TOTAL
 ssh root@$serveur arkc -backup -start -D skname=$sp_name plname=$pl_name dkname=$dk_name email=$mail_value retention=$ret_value retunit=$retunit_value type=$backup_type -moreinfo
## Enregistrer l'ID de la total
else
 exit 1

fi
exit 0

## En cours : ##
## Récupérer l'id de la dernière total pour pouvoir faire des différentiel ( = incrémental basé sur la dernière total )
