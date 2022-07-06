#!/bin/bash
# Copyright 2019 News Technologies.
# This script kicks off a Cloud Dataflow Apache Beam Job to extract BIG query table into GCS bucket.
# The script is called from inside __init__.py.
# This script must be provided with a flag "-p(poll)" or "-np(no polling)" for polling job status, 
# GCP PROJECT_NAME, GCS BUCKET_NAME, BQ TABLE NAME, BQ DATASET NAME, PYINSTALL(-y for -n for no), 
# PYPATH(python path) in positions arguments 1, 2, 3, 4, 5, 6, 7, 8 and 9 respectively.

# These location needs to be updated based where exactly these folders are located on the server
loglocation=`env | grep NEWSIQ_GCP_EVICTION_LOG_LOCATION | awk -F= {'print $2'}`
policylocation=`env | grep NEWSIQ_GCP_EVICTION_POLICY_LOCATION | awk -F= {'print $2'}`

#Help : Usage Description
if [[ "$1" == "-h" ]]; then
    printf "\n"
	printf "##############################################################################################################################################################\n\n"
    printf "Usage: `basename $0` <-p or -np> <PROJECT_ID> <GCS_BUCKET_NAME> <TABLE NAME> <DATASET NAME> <PYINSTALL (-y or -n )> <PYPATH> <WORKER COUNT> <MAX WORKER COUNT>\n"
	printf "##############################################################################################################################################################\n\n"
	echo "False" > ${jobstatuslocation}
	exit 1
fi

#Input validation
printf "\n"
if [[ -z "$1" ]]; then
		printf "Argument Missing!!\n"
        printf "You need to specify if polling for job status is required or not. Valid values are [-p or -np], for help give [ -h ] as argument\n"
        echo "False" > ${jobstatuslocation}
		exit 1
elif [[ -z "$2" ]]; then 
		printf "Argument Missing!!\n"
        printf "You need to specify the GCP project name as the 2nd argument, for help give [ -h ] as first argument\n"
        echo "False" > ${jobstatuslocation}
		exit 1
elif [[ -z "$3" ]]; then
		printf "Argument Missing!!\n"
        printf "You need to specify the GCS bucket name as the 3rd argument, for help give [ -h ] as first argument\n"
        echo "False" > ${jobstatuslocation}
		exit 1
elif [[ -z "$4" ]]; then
		printf "Argument Missing!!\n"
        printf "You need to specify the table name as the 4th argument, for help give [ -h ] as first argument\n"
        echo "False" > ${jobstatuslocation}
		exit 1
elif [[ -z "$5" ]]; then
		printf "Argument Missing!!\n"
        printf "You need to specify the DATASET name as the 5th argument, for help give [ -h ] as first argument\n"
        echo "False" > ${jobstatuslocation}
		exit 1
elif [[ -z "$6" ]]; then
		printf "Argument Missing!!\n"
        printf "You need to specify if you need to install python 3.6 as the 6th argument, for help give [ -h ] as first argument\n"
        echo "False" > ${jobstatuslocation}
		exit 1
elif [[ -z "$7" ]]; then
		printf "Argument Missing!!\n"
        printf "You need to specify python path as the 7th argument, for help give [ -h ] as first argument\n"
        echo "False" > ${jobstatuslocation}
		exit 1
elif [[ -z "$8" ]]; then
		printf "Argument Missing!!\n"
        printf "You need to specify minimum worker count to start dataflow job as the 8th argument, for help give [ -h ] as first argument\n"
        echo "False" > ${jobstatuslocation}
		exit 1
elif [[ -z "$9" ]]; then
		printf "Argument Missing!!\n"
        printf "You need to specify maximum worker count for the dataflow job as the 9th argument, for help give [ -h ] as first argument\n"
        echo "False" > ${jobstatuslocation}
		exit 1
else 
		:
fi

#Banner for the bash script
printf "\n\n"
printf "//////////////////////////////////////////////////////////////////////////\n"
printf "//////                                             		    //////\n"
printf "//////     STARTING DATAFLOW APACHE BEAM BQ-GCS EXTRACTION JOB      //////\n"
printf "//////                                             		    //////\n"
printf "//////////////////////////////////////////////////////////////////////////\n"

