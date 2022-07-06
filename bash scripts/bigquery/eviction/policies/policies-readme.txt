# delete_and_evict
\
Deletes all the tables in the dataset passed as parameter when the table names match the given table name as per the table_name_matches function. 
As the policy name says this will evict the table to Google Cloud Storage and then deletes the table from Big Query.
NOTE : Only give normal and "day" partitioned tables are handled in this policy, tables partitioned with "_PARTITIONTIME" is not handled in this policy.
eg:
Normal tables : dj_activeViews_20200615
Day partitioned tables : newsiq_ad_value.advertiser_value
# delete_no_eviction
\
Deletes all the tables in the dataset passed as parameter when the table names match the given table name as per the table_name_matches function.
As the policy name says this will delete the table from Big Query without evicting it to Google Cloud Storage.
NOTE : Only normal tables are handled in this policy.
Normal tables : dj_activeViews_20200615
# eviction_no_delete
\
Evicts all the tables in the dataset passed as parameter with the retention period.
As the policy name says this will evict the table to Google Cloud Storage but does not delete the table from Big Query.
NOTE : This policy can be applied to normal tables as well as "day" or "_PARTITIONTIME" partitioned tables.

# partitioned_delete_no_eviction
\
Deletes all the tables in the dataset passed as parameter when the table names match the given table name as per the table_name_matches function.
NOTE : Only tables partitioned with "_PARTITIONTIME" is handled in this policy.

