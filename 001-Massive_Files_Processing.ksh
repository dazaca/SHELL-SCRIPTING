#!/bin/ksh
#==============================================================================
# DEBUT EN-TETE ComptageCLIP.ksh
#==============================================================================
# Revision: 00_00#1
#==============================================================================
# Description :
#
#  Des la reception d un fichier massive (10^6 lignes) appele CLIP sur $REPDATA/input/CLIP/ENTREE,
#  ce script affiche le nombre de lignes et le montant total du fichier avant
#  tout operation dans l application en faisant un traitement de la copie de 
#  celui-ci sur $REPADATA/output/CPTCLIP/TRAVAIL. Ce montant total correspondrait  
#  a la somme des montants de chaque ligne constituant ce fichier.
#    
#  Grace a SQL*Loader, une deuxieme partie recupere le fichier CLIP en entree et 
#  bascule toute ses lignes vers une table temporaire en incorporant une colonne 
#  formatee de chaque ligne (remplacement des points virgules par des espaces 
#  blancs), ajout une colonne avec le numero de ligne et cree une colonne pour 
#  chaque ligne formatee avec une signature issue a partir de la fonction Oracle MD5.
#
#    Parametres :
#    $0   Nom du shell
#    $1   Nom du fichier CLIP
#
#==============================================================================
# FIN EN-TETE ComptageCLIP.ksh
#==============================================================================
# set -x


#------------------------ 1-Chargement Fonction RecupVal ------------------------------

. "${REPAPPLI}"/etc/OCB_FonctionsCommunes.cfg
if [ $(typeset +f | grep -c RecupVal2) -eq 0 ]; then
   echo "KO Fonction RecupVal non definie. Charger le proitco"
   exit 1
fi


#------------------------ 2-Lecture du fichier de parametrage -------------------------

RecupVal2 REPSHELL                        "${APPLI_FICPARAM}"
RecupVal2 REPEXE                          "${APPLI_FICPARAM}"
RecupVal2 REPFICTMP                       "${APPLI_FICPARAM}"
RecupVal2 FCHLOG                          "${APPLI_FICPARAM}"
RecupVal2 ORACLE_SID                      "${APPLI_FICPARAM}"
RecupVal2 DATA_OUT_CPTCLIP_SORTIE         "${APPLI_FICPARAM}"
RecupVal2 DATA_OUT_CPTCLIP_TRAVAIL        "${APPLI_FICPARAM}"
RecupVal2 REPLOGS                         "${APPLI_FICPARAM}" REPLOG
RecupVal2 ORACLE_SID                      "${APPLI_FICPARAM}"
RecupVal2 ORACLE_PROPUSER                 "${APPLI_FICPARAM}"
RecupVal2 ORACLE_PWDFILE 	                "${APPLI_FICPARAM}"


#------------------------ 3-Initialisation des parametres -----------------------------

#Repertoire reception fichier CLIP.
DirFileCLIP=$DATA_OUT_CPTCLIP_TRAVAIL
#Nom du script shell.
NOMTSK=$(basename "$0")
CODEXE=$(date +'%Y%m%d%H%M%S')
CODEXE2=$(date +'%d/%m/%Y')

NomFichierCLIP="$(basename $1)"

# Fichier CLIP
FileClip=${DirFileCLIP}/${NomFichierCLIP} 
# Fichier flag
FICFLAG="${DirFileCLIP}/traitement_CptCLIP.fic"
> "${FICFLAG}"
chmod 775 "$FICFLAG"
# Fichier comptage CLIP
FileComptageCLIP="${DirFileCLIP}/Comptage_clip_${NomFichierCLIP}_INIT"
#Repertoire + nom du fichier fichier_controle_clip.fic utilise pour la bascule en table de l´info du fichier CLIP avec SQL*Loader.
FileControlCLIPsql="${DirFileCLIP}/Fichier_controle_clip_sql_loader${NomFichierCLIP}.fic"
#Repertoire + nom du fichier utilise pour garder les montants extraits du fichier CLIP.
FileCoupMontant="${DirFileCLIP}/Fichier_coup_montant_clip_${NomFichierCLIP}.fic"
#Repertoire + nom du fichier log genere apres le traitement SQL*Loader de charge de donnees du fichier CLIP dans la table CPT_CLIP_FICHIER.
FICHIER_LOG_SQL=${REPAPPLI}"/logs/log_SQL_loader_CLIP_${CODEXE}.log"
# Fichier log
LOG=$REPLOG/log_CptCLIP_Init_${NomFichierCLIP}_${CODEXE}.log