#Function that validates the python3.6 path given by the user
validate_pypath(){
        local givenpath=$1
        verexists=`command -v ${givenpath} 2>&1`
        if [[ -z "$verexists" ]]; then
            echo "The path provided is invalid, please provide a valid python3.6 path!\n"
			echo "False" > ${jobstatuslocation}
            exit 1
        elif [[ ! -z "$verexists" ]]; then
            providedpypath=${verexists}
        else
			:
        fi
}

#Function to install python 3.6	
pyinstall(){
	if [[ "$pyinstall" == true ]]; then
		# Will verify if python 3.6 is available, if not it will be installed.
		pversion=`python --version 2>&1 | cut -f1,2 -d'.' | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]'`
		pypath=`command -v python3.6`
		printf "\nVerifying if python3.6 is available ..........\n\n"
		sleep 5
		if [[ -z $pypath ]]; then
			printf "Unable to find python 3.6.x. Currently Runnning on Python Version : ${pversion}\n"
        	sleep 5
        	printf "Downloading Python 3.6.9 ...........\n"
        	sleep 5
        	wget https://www.python.org/ftp/python/3.6.9/Python-3.6.9.tar.xz
        	printf "\n\nExtracting Python-3.6.9.tar.xz ..........\n"
        	sleep 5
        	tar xJf Python-3.6.9.tar.xz
        	cd Python-3.6.9
        	printf " \n\nConfiguring and installing python 3.6.9 .........."
        	sleep 5
        	./configure
        	make
        	sleep 2
        	make install
        	cd ../
        	rm -rf Python-3.6.9.tar.xz
        	installedpypath=`command -v python3.6`
			printf "\n\nPython3.6 path : ${pypath}"
		else 
        	printf "Good!!! We have python 3.6 Running, you must have missed it. Lets start .........\n\n"
        	installedpypath=`command -v python3.6`
		fi
	fi
}
#Function to print the final job results
job_results() {
	printf "\n\n"
	printf "################## JOB RESULT ##################\n"
	while read line;
		do
			table_name=`echo ${line} | awk -F'table_name:' '{print $2}' | awk -F'|' '{print $1}'`
			dataset_name=`echo ${line} | awk -F'dataset_name:' '{print $2}' | awk -F'|' '{print $1}'`
			job_id=`echo ${line} | awk -F'job_id:' '{print $2}' | awk -F'|' '{print $1}'`
			jobStatus=`echo ${line} | awk -F'job_status:' '{print $2}'`
			printf "\nTABLE NAME : ${table_name}\nDATASET NAME : ${dataset_name}\nJOB ID : ${job_id}\nFINAL JOB STATUS : ${jobStatus}\n"
		done < ${loglocation}/jobStatus.txt
	jobStatusFinal=${jobStatus}
	printf "\n################################################\n\n"
}

#Function for Polling the job status, will be used only if polling is opted while script is triggered.
extractjobstatus() {
	local table_name=$1
	local dataset_name=$2
	local job_id=$3
   	local job_status=$4
	gcloud_job_status=`gcloud --project=${PROJECT_ID} dataflow jobs list --filter="id=${job_id}" --format="get(state)" --region="us-east1"`
	if [[ "$gcloud_job_status" == "Done" ]]; then
		#update Job Completed sucessfully
		sed -i '' -e "s/table_name:${table_name}|dataset_name:${dataset_name}|job_id:${job_id}|job_status:${job_status}/table_name:${table_name}|dataset_name:${dataset_name}|job_id:${job_id}|job_status:Done/g" ${loglocation}/jobStatus.txt										       
	elif [[ "$gcloud_job_status" == "Failed" ]]; then
		#update Job Failure
		sed -i '' -e "s/table_name:${table_name}|dataset_name:${dataset_name}|job_id:${job_id}|job_status:${job_status}/table_name:${table_name}|dataset_name:${dataset_name}|job_id:${job_id}|job_status:Failed/g" ${loglocation}/jobStatus.txt
	elif [[ "$gcloud_job_status" == "Cancelled" ]]; then
		#update Job Cancellation
		sed -i '' -e "s/table_name:${table_name}|dataset_name:${dataset_name}|job_id:${job_id}|job_status:${job_status}/table_name:${table_name}|dataset_name:${dataset_name}|job_id:${job_id}|job_status:Cancelled/g" ${loglocation}/jobStatus.txt
	fi
	
} 

#Setting poll true or false

if [[ "$1" == "-p" ]]; then
	polling=true
	printf "\n\nPolling for Job Is Set to : ${polling}\n"
