#!/bin/bash

chmod +x wordStats.sh

function convertFile() {

   # Validate the file input so the user cant specify a non-existing file
   # To validate the file first we need to check if the file exists

   echo "[INFO] Validating file"

   if [[ ! -f $file ]]; then
      echo "[ERROR] The input file does not exist"
      exit

   # Then it's necessary to verify the extension of the file so just .pdf and .txt files are accepted
   # We will convert the file to txt just when the input file its and pdf

   elif [[ "$file" == *.pdf ]]; then
      echo "[INFO] Processing '$file_name.pdf'"
      pdftotext "$file"
      echo "$file_name : PDF file"

   elif [[ "$file" == *.txt ]]; then
      echo "$file_name : TXT file"
      echo "[INFO] Processing '$file_name.txt'"

   else
      echo "[ERROR] The input file is not a pdf or a txt file"
      exit
   fi

   echo "[INFO] Validation complete"

}

function removeStopWords() {

   # Before starting removing the stop words we need to verify if the stopwords file exists

   if [[ ! -f "./StopWords/$lang.stop_words.txt" ]];then
      echo "The file with $lang stop words dont exist"
      exit

   fi
   


   echo "STOP WORDS will be filtered out"
   echo "StopWords file '$lang' : words - $(wc -w StopWords/"$lang".stop_words.txt ) " 

   # -v reverse the word's selection, that is, instead of selecting the same words from the given file, present in the stopwords file 
   # select the different words from the given file

   # -w only select lines that contain whole words like the ones provided in the stopwords file

   # -f indicates the file with the words to be removed

   grep -vwf ./StopWords/"$lang".stop_words.txt "$file_location"/processing"$file_name".txt >"$file_location"/processing2"$file_name".txt
   mv "$file_location"/processing2"$file_name".txt "$file_location"/processing"$file_name".txt

}

function createPlot() {

   # From the file generated with all the unique words we are just saving the first "$num_word" words to the data.dat file
   # so it can be plotted
   
   # We decided that it would be better if we resize the image corresponding to the number of words plotted for
   # the x-axis so the labels do not overlap each other

   echo "[INFO] Starting to plot $num_word words"

   if [[ $num_word -gt 5 ]]; then

      echo "set term png size $((num_word * 100)),500" >gnuCommands.txt

   else
      echo "set term png size 500,500" >gnuCommands.txt

   fi

   # We used shellcheck to verify this syntax and we were getting a warning that redirected us to a GitHub page with the more appropriate fix
   # fix https://github.com/koalaman/shellcheck/wiki/SC2129

   # Here are the Gnuplot commands that will be stored in a file so then they can be executed inside Gnuplot

   {
      echo 'set yrange [0:]'
      echo 'set boxwidth 0.75'
      echo 'set xlabel "words"'
      echo 'set ylabel "number of occurrences"'
      echo 'set style fill solid'
      echo "set output '$file_location/result---$file_name.png'"
      echo 'set title "Top words of '$(basename "${file%}")' \n Created: '$(date "+%Y-%m-%d %T")'"'
      echo 'plot   "<(head -'$num_word' '$file_location'/result---'$file_name'.txt)" using 2:xtic(3) lc rgb "#038cfc" with boxes title "# of occurrences" , ""  using 0:($2+.1):(sprintf("%d",$2)) with labels notitle'

   } >> gnuCommands.txt

   gnuplot gnuCommands.txt
   
   echo "[INFO] Plot complete"

}

function createHtml() {

   # This function creates an HTML file with a ploted png image

   echo "[INFO] Generating HTML file"

   {
      echo '<!DOCTYPE html>'
      echo "<html lang='$lang'>"
      echo '  <head>'
      echo '    <meta charset="UTF-8">'
      echo '    <meta http-equiv="X-UA-Compatible" content="IE=edge">'
      echo '    <meta name="viewport" content="width=device-width, initial-scale=1.0">'
      echo "    <title>Top $num_word Words - $file</title>"
      echo '  </head>'
      echo '  <body align="center">'

      # Here the location of the image doesnt have the $file_location because the html file created 
      # will be in the same location of the output png

      echo "    <img src='result---$file_name.png' alt='image'>"
      echo '     <div>Authors: Pedro Pedro, Ricardo Franco</div>'
      echo "     <div>Created: $(date "+%Y-%m-%d %T")</div>"
      echo '  </body>'
      echo '</html>'
   } >"$file_location/result---$file_name.html"

   echo "[INFO] Generation complete"

}

