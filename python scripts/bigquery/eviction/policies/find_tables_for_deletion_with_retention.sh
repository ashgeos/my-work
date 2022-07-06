#!/bin/bash
#The script will dete the big qyery tables based on the data retention policy set inside the table_deletion_policy.txt
#This script takes one argumentas input that is --dry_run=true or --dry_run=false, 
#if true the script will just show what all tables will be deleted in the log file, if false then the scrip will delete the tables without any user itervention.
#It is always adviced to use --dry_run=true to check the tables that will be deleted, validate and then run it with --dry_run=false

#Input validation
if [[ -z "$1" ]]; then
    printf "The script is missing dry_run argument at position 1, Please provide the same and re-run the script\n"
    exit 1
elif [[ -z "$2" ]]; then
    printf "The script is missing project argument at position 2, Please provide the same and re-run the script\n"
    exit 1
elif [[ -z "$3" ]]; then
    printf "The script is missing downstream_buffer argument at position 3, Please provide the same and re-run the script\n"
    exit 1
elif [[ -z "$4" ]]; then
    printf "The script is missing dataset_id argument at position 4, Please provide the same and re-run the script\n"
    exit 1
elif [[ -z "$5" ]]; then
    printf "The script is missing table_id argument at position 5, Please provide the same and re-run the script\n"
    exit 1
elif [[ -z "$6" ]]; then
    printf "The script is missing retention_period argument at position 6, Please provide the same and re-run the script\n"
    exit 1
elif [[ -z "$7" ]]; then
    printf "The script is missing statuslocation argument at position 7, Please provide the same and re-run the script\n"
    exit 1
elif [[ -z "$8" ]]; then
    printf "The script is missing eviction_policy argument at position 8, Please provide the same and re-run the script\n"
    exit 1
else
    :
fi

#Validates and sets dry_run input argument value 
if [[ "$1" == "true" ]] || [[ "$1" == "True" ]] || [[ "$1" == "TRUE" ]];then
    printf "\n#################################################################\n\n" 
    printf "Dry run is set to true, this script will not delete any tables, will simulate what will be deleted.\n"
    dry_run=1
elif [[ "$1" == "false" ]] || [[ "$1" == "False" ]] || [[ "$1" == "FALSE" ]]; then
    printf "\n#################################################################\n\n"
    printf "Dry run is set to false, this script will delete tables specified in bq-eviction-policy-configmap in gcp.\n"
    dry_run=0
else
    exit 1
fi