NombreLignes=0
NombreLignesComptage=0
NombreLignesCorrectes=0
Montant=0
Count=0
RealCount=0
RealCountFormat=0
Facteur=1000
CountMauvaises=0
LIGNE_COUNT=0  

#Variables entieres pour la fonction "is_numeric".
typeset -i LIGNE_COUNT
typeset -i TMP_IS_NUMERIC

#Variables access BDD
ORACLE_PWD="$(RecupPassword "${ORACLE_PROPUSER}" "${ORACLE_PWDFILE}")"
VerifieExistenceVariable "ORACLE_PWD" "${ORACLE_PWD}"

#------------------------ 4-Generation fichier .PAR temporaire ------------------------

FICPARAM_TEMP=${REPFICTMP}/temp.par.$$
JOURNAL="${REPEXE}/journal ${FICPARAM_TEMP} ${NOMTSK}"
Erreur=$(GenererFichierParamTemp "${APPLI_FICPARAM}" "${FICPARAM_TEMP}" X \
         "${CODEXE}" "${LOG}")
if [ "${Erreur}" = "KO" ]; then
   exit 1
fi

#------------------------ 5-Chargement des fonctions ----------------------------------

#-------------------------------------------------------------------------------
# is_numeric()
# DESCRIPTION   : Identifie si la chaine passee comme parametre est 
#                 de type numerique ou pas.
#-------------------------------------------------------------------------------

function is_numeric {
    typeset TMP_STR="$1"
 
    if [[ "$TMP_STR" == +([[:digit:]])?(.*([[:digit:]])) ]]; then
        TMP_IS_NUMERIC=1
    else
        ${JOURNAL} ${LINENO} S0999 1 \
         "ligne '$LIGNE_COUNT':"

        ${JOURNAL} ${LINENO} S0999 1 \
         "'$TMP_STR' -> montant incorrect."

        TMP_IS_NUMERIC=0
        CountMauvaises=$((CountMauvaises+1))
    fi
}

#-------------------------------------------------------------------------------
# InsertFileText()
# DESCRIPTION   : Insere le contenu d un fichier dans la log du programme.
#-------------------------------------------------------------------------------

function InsertFileText
{
  typeset TMP_STR="$1"

  while IFS= read -r line
        do
          ${JOURNAL} ${LINENO} S0999 1 "$line"
          if [ $? -ne 0 ]; then
          # Controle des iterations.
          ${JOURNAL} ${LINENO} S0999 1 " "
          ${JOURNAL} ${LINENO} S0999 1 " "
          ${JOURNAL} ${LINENO} S0998 1 \
              "Probleme lors de l insertion du rapport SQL*Loader associe a la bascule d info CLIP vers la table."
          ${JOURNAL} ${LINENO} S0998 1 \
              "Arret a la ligne $LIGNE_COUNT."
              exit 1 
          fi 
          # Fin du controle des iterations.
        done <"$TMP_STR"

}

#-------------------------------------------------------------------------------
# CreateTableFichierCLIP()
# DESCRIPTION   : Remplissage de la table temporaire du fichier CLIP.
#                 Cette fonction cree un fichier de control qui contient les
#                 instructions pour utiliser SQL*Loader (bascule de l´info du
#                 fichier CLIP vers la table temporaire CPT_CLIP_FICHIER)
#
#-------------------------------------------------------------------------------

