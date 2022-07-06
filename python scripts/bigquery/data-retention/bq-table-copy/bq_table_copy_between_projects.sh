#!/bin/bash
#This script copies prd BQ tables to dev BQ under the same dataset
#Mak
gcpFromProject="ashish-test-prod"
gcpToProject="ashish-test-dev"
dataset="newsiq_exports"

while read line; 
do 
    printf "\nTable : ${line}\n"
        bq cp ${gcpFromProject}:${dataset}.${line} ${gcpToProject}:${dataset}.${line} > tablecopy.log
        status=`cat tablecopy.log | grep "successfully copied to" | wc -l |tr -d '[:space:]'`
        if [[ "$status" == 1 ]]; then
            printf "\nCopied ${line} to ${gcpToProject} BQ\n"
        else
            printf "\n${line} was not copied to ${gcpToProject} BQ\n"
        fi
done < tableList.txt