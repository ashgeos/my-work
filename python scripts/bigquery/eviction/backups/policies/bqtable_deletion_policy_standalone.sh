#!/bin/bash
#The script will dete the big qyery tables based on the data retention policy set inside the table_deletion_policy.txt
#This script takes one argumentas input that is --dry_run=true or --dry_run=false, 
#if true the script will just show what all tables will be deleted in the log file, if false then the scrip will delete the tables without any user itervention.
#It is always adviced to use --dry_run=true to check the tables that will be deleted, validate and then run it with --dry_run=false

#stores the log files location
logfile="/tmp/bqtable_deletion_`date +%Y%m%dT%H%M%S`.log"
filenamedate=`date +%Y%m%dT%H%M%S`
export NEWSIQ_GCP_BQ_DOWNSTREAM_BUFFER="3"

#Authenticate the gcloud user
projectId=`cat /secrets/gcp/credentials.json | grep "project_id" | awk -F " " {'print $2'} | sed 's/[,"]//g'`
gcloud auth activate-service-account --key-file=/secrets/gcp/credentials.json --project=${projectId}

#Validates the script input argument 
if [[ "$1" == "--dry_run=true" ]] || [[ "$1" == "--dry_run=True" ]] || [[ "$1" == "--dry_run=TRUE" ]];then
    printf "Dry run is set to true, this script will not delete any tables, will simulate what will be deleted, please check ${logfile} to know more\n"
    dry_run=1
elif [[ "$1" == "--dry_run=false" ]] || [[ "$1" == "--dry_run=False" ]] || [[ "$1" == "--dry_run=FALSE" ]]; then
    printf "Dry run is set to false, this script will delete tables specified in table_deletion_policy.txt based on the policy,please check ${logfile} to know more\n"
    dry_run=0
elif [[ -z "$1" ]]; then
    exit 1
else
    exit 1
fi

printf "Please go through the ${logfile} file to see what the script performed.\n"
#Extracts the GCP project and BQ downstream buffer from the environment variable

downstream_buffer=`env | grep "NEWSIQ_GCP_BQ_DOWNSTREAM_BUFFER" | awk -F"NEWSIQ_GCP_BQ_DOWNSTREAM_BUFFER=" {'print $2'}`
if [[ -z ${projectId} ]]; then
    printf "GCP Project was not avilabe from the credentials.json.\n"
    exit 1
elif [[ -z ${downstream_buffer} ]]; then
    printf "GCP BQ downstream buffer environment variable is not set, please set NEWSIQ_GCP_BQ_DOWNSTREAM_BUFFER environment variable and re-run the script.\n"
    exit 1
else
    :
fi