CreateTableFichierCLIP()
{
  
	${JOURNAL} ${LINENO} S0999 1 \
	      "Debut traitement de creation et remplissage de la table temporaire du fichier CLIP."
	${JOURNAL} ${LINENO} S0999 1 ""
	
	${JOURNAL} ${LINENO} S0999 1 \
	        "Debut truncate table CLIP."
	${JOURNAL} ${LINENO} S0999 1 ""
    sqlplus -s "${ORACLE_PROPUSER}"/"${ORACLE_PWD}" <<EOF          
          WHENEVER SQLERROR EXIT FAILURE ROLLBACK;
          set echo off
          set feedback off
          set heading off
          set pagesize 0
          set linesize 2000
          set tab off
          set serveroutput on
           
          begin
    
            -- Avant la bascule de la information du fichier CLIP vers
            -- la table a l aide de SQL*Loader, on elimine toute l information de celle-ci.

            execute immediate 'TRUNCATE table CPT_CLIP_FICHIER';
 
            commit;

            EXCEPTION
            WHEN OTHERS THEN
              DBMS_OUTPUT.PUT_LINE('Exception:'||SQLERRM(SQLCODE));
            RAISE;
          end;
                    
        /
        exit 0;
EOF
    
   if [ $? -ne 0 ];then
      ${JOURNAL} ${LINENO} S0998 1 \
         "Fin KO traitements CLIP: erreur technique lors du de la table CLIP: impossible vider la table CLIP."
      ${JOURNAL} ${LINENO} S0999 1 "################################################################################################"
      rm -f "${FICPARAM_TEMP}"
   exit 1
   fi
   
   ${JOURNAL} ${LINENO} S0999 1 \
         "Generation du fichier de controle "FichierControle.fic" pour le declenchement de SQL*Loader."
   ${JOURNAL} ${LINENO} S0999 1 ""

# Debut insertion fichier avec SQL*Loader. On exclude les lignes qui commencent par 'L' et on mettra a NULL les lignes identifiees comme incorrectes.
# Les lignes avec un montant vide ne sont pas inserees par defaut en BDD par SQL*Loader. Pour cela, on la ligne qui evalue le montant entre les positions  


echo "LOAD DATA CHARACTERSET WE8MSWIN1252 INFILE '$FileClip' REPLACE PRESERVE BLANKS INTO TABLE CPT_CLIP_FICHIER
  WHEN (01) <> 'L'(
      LIGNE_CLIP POSITION(1:952) CHAR, NLF SEQUENCE(1,1),
          MONTANT POSITION(202:213) CHAR \" DECODE(LENGTH(TRIM(TRANSLATE(NULLIF(TO_CHAR(TRIM(:MONTANT)), ' '), '0123456789', ' '))),NULL,TO_NUMBER(NULLIF(TO_CHAR(TRIM(:MONTANT)), ' ')),NULL)\",
              LIGNE_CLIP_FORMATEE CHAR \"REPLACE(:LIGNE_CLIP, ';', ' ')\",
                  MD5_CLIP CHAR \" dbms_obfuscation_toolkit.md5(
                        input => UTL_RAW.cast_to_raw(
                                SUBSTR(REPLACE(:LIGNE_CLIP, ';', ' '), 0,952)
                                      )
                                          )\"
                                            )" > "${FileControlCLIPsql}"