elif [[ "$1" == "-np" ]]; then
	polling=false
	printf "\n\nPolling for Job Is Set to : ${polling}\n"
fi

#Install python3.6 or provide a valid python3.6 path.
PYPATH=${7}
if [[ "${6}" == "-y" ]]; then
        printf "Install python3.6 is set to : True\n\n"
        pyinstall
		pypath=${installedpypath}
elif [[ "${6}" == "-n" ]]; then
        printf "\n"
        if [[ -z "$PYPATH" ]]; then
                printf "\nPlease Provide a working python3.6 path\n\n"
				echo "False" > ${jobstatuslocation}
                exit 1
        else 
                validate_pypath "${PYPATH}"
				pypath=${providedpypath}
                printf "\n${PYPATH} is valid, and will be used inside the script.\n\n"
        fi
else 
    printf "Please provide a valid input!!\n\n"
	echo "False" > ${jobstatuslocation}
    exit
fi

######################### MAIN PROGRAM STARTS HERE #########################
############################################################################ 
PROJECT_ID=${2}
BUCKET_NAME=${3}
table=${4}
DATASET_NAME=${5}
PYINSTALL=${6}
WORKERCOUNT=${8}
MAXWORKERCOUNT=${9}
warm_up=true
datetime=`date '+%d%m%Y'`
dateandtime=`date '+%Y-%m-%d at %H:%M:%S'`
jobstatuslocation="${loglocation}/jobstatusenv"
# This file needs to be removed before the pipeline starts so that the new status is updated in it,
# which will be used by __init__.py
rm -rf ${jobstatuslocation}
# Iterate for every table specified in tablesList.txt
printf "Starting the Extraction Job using GCP Dataflow Pipeline\n"
tableStripped=`echo ${table} | tr -dc '[:alnum:]\n\r' | tr '[:upper:]' '[:lower:]'`
rand=`/usr/bin/openssl rand -hex 6`
jobName="evictionbigquerytogcs${tableStripped}${rand}"
printf "\n####################\n"
printf "#\n"
printf "# Table in Iteration : ${table}\n"
printf "# Associated Dataset : ${DATASET_NAME}\n"
printf "# GCP Project ID     : ${PROJECT_ID}\n"
printf "# Dataflow Job Name  : ${jobName}\n"
#Submit a Google Cloud Dataflow Apache Beam job for each table.
${PYPATH}  ${policylocation}/bq_table_to_gcs.py --bql "select * from \`${PROJECT_ID}.${DATASET_NAME}.${table}\`" \
--output gs://${BUCKET_NAME}/${DATASET_NAME}/${table}/ \
--project ${PROJECT_ID} \
--job_name ${jobName} \
--staging_location gs://${BUCKET_NAME}/staging_location \
--temp_location gs://${BUCKET_NAME}/temp_location \
--region us-east1 \
--num_workers ${WORKERCOUNT} \
--max_num_workers ${MAXWORKERCOUNT} \
--runner DataflowRunner \
--save_main_session True \
--requirements_file ${policylocation}/requirements.txt >& ${loglocation}/${jobName}.txt
jobId=`cat ${loglocation}/${jobName}.txt |grep  "Created job with id:" | sed -n -e 's/^.*Created job with id: //p' | tr -d '[],'`
sleep 5
printf "# Dataflow Job Id    : ${jobId}\n"
printf "#\n"
printf "####################\n\n"
if [[ -z "$jobId" ]]; then
        printf "\nDataflow job was not triggered due to some reason, please check the logs for more details\n\n"
        echo "False" > ${jobstatuslocation}
        exit 1
else
        :
fi
if [[ "$polling" == true ]]; then
	#Polling for job status is enabled
	printf "table_name:${table}|dataset_name:${DATASET_NAME}|job_id:${jobId}|job_status:Running\n" >> ${loglocation}/jobStatus.txt
fi