#Function to delete only the partitioned tables of big query.
partitioned_delete()
{
    local dataset=${1}
    local table=${2}
    local policy=${3}
    local project=${4}
    bq query --nouse_legacy_sql --format=csv  'select _PARTITIONTIME as day, count(*) cnt from `'${dataset}'.'${table}'` group by 1 order by 1 desc ' | sed "2 d" | sed '/^[[:space:]]*$/d' > /tmp/temppartitionedtable_${filenamedate}.txt
    error=`cat /tmp/temppartitionedtable_${filenamedate}.txt | grep "Not found" | wc -l`
    if [[ "$error" -gt 0 ]]; then
	    printf "\n#################################################################\n\n" >> $logfile
        printf "Table ${table} does not exist in dataset ${dataset}\n" >> $logfile
        rm -rf /tmp/temppartitionedtable_${filenamedate}.txt
    else
        totalcount=`cat /tmp/temppartitionedtable_${filenamedate}.txt | sort | awk -F, {'print $1'} | wc -l`
        if [[ "$totalcount" -le 1 ]]; then
            printf "\n#################################################################\n\n" >> $logfile
            printf "The policy is to retain time partition data upto ${policy} days, but we found only 1 or 0 partition that exist, hence skipping it.\n" >> $logfile
            printf "Skipping deletion for dataset : ${dataset} and table : ${table}\n" >> $logfile
            rm -rf /tmp/temppartitionedtable_${filenamedate}.txt /tmp/partitionedtable_${filenamedate}.txt
        else
            cat /tmp/temppartitionedtable_${filenamedate}.txt | sort | awk -F, {'print $1'} | head -n -${policy} > /tmp/partitionedtable_${filenamedate}.txt
            pcount=`cat /tmp/partitionedtable_${filenamedate}.txt |  wc -l`
            if [[ "$pcount" -eq 0 ]]; then
                printf "\n#################################################################\n\n" >> $logfile
                printf "The policy is to retain table data upto ${policy} days\n" >> $logfile
                printf "Number of Partitioned tables to be deleted for dataset : ${dataset} and table : ${table} is ${pcount}\n" >> $logfile
                rm -rf /tmp/temppartitionedtable_${filenamedate}.txt /tmp/partitionedtable_${filenamedate}.txt
            elif [[ "$pcount" -gt 0 ]]; then
                printf "\n#################################################################\n\n" >> $logfile
                printf "The policy is to retain table data upto "$policy" days\n" >> $logfile
                printf "Number of Partitioned tables to be deleted for dataset : ${dataset} and table : ${table} is ${pcount}\n" >> $logfile
                while read line;
                do
                    bqtabledeletionsize="0"
                    absolutetablename="${projectId}:${dataset}.${table}"
                    tabledate=`echo "$line" | awk -F" " {'print $1'} | sed 's/-//g'`

                    if [[ "$dry_run" == 0 ]]; then
                        printf "Partition ${line} of table ${projectId}:${dataset}.${table} will be deteted.\n" >> $logfile
                        bqtabledeletionsize=`bq --format=json  show ""$absolutetablename"$"$tabledate"" | jq '.numBytes | tonumber' | head -n 1`
                        bqdeletionsizetotal="$(($bqtabledeletionsize + $bqdeletionsizetotal))"
                        bq query --nouse_legacy_sql --format=csv 'delete from `'${dataset}'.'${table}'`  where _PARTITIONTIME = "'${line}'" '
                        rm -rf /tmp/temppartitionedtable_${filenamedate}.txt
                    elif [[ "$dry_run" == 1 ]]; then
                        printf "Partition ${line} of table ${projectId}:${dataset}.${table} will be deteted.\n" >> $logfile
                        bqtabledeletionsize=`bq --format=json  show ""$absolutetablename"$"$tabledate"" | jq '.numBytes | tonumber' | head -n 1`
                        bqdeletionsizetotal="$(($bqtabledeletionsize + $bqdeletionsizetotal))" 
                        rm -rf /tmp/temppartitionedtable_${filenamedate}.txt
                    else
                        :
                    fi
                done < /tmp/partitionedtable_${filenamedate}.txt
                rm -rf /tmp/partitionedtable_${filenamedate}.txt
            else
                :
            fi
        fi
    fi
}

