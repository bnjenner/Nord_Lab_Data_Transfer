#!/bin/bash

###############################################################
#### Usage Message

usage=$(cat << EOF
usage:
    $(basename "$0") [-h] [-s source] [-d destination]

description:
    Implementation of clone.sh that copies contents of subdirectories into corresponding, pre-existing directories.  

arguments:
    -h help   prints help documentation
    -s source   source location for files to copy
    -d drive    location for source
    -e email    email address to send completion or error message
    -k key    key file specifying email and password ("email:password")
    -l log              directory for log
    -i includes             file with directories in following format: directory/

For questions of comments, contact Bradley Jenner at <bnjenner@ucdavis.edu>
EOF
)

###############################################################
#### Exit and Error and Debug Messages

set -e
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "\"${last_command}\" command failed on line ${LINENO}."' ERR

###############################################################
#### Argument Parser

while getopts ':hs:d:e:k:l:i:' option; do
  case $option in
    h) echo "$usage"
       exit
       ;;
    s) SOURCE_DIR=${OPTARG%/}
       ;;
    d) DEST_DIR=${OPTARG%/}
       ;;
    e) EMAIL=${OPTARG}
       ;;
    k) KEY=${OPTARG}
       ;;
    l) LOG_DIR=${OPTARG%/}
       ;;
    i) INCLUDES=${OPTARG}
       ;;
  esac
done

shift $((OPTIND - 1))

###############################################################
#### File Transfer Script

ID=`date +%s`

echo "##### Transfer ID: ${ID} #####"

mkdir ${LOG_DIR}/phase_2_${ID}

# checks for directories on cluster
rclone lsd --include-from=${INCLUDES} $SOURCE_DIR | \
  awk '{print $5}' > ${LOG_DIR}/phase_2_${ID}/phase_2_source_dirs_${ID}.txt

# checks for directories on specified directory containing local hard drives 
rclone lsd -L --exclude=logfolder/ --exclude=box.com/ $DEST_DIR | \
  awk '{print $5}' > ${LOG_DIR}/phase_2_${ID}/phase_2_dest_dirs_${ID}.txt


# iterates over directories to find matching directories and then initiates a transfer between them. 
# this process does not overwrite, but instead, updates.
for dest_dir in `cat ${LOG_DIR}/phase_2_${ID}/phase_2_dest_dirs_${ID}.txt`
do
  for dest_subdir in `ls ${DEST_DIR}/$dest_dir | sort -u`
  do

    for source_dir in `cat ${LOG_DIR}/phase_2_${ID}/phase_2_source_dirs_${ID}.txt | sort -u`
    do

      if [[ $dest_subdir == $source_dir ]]
      then

  clone.sh -s ${SOURCE_DIR}/${source_dir} \
                 -d ${DEST_DIR}/${dest_dir}/${dest_subdir} \
                 -l $LOG_DIR \
                 -e $EMAIL -k $KEY \
                 -v -i ${ID}_${dest_dir}_$dest_subdir
      fi
    done
  done
done

# moves all temp and log files/directoris to a meta dircetory for cluster sync.
[[ -d ${LOG_DIR}/log_${ID}_debug ]] || mkdir ${LOG_DIR}/log_dir.${ID}
mv ${LOG_DIR}/*_${ID}*/ ${LOG_DIR}/log_dir.${ID}/