if ${warm_up}; then
sleep 10
warm_up=false 
fi
if [[ "$polling" == true ]]; then
	printf "Initiating polling for the Jobs.........\n\n"
	printf "Sleeping for 5 Minutes to start polling, please be patient.\n\n"
	sleep 300
	while read line; 
		do 	
			extractCount=0
			table_name=`echo ${line} | awk -F'table_name:' '{print $2}' | awk -F'|' '{print $1}'`
			dataset_name=`echo ${line} | awk -F'dataset_name:' '{print $2}' | awk -F'|' '{print $1}'`
			job_id=`echo ${line} | awk -F'job_id:' '{print $2}' | awk -F'|' '{print $1}'`
			jobStatus=`echo ${line} | awk -F'job_status:' '{print $2}'`
			extractjobstatus "${table_name}" "${dataset_name}" "${job_id}" "${jobStatus}"
			job_status=${gcloud_job_status}
			((extractcount++))
			if [[ "$job_status" == "Running" ]]; then
				printf "\nJob : ${job_id} is still running, sleeping for 2 minutes to poll again.\n\n"
				sleep 120
				for i in {0..59}
					do
						extractjobstatus "${table_name}" "${dataset_name}" "${job_id}" "${jobStatus}"
						job_status=${gcloud_job_status}
						if [[ "$job_status" == "Running" ]]; then 
							printf "\nJob : ${job_id} is still running, sleeping for 2 minutes to poll again.\n\n"
							sleep 120
							((extractcount++))
						elif [[ "$job_status" == "Done" ]]; then
							echo "True" > ${jobstatuslocation}
							break
						elif [[ "$job_status" == "Cancelled" ]]; then
							echo "False" > ${jobstatuslocation}
							break
						elif  [[ "$job_status" == "Failed" ]]; then
							echo "False" > ${jobstatuslocation}
							break
						elif [[ "$job_status" == "Cancelling" ]]; then
                            printf "\nThe job has been Cancelled by the user, sleeping for 2 minutes for the job to be in Cancelled state.\n"
                            sleep 120
						else
							printf "\nUnknown dataflow job status\n"
						fi
					done
			elif [[ "$job_status" == "Running" ]] && [[ "$extractcount" -gt 59 ]]; then
				printf "\nThis job has been polled ${extractcount} times and has exeecdeed the MAX 2 hours wait time, please monitor the job from Google Coud dataflow GUI : ${job_id}\n\n"
				printf "\n\nThis table will not be deleted from Bigquery, you need to manully delete it once the job extraction job is completed.\n\n"
				echo "False" > ${jobstatuslocation}
			elif [[ "$job_status" == "Cancelled" ]]; then
				echo "False" > ${jobstatuslocation}
			elif  [[ "$job_status" == "Failed" ]]; then
				echo "False" > ${jobstatuslocation}
			elif [[ "$job_status" == "Cancelling" ]]; then
                printf "\nThe job has been Cancelled by the user, sleeping for 2 minutes for the job to be in Cancelled state.\n"
				for i in {0..10}
					do
						sleep 120
						extractjobstatus "${table_name}" "${dataset_name}" "${job_id}" "${jobStatus}"
						job_status=${gcloud_job_status}
						if [[ "$job_status" -ne "Cancelled" ]]; then
							echo "False" > ${jobstatuslocation}
							break
						else
							printf "\nThe job still in Cancelling state, sleeping for 2 minutes for the job to be in Cancelled state.\n"
						fi
					done
			else
				printf "\nLooks like the job completed too soon, something is fishey, please take a look at the job via GUI, the table will not be deleted from Bigquery\n\n"
				echo "False" > ${jobstatuslocation}
			fi 	
		done < ${loglocation}/jobStatus.txt
	job_results
	jobFinalStatus=${jobStatusFinal}
	joberrorstatus=`echo ${jobFinalStatus} | grep 'Cancelled\|Failed\|Running\|Cancelling'`
	if [[ ! -z "$joberrorstatus" ]]; then
		printf "\nThe Job was Unsuccessful.....!!!!!!\nplease refer to the ${loglocation}/${jobName}.txt for more details and delete the log file manually\n"
		printf "DATE : ${dateandtime}       DATASET : ${DATASET_NAME}       TABLE NAME : ${table}         JOB ID : ${job_id}      STATUS : ${jobFinalStatus}\n" >> ${loglocation}/evictionJobs.log
		echo "False" > ${jobstatuslocation}
		rm -rf ${loglocation}/jobStatus.txt
	else 
		printf "\nThe table extraction job from bigquery to GCS was completed sucessfully\n"
        printf "DATE : ${dateandtime}       DATASET : ${DATASET_NAME}       TABLE NAME : ${table}         JOB ID : ${job_id}      STATUS : ${jobFinalStatus}\n" >> ${loglocation}/evictionJobs.log
		echo "True" > ${jobstatuslocation}
		rm -rf ${loglocation}/${jobName}.txt ${loglocation}/jobStatus.txt
	fi
	printf "\n\n"		
fi