#Function to delete only the partitioned tables of big query.
partitioned_delete()
{
    local dataset=${1}
    local table=${2}
    local policy=`echo ${3} | awk -F"@" {'print $1'} | tr -d '[:space:]'`
    local dailyPolicyDays=`echo ${3} | awk -F"@" {'print $2'} | tr -d '[:space:]'`
    local project=${4}
    #if policy is daily and has number of partioned x days to be evictied to GCS
    if [[ "$policy" == "daily" ]] && [[ -n "$dailyPolicyDays" ]]; then
        partColumn=$(bq query --nouse_legacy_sql --format=prettyjson  'SELECT * FROM `'${project}'.'${dataset}'.INFORMATION_SCHEMA.COLUMNS` where table_name="'${table}'" and is_partitioning_column="YES" ' | jq '.[].column_name' | tail -c +2 | head -c -2 )
        bq query --nouse_legacy_sql --format=csv --max_rows=100000 'select '${partColumn}' as day from `'${project}'.'${dataset}'.'${table}'` group by 1 order by 1 desc ' | grep -v day | sed '/^[[:space:]]*$/d' > /tmp/temppartitionedtable_${filenamedate}.txt
        error=`cat /tmp/temppartitionedtable_${filenamedate}.txt | grep "Not found" | wc -l`
        if [[ "$error" -gt 0 ]]; then
            printf "Table ${table} does not exist in dataset ${dataset}\n" >> $logfile
            printf "${table}:no_tables_to_delete\n" >> ${statuslocation}
            rm -rf /tmp/temppartitionedtable_${filenamedate}.txt
        else
            cat /tmp/temppartitionedtable_${filenamedate}.txt | sort | awk -F, {'print $1'} | head -n -${dailyPolicyDays} > /tmp/partitionedtable_${filenamedate}.txt
            pcount=`cat /tmp/partitionedtable_${filenamedate}.txt |  wc -l`
            if [[ "$pcount" -eq 0 ]]; then
                printf "The policy set is to retain ${dailyPolicyDays} days of partitoned data, and the table contains ${dailyPolicyDays} partitioned days hence nothing to do\n" >> $logfile
                printf "Number of Partitioned tables to be deleted for dataset : ${dataset} and table : ${table} is ${pcount}\n" >> $logfile
                printf "${table}:no_tables_to_delete\n" >> ${statuslocation}
                rm -rf /tmp/temppartitionedtable_${filenamedate}.txt /tmp/partitionedtable_${filenamedate}.txt
            elif [[ "$pcount" -gt 0 ]]; then
                printf "The policy is to retain table data upto "$dailyPolicyDays" days of partitioned data\n" >> $logfile
                printf "Number of Partitioned tables to be evicted and deleted for dataset : ${dataset} and table : ${table} is ${pcount}\n" >> $logfile
                while read line;
                do
                bqtabledeletionsize="0"
                absolutetablename="${project}:${dataset}.${table}"
                tabledate=`echo "$line" | awk -F" " {'print $1'} | sed 's/-//g'`
                if [[ "$dry_run" == 0 ]]; then
                    printf "Partition ${line} of table ${absolutetablename} is identified for this activity.\n" >> $logfile
                    bqtabledeletionsize=`bq --format=json  show ""$absolutetablename"$"$tabledate"" | jq '.numBytes | tonumber' | head -n 1`
                    bqdeletionsizetotal="$(($bqtabledeletionsize + $bqdeletionsizetotal))"
                    lineformatted=`echo "${tabledate}" | tr -d '[:space:]'`
                    printf ""$table"$"$lineformatted":evictAndDeletePartitioned\n" >> ${statuslocation}
                    rm -rf /tmp/temppartitionedtable_${filenamedate}.txt
                elif [[ "$dry_run" == 1 ]]; then
                    printf "dry_run : Partition ${line} of table ${absolutetablename} is identified for this activity.\n" >> $logfile 
                    bqtabledeletionsize=`bq --format=json  show ""$absolutetablename"$"$tabledate"" | jq '.numBytes | tonumber' | head -n 1`
                    bqdeletionsizetotal="$(($bqtabledeletionsize + $bqdeletionsizetotal))"
                    lineformatted=`echo "${tabledate}" | tr -d '[:space:]' `
                    printf ""$table"$"$lineformatted":dry_run\n" >> ${statuslocation}
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
    #if policy is daily and need the entire partioned table to be evictied to GCS
    elif [[ "$policy" == "daily" ]] && [[ -z "$dailyPolicyDays" ]]; then
        printf "The policy is to backup ${dataset}.${table} partitioned table daily.\n" >> $logfile
        bqtabledeletionsize="0"
        absolutetablename="${project}:${dataset}.${table}"
        bqtabledeletionsize=`bq --format=json  show "$absolutetablename" | jq '.numBytes | tonumber' | head -n 1`
        bqdeletionsizetotal="$(($bqtabledeletionsize + $bqdeletionsizetotal))"
        if [[ "$dry_run" == 1 ]]; then
            printf "${table}:dry_run\n" >> ${statuslocation}
        elif [[ "$dry_run" == 0 ]]; then
            printf "${table}:backuponlyPartitioned\n" >> ${statuslocation}
        else
            :
        fi
    #if policy is a number of days and has needs x days of partioned data to be deleted from BQ
    else
        partColumn=$(bq query --nouse_legacy_sql --format=prettyjson  'SELECT * FROM `'${project}'.'${dataset}'.INFORMATION_SCHEMA.COLUMNS` where table_name="'${table}'" and is_partitioning_column="YES" ' | jq '.[].column_name' | tail -c +2 | head -c -2 )
        bq query --nouse_legacy_sql --format=csv  'select '${partColumn}' as day, count(*) cnt from `'${project}'.'${dataset}'.'${table}'` group by 1 order by 1 desc ' |  sed "2 d" | sed '/^[[:space:]]*$/d' > /tmp/temppartitionedtable_${filenamedate}.txt
        error=`cat /tmp/temppartitionedtable_${filenamedate}.txt | grep "Not found" | wc -l`
        if [[ "$error" -gt 0 ]]; then
            printf "Table ${table} does not exist in dataset ${dataset}\n" >> $logfile
            printf "${table}:no_tables_to_delete\n" >> ${statuslocation}
            rm -rf /tmp/temppartitionedtable_${filenamedate}.txt
        else
            cat /tmp/temppartitionedtable_${filenamedate}.txt | sort | awk -F, {'print $1'} | head -n -${policy} > /tmp/partitionedtable_${filenamedate}.txt
            pcount=`cat /tmp/partitionedtable_${filenamedate}.txt |  wc -l`
            if [[ "$pcount" -eq 0 ]]; then
                printf "The policy is to retain table data upto ${policy} days\n" >> $logfile
                printf "Number of Partitioned tables to be deleted for dataset : ${dataset} and table : ${table} is ${pcount}\n" >> $logfile
                printf "${table}:no_tables_to_delete\n" >> ${statuslocation}
                rm -rf /tmp/temppartitionedtable_${filenamedate}.txt /tmp/partitionedtable_${filenamedate}.txt
            elif [[ "$pcount" -gt 0 ]]; then
                printf "The policy is to retain table data upto "$policy" days\n" >> $logfile
                printf "Number of Partitioned tables to be deleted for dataset : ${dataset} and table : ${table} is ${pcount}\n" >> $logfile
                while read line;
                do
                bqtabledeletionsize="0"
                absolutetablename="${project}:${dataset}.${table}"
                tabledate=`echo "$line" | awk -F" " {'print $1'} | sed 's/-//g'`

                if [[ "$dry_run" == 0 ]]; then
                    printf "Partition ${line} of table ${absolutetablename} will be deteted.\n" >> $logfile
                    bqtabledeletionsize=`bq --format=json  show ""$absolutetablename"$"$tabledate"" | jq '.numBytes | tonumber' | head -n 1`
                    bqdeletionsizetotal="$(($bqtabledeletionsize + $bqdeletionsizetotal))"
                    bq query --nouse_legacy_sql --format=csv 'delete from `'${project}'.'${dataset}'.'${table}'`  where _PARTITIONTIME = "'${line}'" '
                    lineformatted=`echo "${line}" | sed -r 's/[:]+/-/g' | sed -r 's/[ ]+/-/g' | tr -d '[:space:]' `
                    printf "${table}.${lineformatted}:deleted\n" >> ${statuslocation}
                    rm -rf /tmp/temppartitionedtable_${filenamedate}.txt
                elif [[ "$dry_run" == 1 ]]; then
                    printf "Partition ${line} of table ${absolutetablename} will be deteted.\n" >> $logfile 
                    bqtabledeletionsize=`bq --format=json  show ""$absolutetablename"$"$tabledate"" | jq '.numBytes | tonumber' | head -n 1`
                    bqdeletionsizetotal="$(($bqtabledeletionsize + $bqdeletionsizetotal))"
                    lineformatted=`echo "${line}" | sed -r 's/[:]+/-/g' | sed -r 's/[ ]+/-/g' | tr -d '[:space:]' `
                    printf "${table}.${lineformatted}:dry_run\n" >> ${statuslocation}
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

#stores the log files location
logfile="/tmp/bqtable_deletion_`date +%Y%m%dT%H%M%S`.log"
filenamedate=`date +%Y%m%dT%H%M%S`
mkdir -p $7
statuslocation=$7/deletionjobstatusenv
rm -rf ${statuslocation} ${tablelistlocation}
touch ${statuslocation} ${tablelistlocation}
printf "Please go through the ${logfile} file to see what the script performed.\n"
touch /tmp/truetables_${filenamedate}.txt

#Assigning script inputs
project=$2
downstream_buffer=$3
dataset=$4
table=$5
policy=$6
eviction_policy=$8

printf "The downstream buffer set to ${downstream_buffer} days if applicable.\n" >> ${logfile} 

#Activates service account only if none is activated
gcloudAuthActive=`gcloud config get-value account | grep "compute@developer.gserviceaccount.com"| wc -l`
if [[ "$gcloudAuthActive" == 1 ]]; then
    gcloud auth activate-service-account --key-file=/secrets/gcp/credentials.json --project=${project}
else
    :
fi

partionedType=`bq show  --format=prettyjson ${project}:${dataset}.${table} | grep timePartitioning | wc -l | tr -d '[:space:]' `
bqdeletionsizetotal=0

#This part of the script will take care of partitioned tables and normal tables
if [[ "$partionedType" == 1 ]]; then
    partitioned_delete ${dataset} ${table} ${policy} ${project}
else
    bq ls --max_results=100000 "${dataset}" | grep "${table}" |  awk {'print $1'} > /tmp/temptables_${filenamedate}.txt
    if [[ $table = *_ ]]; then
        scounttable=`echo -n ${table} | wc -c`
        sncounttable=`expr $scounttable + 8`
        while read line;
        do
            stringcounttable=`echo -n ${line} | wc -c`
            if [[ "$stringcounttable" == "$sncounttable" ]]; then
                printf "${line}\n" >> /tmp/truetables_${filenamedate}.txt
            else
                :
            fi
        done < /tmp/temptables_${filenamedate}.txt
    else
        cat /tmp/temptables_${filenamedate}.txt > /tmp/truetables_${filenamedate}.txt
    fi
    totalCount=`cat /tmp/truetables_${filenamedate}.txt | wc -l`
    printf "The total number of tables in ${dataset}.${table} is ${totalCount}\n" >> $logfile
    if [[ "$policy" == "daily" ]]; then
        printf "The policy is to entirely backup ${dataset}.${table} daily.\n" >> $logfile
        if [[ "$dry_run" == 0 ]]; then
            while read line;
            do
                printf "${line}:backuponlyNormal\n" >> ${statuslocation}
            done < /tmp/truetables_${filenamedate}.txt
        elif [[ "$dry_run" == 1 ]]; then
            while read line;
            do
                printf "${line}:dry_run\n" >> ${statuslocation}
            done < /tmp/truetables_${filenamedate}.txt
        else
            :
        fi
        rm -rf /tmp/truetables_${filenamedate}.txt /tmp/temptables_${filenamedate}.txt
    else
        printf "The policy is to retain table data upto ${policy} days\n" >> $logfile
        cat /tmp/truetables_${filenamedate}.txt | head -n -${policy} > /tmp/tablesUnderPolicy_${filenamedate}.txt
        count=`cat /tmp/tablesUnderPolicy_${filenamedate}.txt | wc -l`
        printf "Number of tables to be deleted for dataset : ${dataset} and table : ${table} is ${count}\n" >> $logfile
        if [[ "$count" -gt 0 ]]; then
            rm -rf /tmp/truetables_${filenamedate}.txt /tmp/temptables_${filenamedate}.txt
            while read line;
            do
                if [[ "$dry_run" == 0 ]]; then
                    bqtabledeletionsize="0"
                    absolutetablename="${project}:${dataset}.${line}"
                    if [[ "$dataset" == "ash_dfp" ]] || [[ "$dataset" == "ash_pixel" ]] || [[ "$dataset" == "ash_prebid" ]] || [[ "$dataset" == "ash_ad_value" ]] ; then 
                        if [[ "$downstream_buffer" == 0 ]]; then
                            bqtabledeletionsize=`bq --format=json  show "$absolutetablename" | jq '.numBytes | tonumber' | head -n 1`
                            bqdeletionsizetotal="$(($bqtabledeletionsize + $bqdeletionsizetotal))"
                            printf "${line}:true\n" >> ${statuslocation}
                        else      
                            temp_downstream_buffer_date=`date --date="${downstream_buffer} days ago" '+%Y-%m-%d %H:%M:%S'`
                            downstream_buffer_date=`date +%s -d"$temp_downstream_buffer_date"`
                            bq query --nouse_legacy_sql --format=prettyjson 'SELECT *REPLACE(TIMESTAMP_MILLIS(last_modified_time) AS last_modified_time), FROM `'${project}'.'${dataset}'.__TABLES__` where table_id = "'${line}'" ' > /tmp/bq_table_info.txt 
                            temp_last_modified_date=`cat /tmp/bq_table_info.txt | grep last_modified_time | awk -F"last_modified_time" {'print $2'} | awk -F": " {'print $2'} | sed 's/\"//g' | sed 's/\,//g'`
                            last_modified_date=`date +%s -d"$temp_last_modified_date"`
                            if [[ "$last_modified_date" -gt "$downstream_buffer_date" ]]; then
                                printf "${line}:skipped\n" >> ${statuslocation}
                                rm -rf /tmp/bq_table_info.txt
                            else 
                                bqtabledeletionsize=`bq --format=json  show "$absolutetablename" | jq '.numBytes | tonumber' | head -n 1`
                                bqdeletionsizetotal="$(($bqtabledeletionsize + $bqdeletionsizetotal))"
                                printf "${line}:true\n" >> ${statuslocation}
                                rm -rf /tmp/bq_table_info.txt
                            fi
                        fi
                    else
                        bqtabledeletionsize=`bq --format=json  show "$absolutetablename" | jq '.numBytes | tonumber' | head -n 1`
                        bqdeletionsizetotal="$(($bqtabledeletionsize + $bqdeletionsizetotal))"
                        printf "${line}:true\n" >> ${statuslocation}
                    fi
                elif [[ "$dry_run" == 1 ]]; then
                    bqtabledeletionsize="0"
                    absolutetablename="${project}:${dataset}.${line}"
                    if [[ "$dataset" == "ash_dfp" ]] || [[ "$dataset" == "ash_pixel" ]] || [[ "$dataset" == "ash_prebid" ]] || [[ "$dataset" == "ash_ad_value" ]]; then 
                        if  [[ "$downstream_buffer" == 0 ]]; then
                            bqtabledeletionsize=`bq --format=json  show "$absolutetablename" | jq '.numBytes | tonumber' | head -n 1`
                            bqdeletionsizetotal="$(($bqtabledeletionsize + $bqdeletionsizetotal))"
                            printf "${line}:dry_run\n" >> ${statuslocation}
                        else
                            temp_downstream_buffer_date=`date --date="${downstream_buffer} days ago" '+%Y-%m-%d %H:%M:%S'`
                            downstream_buffer_date=`date +%s -d"$temp_downstream_buffer_date"`
                            bq query --nouse_legacy_sql --format=prettyjson 'SELECT *REPLACE(TIMESTAMP_MILLIS(last_modified_time) AS last_modified_time), FROM `'${project}'.'${dataset}'.__TABLES__` where table_id = "'${line}'" ' > /tmp/bq_table_info.txt 
                            temp_last_modified_date=`cat /tmp/bq_table_info.txt | grep last_modified_time | awk -F"last_modified_time" {'print $2'} | awk -F": " {'print $2'} | sed 's/\"//g' | sed 's/\,//g'`
                            last_modified_date=`date +%s -d"$temp_last_modified_date"`
                            printf "Last modifed date ${temp_last_modified_date}\n"
                            if [[ "$last_modified_date" -gt "$downstream_buffer_date" ]]; then
                                printf "${line}:skipped\n" >> ${statuslocation}
                                rm -rf /tmp/bq_table_info.txt
                            else 
                                bqtabledeletionsize=`bq --format=json  show "$absolutetablename" | jq '.numBytes | tonumber' | head -n 1`
                                bqdeletionsizetotal="$(($bqtabledeletionsize + $bqdeletionsizetotal))"
                                printf "${line}:dry_run\n" >> ${statuslocation}
                                rm -rf /tmp/bq_table_info.txt
                            fi
                        fi
                    else
                        bqtabledeletionsize=`bq --format=json  show "$absolutetablename" | jq '.numBytes | tonumber' | head -n 1`
                        bqdeletionsizetotal="$(($bqtabledeletionsize + $bqdeletionsizetotal))"
                        printf "${line}:dry_run\n" >> ${statuslocation}
                    fi
                else 
                    :
                fi
            done < /tmp/tablesUnderPolicy_${filenamedate}.txt
        else
            printf "${table}:no_tables_to_delete\n" >> ${statuslocation}
            rm -rf /tmp/truetables_${filenamedate}.txt /tmp/temptables_${filenamedate}.txt /tmp/bq_table_last_mod_info.txt /tmp/bq_table_exp_date.txt
        fi
    fi
    rm -rf /tmp/tablesUnderPolicy_${filenamedate}.txt
fi

rm -rf /tmp/truetables_${filenamedate}.txt 
if [[ "$dry_run" == 0 ]]; then
    printf "Total size of tables deleted from bigquery in bytes : ${bqdeletionsizetotal} for dataset : ${dataset} and table : ${table} using policy : BQ_${eviction_policy}\n"
else 
    printf "Dry Run : Tables deleted from bigquery in bytes : ${bqdeletionsizetotal} for dataset : ${dataset} and table : ${table} using policy : BQ_${eviction_policy}\n"
fi
cat ${logfile}