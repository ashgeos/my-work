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
else
    :
fi

#Validates and sets dry_run input argument value 
if [[ "$1" == "true" ]] || [[ "$1" == "True" ]] || [[ "$1" == "TRUE" ]];then
    printf "Dry run is set to true, this script will not delete any tables, will simulate what will be deleted, please check ${logfile} to know more\n"
    dry_run=1
elif [[ "$1" == "false" ]] || [[ "$1" == "False" ]] || [[ "$1" == "FALSE" ]]; then
    printf "Dry run is set to false, this script will delete tables specified in table_deletion_policy.txt based on the policy,please check ${logfile} to know more\n"
    dry_run=0
else
    exit 1
fi


#Function to delete only the partitioned tables of big query.
partitioned_delete()
{
    local dataset=${1}
    local table=${2}
    local policy=${3}
    local project=${4}
    bq query --nouse_legacy_sql --format=csv  'select _PARTITIONTIME as day, count(*) cnt from `'${project}'.'${dataset}'.'${table}'` group by 1 order by 1 desc ' | sed "1 d" > /tmp/temppartitionedtable_${filenamedate}.txt
    error=`cat /tmp/temppartitionedtable_${filenamedate}.txt | grep "Not found" | wc -l`
    if [[ "$error" -gt 0 ]]; then
	    printf "\n#################################################################\n\n" >> $logfile
        printf "Table ${table} does not exist in dataset ${dataset}\n" >> $logfile
        printf "${line}:no_tables_to_delete\n" >> ${statuslocation}
        rm -rf /tmp/temppartitionedtable_${filenamedate}.txt
    else
        cat /tmp/temppartitionedtable_${filenamedate}.txt | sort | awk -F, {'print $1'} | head -n -${policy} > /tmp/partitionedtable_${filenamedate}.txt
        pcount=`cat /tmp/partitionedtable_${filenamedate}.txt |  wc -l`
        if [[ "$pcount" -eq 0 ]]; then
            printf "\n#################################################################\n\n" >> $logfile
            printf "The policy is to retain table data upto ${policy} days\n" >> $logfile
            printf "Number of Partitioned tables to be deleted for dataset : ${dataset} and table : ${table} is ${pcount}\n" >> $logfile
            printf "${table}:no_tables_to_delete\n" >> ${statuslocation}
            rm -rf /tmp/temppartitionedtable_${filenamedate}.txt /tmp/partitionedtable_${filenamedate}.txt
        elif [[ "$pcount" -gt 0 ]]; then
            printf "\n#################################################################\n\n" >> $logfile
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
                printf "${line}:true\n" >> ${statuslocation}
                rm -rf /tmp/temppartitionedtable_${filenamedate}.txt
            elif [[ "$dry_run" == 1 ]]; then
                printf "Partition ${line} of table ${absolutetablename} will be deteted.\n" | tee -a $logfile 
                bqtabledeletionsize=`bq --format=json  show ""$absolutetablename"$"$tabledate"" | jq '.numBytes | tonumber' | head -n 1`
                bqdeletionsizetotal="$(($bqtabledeletionsize + $bqdeletionsizetotal))"
                printf "${table}:dry_run\n" >> ${statuslocation}
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
}

#The main script starts here

#stores the log files location
logfile="/tmp/bqtable_deletion_`date +%Y%m%dT%H%M%S`.log"
filenamedate=`date +%Y%m%dT%H%M%S`
mkdir -p $7
statuslocation=$7/deletionjobstatusenv
rm -rf ${statuslocation}
touch ${statuslocation}
printf "Please go through the ${logfile} file to see what the script performed.\n"
touch /tmp/truetables_${filenamedate}.txt

#Assigning script inputs
project=$2
downstream_buffer=$3
dataset=$4
table=$5
policy=$6
#Activates service account only if none is activated
gcloudAuthActive=`gcloud config get-value account | grep "compute@developer.gserviceaccount.com"| wc -l`
if [[ "$gcloudAuthActive" == 1 ]]; then
    gcloud auth activate-service-account --key-file=/secrets/gcp/credentials.json --project=${project}
else
    :
fi

partionedType=`bq show  --format=prettyjson ${project}:${dataset}.${table} | grep timePartitioning | wc -l`
bqdeletionsizetotal=0
#This part of the script will take care of partitioned tables and normal tables
if [[ "$partionedType" == 1 ]]; then
    partitioned_delete ${dataset} ${table} ${policy} ${project}