#The main script starts here
bqdeletionsizetotal=0
printf "Big Query Datasets.\n"
bq ls
while read line;
do
    dataset=`echo ${line} | awk -F':TABLE=' {'print $1'} | awk -F'=' {'print $2'}`
    table=`echo ${line} | awk -F':TABLE=' {'print $2'} | awk -F':TYPE' {'print $1'}`
    type=`echo ${line} | awk -F"TYPE=" {'print $2'} | awk -F":POLICY=" {'print $1'}`
    policy=`echo ${line} | awk -F':POLICY=' {'print $2'}`
    filedate=`date +%Y%m%dT%H%M%S`
    touch /tmp/truetables_${filedate}.txt
    if [[ -z "$dataset" ]] || [[ -z "$table" ]] | [[ -z "$type" ]] | [[ -z "$policy" ]]; then
        printf "The policy string is not in the correct format please validate the table_deletion_policy.txt file entrys.\n" >> $logfile
        exit 1
    elif [[ "$type" == "PARTITIONED" ]]; then
        partitioned_delete ${dataset} ${table} ${policy} ${projectId}
    else
        bq ls --max_results=100000 "${dataset}" | grep "${table}" |  awk {'print $1'} > /tmp/temptables_${filenamedate}.txt
        scounttable=`echo -n ${table} | wc -c`
        sncounttable=`expr $scounttable + 8`
        while read line;
        do
            stringcounttable=`echo -n ${line} | wc -c`
            if [[ "$stringcounttable" == "$sncounttable" ]]; then
                printf "${line}\n" >> /tmp/truetables_${filedate}.txt
            else
                :
            fi
        done < /tmp/temptables_${filenamedate}.txt
        printf "\n#################################################################\n\n" >> $logfile
        printf "The policy is to retain table data upto ${policy} days\n" >> $logfile
        cat /tmp/truetables_${filedate}.txt | head -n -${policy} > /tmp/tablesUnderPolicy_${filenamedate}.txt
	    rm -rf /tmp/truetables_${filedate}.txt /tmp/temptables_${filenamedate}.txt
        count=`cat /tmp/tablesUnderPolicy_${filenamedate}.txt | wc -l`
	    printf "Number of tables to be deleted for dataset : ${dataset} and table : ${table} is ${count}\n" >> $logfile
        if [[ "$count" -gt 0 ]]; then
            while read line;
            do
                if [[ "$dry_run" == 0 ]]; then
                    bqtabledeletionsize="0"
                    absolutetablename="${projectId}:${dataset}.${line}"
                    if [[ "$dataset" == "newsiq_dfp" ]] || [[ "$dataset" == "newsiq_pixel" ]] || [[ "$dataset" == "newsiq_prebid" ]] || [[ "$dataset" == "newsiq_ad_value" ]]; then
                        if [[ "$downstream_buffer" == 0 ]]; then
                            printf "Table ${line} is getting deleted from Bigquery\n" >> $logfile
                            bqtabledeletionsize=`bq --format=json  show "$absolutetablename" | jq '.numBytes | tonumber' | head -n 1`
                            bqdeletionsizetotal="$(($bqtabledeletionsize + $bqdeletionsizetotal))"
                            bq rm -f -t ${projectId}:${dataset}.${line}
                        else
                            temp_downstream_buffer_date=`date --date="${downstream_buffer} days ago" '+%Y-%m-%d %H:%M:%S'`
                            downstream_buffer_date=`date +%s -d"$temp_downstream_buffer_date"`
                            bq query --nouse_legacy_sql --format=prettyjson 'SELECT *REPLACE(TIMESTAMP_MILLIS(last_modified_time) AS last_modified_time), FROM `'${projectId}'.'${dataset}'.__TABLES__` where table_id = "'${line}'" ' > /tmp/bq_table_info.txt 
                            temp_last_modified_date=`cat /tmp/bq_table_info.txt | grep last_modified_time | awk -F"last_modified_time" {'print $2'} | awk -F": " {'print $2'} | sed 's/\"//g' | sed 's/\,//g'`
                            last_modified_date=`date +%s -d"$temp_last_modified_date"`
                            if [[ "$last_modified_date" -gt "$downstream_buffer_date" ]]; then
                                printf "Table ${line} is skipped from deletion as the table is modified recently, computed using downstream_buffer\n" >> $logfile
                                rm -rf /tmp/bq_table_info.txt
                            else 
                                printf "Table ${line} is getting deleted from Bigquery, computed using downstream_buffer\n" >> $logfile
                                bqtabledeletionsize=`bq --format=json  show "$absolutetablename" | jq '.numBytes | tonumber' | head -n 1`
                                bqdeletionsizetotal="$(($bqtabledeletionsize + $bqdeletionsizetotal))"
                                bq rm -f -t ${projectId}:${dataset}.${line}
                                rm -rf /tmp/bq_table_info.txt
                            fi
                        fi
                    else
                        printf "Table ${line} is getting deleted from Bigquery\n" >> $logfile
                        bqtabledeletionsize=`bq --format=json  show "$absolutetablename" | jq '.numBytes | tonumber' | head -n 1`
                        bqdeletionsizetotal="$(($bqtabledeletionsize + $bqdeletionsizetotal))"
                        bq rm -f -t ${projectId}:${dataset}.${line}
                    fi
                elif [[ "$dry_run" == 1 ]]; then
                    bqtabledeletionsize="0"
                    absolutetablename="${projectId}:${dataset}.${line}"
                    if [[ "$dataset" == "newsiq_dfp" ]] || [[ "$dataset" == "newsiq_pixel" ]] || [[ "$dataset" == "newsiq_prebid" ]] || [[ "$dataset" == "newsiq_ad_value" ]]; then
                        if [[ "$downstream_buffer" == 0 ]]; then
                            printf "Table ${line} is getting deleted from Bigquery\n" >> $logfile
                            bqtabledeletionsize=`bq --format=json  show "$absolutetablename" | jq '.numBytes | tonumber' | head -n 1`
                            bqdeletionsizetotal="$(($bqtabledeletionsize + $bqdeletionsizetotal))"
                        else
                            temp_downstream_buffer_date=`date --date="${downstream_buffer} days ago" '+%Y-%m-%d %H:%M:%S'`
                            downstream_buffer_date=`date +%s -d"$temp_downstream_buffer_date"`
                            bq query --nouse_legacy_sql --format=prettyjson 'SELECT *REPLACE(TIMESTAMP_MILLIS(last_modified_time) AS last_modified_time), FROM `'${projectId}'.'${dataset}'.__TABLES__` where table_id = "'${line}'" ' > /tmp/bq_table_info.txt 
                            temp_last_modified_date=`cat /tmp/bq_table_info.txt | grep last_modified_time | awk -F"last_modified_time" {'print $2'} | awk -F": " {'print $2'} | sed 's/\"//g' | sed 's/\,//g'`
                            last_modified_date=`date +%s -d"$temp_last_modified_date"`
                            printf "Last modifed date for table ${line} is ${temp_last_modified_date}\n"
                            if [[ "$last_modified_date" -gt "$downstream_buffer_date" ]]; then
                                printf "Table ${line} is skipped from deletion as the table is modified recently, computed using downstream_buffer\n" >> $logfile
                                rm -rf /tmp/bq_table_info.txt
                            else 
                                printf "Table ${line} is getting deleted from Bigquery, computed using downstream_buffer\n" >> $logfile
                                bqtabledeletionsize=`bq --format=json  show "$absolutetablename" | jq '.numBytes | tonumber' | head -n 1`
                                bqdeletionsizetotal="$(($bqtabledeletionsize + $bqdeletionsizetotal))"
                                rm -rf /tmp/bq_table_info.txt
                            fi
                        fi
                    else
                        printf "Table ${line} is getting deleted from Bigquery\n" >> $logfile
                        bqtabledeletionsize=`bq --format=json  show "$absolutetablename" | jq '.numBytes | tonumber' | head -n 1`
                        bqdeletionsizetotal="$(($bqtabledeletionsize + $bqdeletionsizetotal))"
                    fi
                else 
                    :
                fi
            done < /tmp/tablesUnderPolicy_${filenamedate}.txt
        else 
            printf "There are no tables to be deleted as per the policy for dataset.table : ${dataset}.${table}\n" >> $logfile
        fi
        rm -rf /tmp/tablesUnderPolicy_${filenamedate}.txt
    fi
done < /eviction/policies/table_deletion_policy.txt

rm -rf /tmp/truetables_${filedate}.txt
printf "Total size of tables deleted from bigquery in bytes : ${bqdeletionsizetotal}\n\n"
printf "########################################################\n"
printf "#################  Printing log file ###################\n"
printf "########################################################\n\n"
cat ${logfile}