# Fin insertion fichier----------------------

   if [ $? -ne 0 ];then
      ${JOURNAL} ${LINENO} S0998 1 \
         "Fin KO traitements CLIP: erreur technique lors de la generation du fichier de controle "FichierControle.fic" pour le declenchement de SQL*Loader."
      ${JOURNAL} ${LINENO} S0999 1 "################################################################################################"
      rm -f "${FICPARAM_TEMP}"
      exit 1
   else
      
      ${JOURNAL} $LINENO S0999 1 "Generation correcte du fichier de controle "FichierControle.fic"."
      ${JOURNAL} ${LINENO} S0999 1 ""
      ${JOURNAL} $LINENO S0999 1 "Debut de l insertion dans la table CPT_CLIP_FICHIER."
	  ${JOURNAL} ${LINENO} S0999 1 \
      "Debut formatage des lignes fichier CLIP plus generation de la colonne montant et MD5 des lignes formatees."
      ${JOURNAL} ${LINENO} S0999 1 "------------------------------------------------------------------------"
      ${JOURNAL} ${LINENO} S0999 1 "------------------------------------------------------------------------"
      ${JOURNAL} ${LINENO} S0999 1 ""
      ${JOURNAL} ${LINENO} S0999 1 ""

      # Insertion en BDD s il n y a pas eu des problemes
      # SQL*Loader (sqlldr) parametres:

      sqlldr userid="${ORACLE_PROPUSER}"/"${ORACLE_PWD}" control="${FileControlCLIPsql}" silent="(feedback, header)" log="${FICHIER_LOG_SQL}" bindsize="900000000" readsize="900000000"

      # Recuperation des erreurs de retour de SQL*Loader:
      
	  result=$?
    
      # Identification des lignes recuperees par le WHEN de SQL*Loader (2 lignes incorrectes identifiees uniquement representent le cas
      # nominal: la ligne de debut et fin, qui vont etre prises en compte et n ont pas de montants entre les positions 202 et 214).
      # La sortie de result a la valeur 2 indique un code SQL*Loader de type EX_WARN provoque lors de l identification du champ montant
      # dans la premiere et derniere ligne.

      rejected_lines_sqlldr=$(grep "Rows not loaded because all WHEN clauses were failed." ${FICHIER_LOG_SQL} | cut -c 3-4)

      if [ "$rejected_lines_sqlldr" -eq 2 ] && [ "$result" -eq 2 ];then
       result=0
      fi
       
      # Integration du rapport genere par SQL*Loader dans la log du script.
      
      InsertFileText "$FileControlCLIPsql"
      InsertFileText "$FICHIER_LOG_SQL"

      # Fin de l integration du rapport genere par SQL*Loader dans la log du script.
         
      # Variable "result" a zero si SQL*Loader execute sans erreurs

      if [ $result -ne 0 ]; then      

        ${JOURNAL} ${LINENO} S0998 1 \
          "Fin KO traitements CLIP: erreur technique lors du remplissage de la table temporaire du fichier CLIP."
        ${JOURNAL} ${LINENO} S0999 1 "################################################################################################"

        rm -f "${FICPARAM_TEMP}"
        exit 1
      fi
      
    ${JOURNAL} ${LINENO} S0999 1 ""
    ${JOURNAL} ${LINENO} S0999 1 ""
    ${JOURNAL} ${LINENO} S0999 1 "------------------------------------------------------------------------"
    ${JOURNAL} ${LINENO} S0999 1 "------------------------------------------------------------------------"
    ${JOURNAL} ${LINENO} S0999 1 "Succes lors du remplissage de la table temporaire du fichier CLIP."
    ${JOURNAL} ${LINENO} S0999 1 "" 

    rm -f "${FileControlCLIPsql}"
    rm -f "${FICHIER_LOG_SQL}"

   fi

   ${JOURNAL} ${LINENO} S0999 1 ""
   
   ${JOURNAL} ${LINENO} S0999 1 "Succes lors de la creation + remplissage de la table temporaire du fichier CLIP."
   ${JOURNAL} ${LINENO} S0999 1 ""
}