else
    bq ls --max_results=100000 "${dataset}" | grep "${table}" |  awk {'print $1'} > /tmp/temptables_${filenamedate}.txt
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
    printf "\n#################################################################\n\n" >> $logfile
    totalCount=`cat /tmp/truetables_${filenamedate}.txt | wc -l`
    printf "The total number of tables in ${dataset}.${table} is ${totalCount}\n" >> $logfile
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
                if [[ "$dataset" == "newsiq_dfp" ]]; then
                    temp_downstream_buffer_date=`date --date="${downstream_buffer} days ago" '+%Y-%m-%d %H:%M:%S'`
                    downstream_buffer_date=`date +%s -d"$temp_downstream_buffer_date"`
                    bq query --nouse_legacy_sql --format=prettyjson 'SELECT *REPLACE(TIMESTAMP_MILLIS(last_modified_time) AS last_modified_time), FROM `'${project}'.'${dataset}'.__TABLES__` where table_id = "'${line}'" ' > /tmp/bq_table_info.txt 
                    temp_last_modified_date=`cat /tmp/bq_table_info.txt | grep last_modified_time | awk -F"last_modified_time" {'print $2'} | awk -F": " {'print $2'} | sed 's/\"//g' | sed 's/\,//g'`
                    last_modified_date=`date +%s -d"$temp_last_modified_date"`
                    if [[ "$last_modified_date" -gt "$downstream_buffer_date" ]]; then
                        printf "Table ${line} is skipped from deletion as the table is modified recently, computed using downstream_buffer\n" >> $logfile
                        printf "${line}:false\n" >> ${statuslocation}
                        rm -rf /tmp/bq_table_info.txt
                    else 
                        printf "Table ${line} is getting deleted from Bigquery, computed using downstream_buffer\n" >> $logfile
                        bqtabledeletionsize=`bq --format=json  show "$absolutetablename" | jq '.numBytes | tonumber' | head -n 1`
                        bqdeletionsizetotal="$(($bqtabledeletionsize + $bqdeletionsizetotal))"
                        bq rm -f -t ${project}:${dataset}.${line}
                        deletionstatus=`bq show ${project}:${dataset}.${line} | grep "Not found" | wc -l`
                        if [[ ${deletionstatus} == 0 ]]; then
                            printf "${line}:true\n" >> ${statuslocation}
                        elif [[ ${deletionstatus} == 0 ]]; then
                            printf "${line}:false\n" >> ${statuslocation}
                        else
                            :
                        fi
                        rm -rf /tmp/bq_table_info.txt
                    fi
                else
                    printf "Table ${line} is getting deleted from Bigquery\n" >> $logfile
                    bqtabledeletionsize=`bq --format=json  show "$absolutetablename" | jq '.numBytes | tonumber' | head -n 1`
                    bqdeletionsizetotal="$(($bqtabledeletionsize + $bqdeletionsizetotal))"
                    bq rm -f -t ${project}:${dataset}.${line}
                    deletionstatus=`bq show ${project}:${dataset}.${line} | grep "Not found" | wc -l`
                        if [[ ${deletionstatus} == 1 ]]; then
                            printf "${line}:true\n" >> ${statuslocation}
                        elif [[ ${deletionstatus} == 0 ]]; then
                            printf "${line}:false\n" >> ${statuslocation}
                        else
                            :
                        fi
                fi
            elif [[ "$dry_run" == 1 ]]; then
                bqtabledeletionsize="0"
                absolutetablename="${project}:${dataset}.${line}"
                if [[ "$dataset" == "newsiq_dfp" ]]; then
                    temp_downstream_buffer_date=`date --date="${downstream_buffer} days ago" '+%Y-%m-%d %H:%M:%S'`
                    downstream_buffer_date=`date +%s -d"$temp_downstream_buffer_date"`
                    bq query --nouse_legacy_sql --format=prettyjson 'SELECT *REPLACE(TIMESTAMP_MILLIS(last_modified_time) AS last_modified_time), FROM `'${project}'.'${dataset}'.__TABLES__` where table_id = "'${line}'" ' > /tmp/bq_table_info.txt 
                    temp_last_modified_date=`cat /tmp/bq_table_info.txt | grep last_modified_time | awk -F"last_modified_time" {'print $2'} | awk -F": " {'print $2'} | sed 's/\"//g' | sed 's/\,//g'`
                    last_modified_date=`date +%s -d"$temp_last_modified_date"`
                    printf "Last modifed date ${temp_last_modified_date}\n"
                    if [[ "$last_modified_date" -gt "$downstream_buffer_date" ]]; then
                        printf "Table ${line} is skipped from deletion as the table is modified recently, computed using downstream_buffer\n" >> $logfile
                        printf "${line}:skipped\n" >> ${statuslocation}
                        rm -rf /tmp/bq_table_info.txt
                    else 
                        printf "Table ${line} is getting deleted from Bigquery, computed using downstream_buffer\n" >> $logfile
                        bqtabledeletionsize=`bq --format=json  show "$absolutetablename" | jq '.numBytes | tonumber' | head -n 1`
                        bqdeletionsizetotal="$(($bqtabledeletionsize + $bqdeletionsizetotal))"
                        printf "${line}:dry_run\n" >> ${statuslocation}
                        rm -rf /tmp/bq_table_info.txt
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
        printf "${table}:no_tables_to_delete\n" >> ${statuslocation}
        rm -rf /tmp/truetables_${filenamedate}.txt /tmp/temptables_${filenamedate}.txt /tmp/bq_table_last_mod_info.txt /tmp/bq_table_exp_date.txt
    fi
    rm -rf /tmp/tablesUnderPolicy_${filenamedate}.txt
fi

rm -rf /tmp/truetables_${filenamedate}.txt 
printf "Total size of tables deleted from bigquery in bytes : ${bqdeletionsizetotal}\n\n"
cat ${logfile}
printf "\n#################################################################\n\n"