#!/bin/ksh


# On identifie le dernier fichier log MEVA pour extraire son heure de debut et fin:
rep_log_MEVA=${REPAPPLI}/logs/
echo "$rep_log_MEVA"

# On se positionne dans le repertoire de logs:
cd $(echo "$rep_log_MEVA" | tr -d '\r')

# On extrait le nom du dernier fichier log généré par la MEDIAVALO:

log_MEVA=$(ls -tr log_MEVA_VE_* | sed '$!d')

echo "Fichier Log mediavalo: $log_MEVA"


NomFichierCLIP=PROXIMA_20190420_00098.CLIP

fichier_err_enrich=($(ls "$REPDATA/files/AMONT/ERREUR/RET_$NomFichierCLIP"*))

# On extrait la date de debut et de fin de la log:

cut_date_debut_mediav=$(head -n 1 "$log_MEVA" | cut -c 5-15 | tr -cd [:digit:] )
cut_heures_debut_mediav=$(head -n 1 "$log_MEVA" | cut -c 16-24 | tr -cd [:digit:] )
cut_annee_debut_mediav=$(echo $cut_date_debut_mediav | cut -c 5-8)
cut_mois_debut_mediav=$(echo $cut_date_debut_mediav | cut -c 3-4)
cut_jour_debut_mediav=$(echo $cut_date_debut_mediav | cut -c 1-2)
cut_date_heures_debut_mediav=$cut_annee_debut_mediav$cut_mois_debut_mediav$cut_jour_debut_mediav$cut_heures_debut_mediav
##########################################################
cut_date_fin_mediav=$(tail -n 1 "$log_MEVA" | cut -c 5-15 | tr -cd [:digit:] )
cut_heures_fin_mediav=$(tail -n 1 "$log_MEVA" | cut -c 16-24 | tr -cd [:digit:] )
cut_annee_fin_mediav=$(echo $cut_date_fin_mediav | cut -c 5-8)
cut_mois_fin_mediav=$(echo $cut_date_fin_mediav | cut -c 3-4)
cut_jour_fin_mediav=$(echo $cut_date_fin_mediav | cut -c 1-2)
cut_date_heures_fin_mediav=$cut_annee_fin_mediav$cut_mois_fin_mediav$cut_jour_fin_mediav$cut_heures_fin_mediav


#cut_date=$(echo "${log_MEVA: -14}")

cut_date=$(echo "${fichier_err_enrich: -14}")

echo "Dernier fichier log MEDIAVALO: $log_MEVA"
echo "cut_date_debut_mediav: $cut_date_debut_mediav"
echo "cut_heures_debut_mediav: $cut_heures_debut_mediav"
echo "cut_date_heures_debut_mediav: $cut_date_heures_debut_mediav"
echo "cut_date_heures_fin_mediav: $cut_date_heures_fin_mediav"
echo "cut_date: $cut_date"


if [ $cut_date -ge $cut_date_heures_debut_mediav ] && [ $cut_date -le $cut_date_heures_fin_mediav ]; then

echo "Date de tri du fichier d enrichissement ($cut_date) est bien comprise entre date_debut MEDIAVALO ($cut_date_heures_debut_mediav) et date_fin MEDIAVALO ($cut_date_heures_fin_mediav)"
fi

exit 0