function checkEnvWordStatsTop() {

   # In this line we are storing the number of lines that the file have in $num_word

   num_word=$(wc -l <"$file_location/result---$file_name.txt")

   # First, we are checking if the env variable "WORD_STATS_TOP" is defined, if not, we will plot 10 words from the file

   # Second, we are checking if the number of words in the file is greater than or equal to the env variable "WORD_STATS_TOP"
   # if it is, the script will plot the first "$WORD_STATS_TOP words

   # Finally if the "WORD_STATS_TOP" env variable isn't set or the number of unique words in the file its less than "WORD_STATS_TOP"
   # value then it will just plot all the words of the file

   # We searched how to verify if an env var was set in this URL 
   # https://www.cyberciti.biz/faq/unix-linux-bash-script-check-if-variable-is-empty/

   if [[ -z "${WORD_STATS_TOP+set}" ]] || [[ "$WORD_STATS_TOP" =~ [[:alpha:]] ]]; then
      echo "[INFO] The environment variable 'WORD_STATS_TOP' isnt set or its a string"
      echo "(using default 10)"
      
      num_word=10
      
   elif [[ "$WORD_STATS_TOP" -eq 0 ]] || [[ "$WORD_STATS_TOP" -lt 0 ]] ; then
      echo "[INFO] The environment variable 'WORD_STATS_TOP' it's set but it's equal or less than 0"
      echo "(using default 10)"

      num_word=10

   elif [[ $num_word -ge $WORD_STATS_TOP ]]; then

      num_word=$WORD_STATS_TOP

   else
      echo "[ERROR] The value of the env variable 'WORD_STATS_TOP' it's greater than the number of unique words in the '$file_name' file"
      echo "[INFO] The script will show all the words of the '$file_name' file"

   fi

}

function cleanTmpFiles() {

   # If the temp files used in the program exist this function will remove them

   if [[ -f "$file_location"/processing"$file_name".txt ]]; then

      rm "$file_location"/processing"$file_name".txt

   fi

   # If the initial file was a pdf when running pdftotext that script will create a txt file of the pdf, and in the end we will not need it anymore

   if [[ "$file" == *.pdf ]] && [[ -f "$file_location"/"$file_name".txt ]]; then
      rm "$file_location"/"$file_name".txt
   fi

   if [[ -f "gnuCommands.txt" ]]; then
      rm "gnuCommands.txt"
   fi
}

# For better use of the variables we decided to first check if the cardinality of the entries is equal to 3
# and only when this is true, do we create the other variables to use in the script

if [[ $# -eq 3 ]]; then

   mode=$1
   file=$2
   file_location="$(dirname "$2")"
   file_name="$(basename "${2%.*}")"
   lang=$3

   # Validating if the input mode it's supported

   if [[ "${mode^^}" != "C"* ]] && [[ "${mode^^}" != "P"*  ]] && [[ "${mode^^}" != "T"*  ]]; then
      echo "[ERROR] The only supported modes are C/c, P/p, T/t"

   # Validate the language inputs

   elif [[ $lang != "en" ]] && [[ $lang != "pt" ]]; then
      echo "[ERROR] Invalid language option. Valid input [ISO3166]: pt or en"
 
   else

      convertFile

      # Here in the first place we are removing all the numbers from the txt file (tr -d "0-9") 
      # then converting all the upper characters to lower (tr '[:upper:]' '[:lower:]') and then
      # using grep -oE to separate every word one per line (-o) by a given pattern (-E)

      # Pattern '\w+': \w --> Matches any word character (alphanumeric & underscore)  + --> Matches 1 or more of the preceding character 
      
      # Finally saving the changes in a temporary file that will be deleted when the end script finishes 

      tr -d "0-9" <"$file_location"/"$file_name".txt | tr '[:upper:]' '[:lower:]' | grep -oE '\w+' >"$file_location"/processing"$file_name".txt
   
      # Verifying if the user wants to remove the StopWords
      
      if [[ $mode == "c"* ]] || [[ $mode == "p"* ]] || [[ $mode == "t"* ]]; then

         removeStopWords

      fi

      # To verify just the upper letter in the next switch case we convert the input "mode" field to upper

      mode="${mode^^}"

      # Primarily we are sorting all the lines alphabetically with sort < "file" then
      # using uniq -c we were able to count the number of occurrences of a word and prefix that number to the word.
      # To sort the lines by the number of occurrences in ascending order we used sort (-n) but with (-r) we could invert to descending order
      # We used nl to prefix the number of the line in each line 
 
      sort <"$file_location"/processing"$file_name".txt | uniq -c | sort -nr | nl >"$file_location"/result---"$file_name".txt

      checkEnvWordStatsTop

      case $mode in
         
      # If the user add a letter by accident when stating the "mode" the script will just verify the first letter

      "C"*)
         echo "COUNT MODE"
         head "-$num_word" "$file_location/result---$file_name.txt"
         echo "RESULTS: '$file_location/result---$file_name.txt'"
         
         ;;
      "P"*)
         createPlot
         createHtml
         display "$file_location/result---$file_name.png" 
         ls -la "$file_location/result---$file_name.txt" "$file_location/result---$file_name.png" "$file_location/result---$file_name.html"
   
         ;;

      "T"*)
         ls -la "$file_location/result---$file_name.txt"
         echo "# TOP $num_word elements"
         head "-$num_word" "$file_location/result---$file_name.txt"
         ;;

      esac

      cleanTmpFiles

   fi

else

   echo "[ERROR] The inputs are not correct $0 [mode] [file location] [ISO3166]"

fi

