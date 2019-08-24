
#!/bin/ksh


Count=0
Count_montant=0
nbocurr=0
cut_montant=0
montant_cumul_ligne=0
montant_cumul_ligne_repetee=0
delta=0
TMP_STR="$1"
montant_summ_diff=0
montant_diff_ligne=0

IFS=$'\n' myarr=($(awk -F, '++seen[$0] == 2' "$1"))
echo "Fichier" > sortieGrand.txt
for i in "${myarr[@]}"
do
  echo " "
  echo " "
  echo " "
  echo " "
  echo " "
  echo " " >> sortieGrand.txt
  echo " " >> sortieGrand.txt
  echo " " >> sortieGrand.txt
  echo " " >> sortieGrand.txt
  echo " " >> sortieGrand.txt
  echo "Ligne repetee:"
  echo "Ligne repetee:" >> sortieGrand.txt
  echo " "
  echo " " >> sortieGrand.txt
  echo $i >> sortieGrand.txt
  
  nbocurr=`grep $i "$1"  | wc -l`
  
  echo "Nombre ocurrences = $nbocurr" >> sortieGrand.txt
  
  cut_montant=$(echo $i | cut -c 202-213)
  
  echo "Montant ligne = $cut_montant" 
  echo "Montant = $cut_montant" >> sortieGrand.txt
  echo "Montant cumul ligne = cut_montant x nbocurr = $cut_montant  X$nbocurr = " 
  
  #montant_cumul_ligne_repetee=$((montant_cumul_ligne_repetee+cut_montant))
  
  montant_cumul_ligne=$((nbocurr*cut_montant))
  echo "montant_cumul_ligne = $montant_cumul_ligne"
  echo "montant_cumul_ligne = $montant_cumul_ligne" >> sortieGrand.txt
  
  echo " "
  
  montant_diff_ligne=$((montant_cumul_ligne-cut_montant))
  echo "montant_diff_ligne = $montant_diff_ligne"
  echo "montant_diff_ligne = $montant_diff_ligne" >> sortieGrand.txt
  
  montant_summ_diff=$((montant_summ_diff+montant_diff_ligne)) 
  echo "montant_summ_diff = $montant_summ_diff"
  echo "montant_summ_diff = $montant_summ_diff" >> sortieGrand.txt

  # echo "Montant cumul ligne repetee = $montant_cumul_ligne"
  # Count_montant=$((Count_montant+montant_cumul_ligne))
  # echo "Cumul montants lignes repetees = $Count_montant"
  # Count=$((Count+1))

done

echo " "
echo " "
echo " "
echo " "
echo " "
echo " "

echo " " >> sortieGrand.txt
echo " " >> sortieGrand.txt
echo " " >> sortieGrand.txt
echo " " >> sortieGrand.txt
echo " " >> sortieGrand.txt
echo " " >> sortieGrand.txt

echo "Sum diff = $montant_summ_diff"
echo "Sum diff = $montant_summ_diff" >> sortieGrand.txt

# echo "Count = $Count" >> sortieGrand.txt
# echo "Count = $Count" 
# echo "Count total montants lignes repetees = $Count_montant" >> sortieGrand.txt
# echo "Count total montants lignes repetees = $Count_montant"
# echo "Count cumul lignes repetees= $montant_cumul_ligne_repetee" >> sortieGrand.txt
# echo "Count cumul lignes repetees= $montant_cumul_ligne_repetee"
 

# delta=$((Count_montant-montant_cumul_ligne_repetee))
# echo "Delta total montants - cumul montants = $Count_montant - $montant_cumul_ligne_repetee = $delta"
# echo "Delta total montants - cumul montants = $Count_montant - $montant_cumul_ligne_repetee = $delta" >> sortieGrand.txt
exit 0