#------------------------ 6-Analyse du nombre de parametres ---------------------------
if [ $# -ne 1 ]; then
  ${JOURNAL} ${LINENO} S0998 1 "${NOMTSK} : Nombre de parametres incorrect."
  rm -f "${FICPARAM_TEMP}"
  exit 1
fi

#------------------------ 7-Recuperation du fichier CLIP ------------------------------
if [ ! -f "$1" ]; then
  ${JOURNAL} ${LINENO} S0998 1 "Le fichier $1 n'existe pas."
  rm -f "${FICPARAM_TEMP}"
  exit 1
fi

cp "$1" "$FileClip" 2> /dev/null

if [[ $? -ne 0 ]]
then
	${JOURNAL} ${LINENO} S0998 1 "ERREUR : Probleme lors de la copie du fichier $1 dans le repertoire ${DirFileCLIP}"   
	exit 1   
else
   ${JOURNAL} ${LINENO} S0999 1 "Fichier deplace vers ${DirFileCLIP}"   
   # changement des droits
   chmod 775 "$FileClip"

   if [[ $? -ne 0 ]]
   then
		${JOURNAL} ${LINENO} S0998 1 "ERREUR : Probleme lors du changement des droits (775) du fichier ${File}"    
		exit 1
   else
	   ${JOURNAL} ${LINENO} S0999 1 "Changement des droits (775) du fichier OK."     
   fi    
fi

if [ $? -ne 0 ]; then
	${JOURNAL} ${LINENO} S0998 1 "ERREUR : Probleme de recuperation de fichier CLIP"   
	exit 1 
fi

${JOURNAL} ${LINENO} S0999 1 "Debut Script comptage fichier CLIP:" 
${JOURNAL} ${LINENO} S0999 1 " " 
${JOURNAL} ${LINENO} S0999 1 " " 
${JOURNAL} ${LINENO} S0999 1 " " 
${JOURNAL} ${LINENO} S0999 1 "Lecture correcte du fichier ${FileClip}"  
${JOURNAL} ${LINENO} S0999 1 " " 


#--------------------------------- 8-MAIN-----------------------------------------------

# Appel aux fonctions:

CreateTableFichierCLIP

NombreLignes=$(($(wc -l <"$FileClip")))
NombreLignesComptage=$((NombreLignes-2))
# On transforme la chaine numerique de type "123456789,123" a "123 456 789,123"
NombreLignesComptage=$(echo "$NombreLignesComptage" | sed ':a;s/\B[0-9]\{3\}\>/ &/;ta')

# Debut insertion log -------------------------  
${JOURNAL} ${LINENO} S0999 1 \
"Nombre lignes = $NombreLignesComptage"
${JOURNAL} ${LINENO} S0999 1 " "
${JOURNAL} ${LINENO} S0999 1 " "
${JOURNAL} ${LINENO} S0999 1 \
"Debut de la recherche de lignes en erreur..."
${JOURNAL} ${LINENO} S0999 1 " "
# Fin insertion log ----------------------------

# Debut insertion fichier-----------------------
echo " " > "${FileComptageCLIP}"
echo "*************************************************" >> "${FileComptageCLIP}"
echo "******** COMPTAGE CLIP EN RECEPTION" >> "${FileComptageCLIP}"
echo "*************************************************" >> "${FileComptageCLIP}"
echo "Date: $CODEXE2" >> "${FileComptageCLIP}"
echo "Fichier CLIP : $NomFichierCLIP" >> "${FileComptageCLIP}"
echo "Nombre lignes : $NombreLignesComptage" >> "${FileComptageCLIP}"
# Fin insertion fichier-----------------------

 

# Traitement du fichier CLIP pour decouper la colonne des montants et les enregistrer au
# prealable dans un fichier pour faire la somme apres avec les montants identifies comme 
# numeriques:

awk '{print substr($0,202,12)}' < "$FileClip" > "$FileCoupMontant" 

if [ $? -ne 0 ]; then
  # Controle du decoupage du montant dans les colonnes du fichier CLIP.
  ${JOURNAL} ${LINENO} S0999 1 " "
  ${JOURNAL} ${LINENO} S0999 1 " "
  ${JOURNAL} ${LINENO} S0998 1 \
      "Fin KO du traitement du comptage CLIP: erreur lors de la recuperation des colonnes du montant dans le fichier CLIP."
  ${JOURNAL} ${LINENO} S0998 1 \
      rm -f "${FileCoupMontant}"
      rm -f "${FICPARAM_TEMP}"
      exit 1 
fi 
# Fin Controle du decoupage du montant dans les colonnes du fichier CLIP.


# Boucle pour parcourir le fichier de decoupage des montants CLIP a la recherche de lignes en erreur
# plus le calcul du montant total.

while IFS= read -r line
do
  LIGNE_COUNT=$((LIGNE_COUNT+1))  
  if [ $LIGNE_COUNT -ne 1 ]
  then
    if [ $LIGNE_COUNT -ne $NombreLignes ]
    then
      Montant=$line
      is_numeric "$Montant"
      if [[ $TMP_IS_NUMERIC -eq 1 ]]
      then
          Count=$((Count+Montant))                
      fi        
    fi 
  fi

  if [ $? -ne 0 ]; then
  # Controle des iterations.
  ${JOURNAL} ${LINENO} S0999 1 " "
  ${JOURNAL} ${LINENO} S0999 1 " "
  ${JOURNAL} ${LINENO} S0998 1 \
      "Fin KO du traitement du comptage CLIP: erreur lors de la recuperation des donnees dans le fichier CLIP."
  ${JOURNAL} ${LINENO} S0998 1 \
      "Arret a la ligne $LIGNE_COUNT."
      rm -f "${FileCoupMontant}"
      rm -f "${FICPARAM_TEMP}"
      exit 1 
  fi 
  # Fin du controle des iterations.
done <"$FileCoupMontant"

if [ $CountMauvaises -eq 0 ]; then
    # Debut insertion log --------------------------
    ${JOURNAL} ${LINENO} S0999 1 " "
    ${JOURNAL} ${LINENO} S0999 1 \
      "Pas de lignes en erreur."
    ${JOURNAL} ${LINENO} S0999 1 " "
    # Fin insertion log ----------------------------
fi

if [ $? -ne 0 ]; then
  ${JOURNAL} ${LINENO} S0999 1 " "
  ${JOURNAL} ${LINENO} S0999 1 " "
  ${JOURNAL} ${LINENO} S0998 1 \
      "Fin KO du traitement du comptage CLIP: erreur lors de la recuperation des donnees dans le fichier CLIP."
  rm -f "${FileCoupMontant}"
  rm -f "${FICPARAM_TEMP}"
  exit 1
else
  ${JOURNAL} ${LINENO} S0999 1 \
      "Sortie de la boucle de comptage CLIP avec succes."
  rm -f "${FileCoupMontant}"
fi

# Division par le facteur pour adapter la chaîne de chiffres.
RealCount=$(echo "scale=3; $Count/$Facteur" | bc)

# Formatage de la chaine de chiffres en 3 pas:

# 1-Arrondi plafond a 2 chiffres decimales
RealCountFormat=$(awk -v a="$RealCount" 'BEGIN { printf "%.2f\n", a}')
# 2-On transforme la chaine numerique de type "123456789.12" a "123456789,12"
RealCountFormat=${RealCountFormat//./,}
# 3-On transforme la chaine numerique de type "123456789,12" a "123 456 789,12"
RealCountFormat=$(echo "$RealCountFormat" | sed ':a;s/\B[0-9]\{3\}\>/ &/;ta')
# Calcul nombre lignes correctes.
NombreLignesComptage=$((NombreLignes-2))
NombreLignesCorrectes=$((NombreLignesComptage-CountMauvaises))
# On transforme la chaine numerique de type "123456789" a "123 456 789"
NombreLignesCorrectes=$(echo "$NombreLignesCorrectes" | sed ':a;s/\B[0-9]\{3\}\>/ &/;ta')

# Debut insertion log -------------------------
${JOURNAL} ${LINENO} S0999 1 " "
${JOURNAL} ${LINENO} S0999 1 " "
${JOURNAL} ${LINENO} S0999 1 \
"Nombre total lignes correctes = $NombreLignesCorrectes"
${JOURNAL} ${LINENO} S0999 1 \
"Nombre total lignes en erreur = $CountMauvaises"

# Fin insertion log ----------------------------

# Debut insertion fichier-----------------------
echo "Nombre de lignes avec un montant valide : $NombreLignesCorrectes" >> "${FileComptageCLIP}"

RealCountFormatComma="$(echo $RealCountFormat | sed 's/\./,/g')"
echo "Montant total = $RealCountFormatComma euros" >> "${FileComptageCLIP}"
#echo "Nombre total lignes en erreur = $CountMauvaises" >> "${FileComptageCLIP}"
# Fin insertion fichier-----------------------


#------------------------ 9-Finalisation du traitement --------------------------------
if [ $? -ne 0 ]
then
   ${JOURNAL} ${LINENO} S0999 1 " "
   ${JOURNAL} ${LINENO} S0998 1 "Fin KO du traitement du comptage CLIP: probleme lors de la suppression du fichier CLIP."
   rm -f "${FICPARAM_TEMP}"
   exit 1
else
   ${JOURNAL} ${LINENO} S0999 1 " "
   ${JOURNAL} ${LINENO} S0999 1 "Suppresion fichier CLIP correcte."
   ${JOURNAL} ${LINENO} S0999 1 "Fin OK du traitement du comptage CLIP." 
   
   # Suppression fichier CLIP du repertoire de TRAVAIL.
   rm -f "${FileClip}" 
   
   # Modifier le fichier flag   
   echo "${FileClip}" > "${FICFLAG}"
fi


#------------------------ 10-Suppression du fichier de parametrage specifique -------
rm -f "${FICPARAM_TEMP}"
exit 0
