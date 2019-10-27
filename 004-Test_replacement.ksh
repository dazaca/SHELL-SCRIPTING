#!/bin/ksh
#https://gist.github.com/un33k/1162378

:<< 'COMMENT'
//////////////////////////////////////////////////////////////////////////////////////////

The main goal of this script is to replace all the old values by new values 
in a given file by using a reference file in which the second and the third
columns contains the correspondences between those values. To do this repla-
cement, a condition will be stablished for each line of the file to modify. 
This condition will be a string pattern passed as a first column in the
reference file (also called condition file). The modifications will be done
in a file called "result.txt".

Given a condion file (second parameter TMP_STR2), its first column represents 
the condition string that indicates the line where the replacement have to be
done in the original file (first parameter TMP_STR1). The second column would
be de old value "old_val" to replace by the new value "new_val" positioned in
the third column. All changes made with "sed" command will be applied to a 
third file called result.txt (TMP_STR3 variable) and not to the original 
represented by the TMP_STR1 variable.

IMPORTANT: the condition file represented by the TMP_STR2 variable must have
a final empty line.

I.E.:

Having this condition file:

---------------
ab-78 666 777  
def-1 zzz YYY
---------------

in a original file like this one:

--------------------------------------------
abc45
abcd33
abcde227 cdef-1 zzzY2 zzz | zzz abzzzab
9xab 4 7777dd
cdef-1 99xcdcat
6667dd ab-78   6667dd6667ab9x3x
7777ab9x3x 
6667dd ab-78   6667dd6667ab9x3x
ab-78  6667dd XXXX
def-1  zzzY2 2
--------------------------------------------

the result of  appliying the script would be:

--------------------------------------------
abc45
abcd33
abcde227 cdef-1 YYYY2 YYY | YYY abYYYab
9xab 4 7777dd
cdef-1 99xcdcat
7777dd ab-78   7777dd7777ab9x3x
7777ab9x3x 
7777dd ab-78   7777dd7777ab9x3x
ab-78  7777dd XXXX
def-1  YYYY2 2
--------------------------------------------

//////////////////////////////////////////////////////////////////////////////////////////
COMMENT

#TMP_STR1 -> variable taking the first parameter representing the file from which the changes will be done.
TMP_STR1="$1"
#TMP_STR2 -> variable taking the second parameter representing the file containing the conditions.
TMP_STR2="$2"
#TMP_STR3 -> variable associated to the file where the changes will be made.
TMP_STR3="result.txt"
#Concat -> variable from which the "sed" statement will be developed.
concat="sed \""

function TransformFile
{

  i=0
  while IFS= read -r line
    # For each line of the condition file ...
	do 
    # ... we extract the pattern condition from the first column of the line "line".
    condition=$(echo $line | awk '{print $1;}')
    # Then we get the old value to be replaced.
    old_val=$(echo $line | awk '{print $2;}')
    # Then we get the new value that will replace the old value.
    new_val=$(echo $line | awk '{print $3;}')
   
    # Then we write the second part of the "sed" command using current values of "condtion", "old_val" and "new_val".
    # This "sed" command will stock as much as replacement commands as lines exists in the "condition" file. The
    # result of the entire command can be seen by uncommenting the line 102 in this script. For our exemple, the line
    # produced would be: sed "/ab-78 /s/666/777/g;/def-1 /s/zzz/YYY/g;" fichier2.txt > result.txt
    # with "fichier2.txt" as our first parameter TMP_STR1 and "result.txt" as our final file containing the modifications.

    concat="${concat}/${condition} /s/${old_val}/${new_val}/g;"

  done <"$TMP_STR2"

  concat="${concat}\" $TMP_STR1 > $TMP_STR3"
  #echo "$concat"

  # This line will execute the "sed" command stocked in the "concat" variable.
  eval "$concat"
}

# Call to the "TransformFile" function:

TransformFile "$TMP_STR2"

exit 0