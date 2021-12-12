#!/bin/bash

# Created by Julia Kisielewicz on 12.12.2021

# This script provides automation of downloading file from URL, verifying the correctness of the file and inserting data to PostgreSQL database.
# It also sends report about data via email.
# Then it finds the best customers (using distance from given location) and sends their names as compressed csv file via email.



# 12.12.2021
# - Added: Check correctness and log events
# - Updated: Standardize variable names

# 09.12.2021
# - Added: Execute SQL operations
# - Added: Send emails

# 05.12.2021
# - Added: Download and verify file
# - Added: Prepare variables



#Variables
WORKSPACE=`pwd`
INDEX_NR=402445
TIMESTAMP=`date "+%m%d%Y"`
TIMESTAMP_PRECISE=`date "+%H%M%S/%m%d%Y"`
FILE_URL=https://home.agh.edu.pl/~wsarlej/Customers_Nov2021.zip
ARCHIVE_PASSWORD="agh"

#SQL variables
HOSTNAME="localhost"
USER_ID="postgres"
PASSWORD="postgres"
DATABASE="customers"
PSQL_PARAM="postgresql://${USER_ID}:${PASSWORD}@${HOSTNAME}/${DATABASE}"
TABLENAME_C="customers_${INDEX_NR}"
TABLENAME_BC="best_customers_${INDEX_NR}"

#Filenames
ARCHIVE=`basename ${FILE_URL}`
NAME=`basename ${FILE_URL} .zip`
FILE="${NAME}.csv"
OLD="Customers_old.csv"
BAD="${NAME}.bad_${TIMESTAMP}"
TMP="tmp.csv" #TODO
PROCESSED="PROCESSED"
LOG="${WORKSPACE}/${PROCESSED}/$(basename "$0")_${TIMESTAMP}.log"


#Preparing subfolder and log
mkdir ${WORKSPACE}/${PROCESSED}
if [ -e ${LOG} ]
then
	rm ${LOG}
fi
touch ${LOG}


#Downloading and unzipping file
wget ${FILE_URL}
unzip -P ${ARCHIVE_PASSWORD} ${ARCHIVE}

if [ "$?" -eq "0" ]
then
	echo "${TIMESTAMP_PRECISE} - Downloading and unzipping - Successful" >> ${LOG}
fi


#Removing empty lines
rows_count_before=`tail +2 ${FILE} | wc -l`
sed -i -e '/^$/w '${BAD}'' -e '//d' ${FILE}

if [ "$?" -eq "0" ]
then
	echo "${TIMESTAMP_PRECISE} - Removing empty lines from file - Successful" >> ${LOG}
fi


#Removing duplicates
sort ${FILE} ${OLD} | uniq -d >> ${BAD}
head -n 1 ${FILE} > ${TMP}
comm -1 -3 <(sort ${OLD}) <(sort ${FILE}) >> ${TMP}
cat ${TMP} > ${FILE}

if [ "$?" -eq "0" ]
then
	echo "${TIMESTAMP_PRECISE} - Removing duplicates from file - Successful" >> ${LOG}
fi

rm ${TMP}


#Preparing SQL table
psql ${PSQL_PARAM} -c "\connect ${DATABASE}"
psql ${PSQL_PARAM} -c "CREATE EXTENSION IF NOT EXISTS postgis;"
psql ${PSQL_PARAM} -c "CREATE TABLE IF NOT EXISTS ${TABLENAME_C}(first_name VARCHAR(50), last_name VARCHAR(50), email VARCHAR(50), lat NUMERIC(8,6), long NUMERIC(9,6));"

if [ "$?" -eq "0" ]
then
	echo "${TIMESTAMP_PRECISE} - Creating table ${TABLENAME_C} - Successful" >> ${LOG}
fi

rows=`psql -X -A ${PSQL_PARAM} -t -c "SELECT COUNT(*) FROM ${TABLENAME_C};"`

if [ "${rows}" = 0 ]
then
        psql ${PSQL_PARAM} -c "\copy ${TABLENAME_C} FROM ${FILE} delimiter ',' csv header;"

	if [ "$?" -eq "0" ]
	then
		echo "${TIMESTAMP_PRECISE} - Inserting data from CSV file to the table ${TABLENAME_C} - Successful" >> ${LOG}
	fi

	psql ${PSQL_PARAM} -c "ALTER TABLE ${TABLENAME_C} ADD COLUMN geom GEOMETRY(POINT, 4326);"
        psql ${PSQL_PARAM} -c "UPDATE ${TABLENAME_C} SET geom = ST_SetSRID(ST_MakePoint(long, lat), 4326);"

	if [ "$?" -eq "0" ]
	then
		echo "${TIMESTAMP_PRECISE} - Calculating geometry from longitude and latitude - Successful" >> ${LOG}
	fi

        rows=`psql -X -A ${PSQL_PARAM} -t -c "SELECT COUNT(*) FROM ${TABLENAME_C};"`
fi

columns=`psql -X -A ${PSQL_PARAM} -t -c "SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_CATALOG = '${DATABASE}' AND TABLE_NAME = '${TABLENAME_C}';"`

#Moving to subfolder
mv ${FILE} "${PROCESSED}/${TIMESTAMP}_${FILE}"

if [ "$?" -eq "0" ]
then
	echo "${TIMESTAMP_PRECISE} - Moving file to PROCESSED folder - Successful" >> ${LOG}
fi

FILE="${PROCESSED}/${TIMESTAMP}_${FILE}"


#Sending email
msg_body="
                Number of rows in original file: ${rows_count_before}\n
                Number of correct rows: `tail +2 ${FILE} | wc -l`\n
                Number of duplicates: ` echo $(grep -c -v '^$' ${BAD}) - 1 | bc`\n
                Amount of data loaded to table ${TABLENAME_C}: ` echo ${rows} \* ${columns} | bc `"

echo -e ${msg_body} | mailx -s "CUSTOMERS LOAD - ${TIMESTAMP}" kisielewicz.tmp@gmail.com

if [ "$?" -eq "0" ]
then
	echo "${TIMESTAMP_PRECISE} - Sending first email - Successful" >> ${LOG}
fi


#Executing query to find the best customers
psql ${PSQL_PARAM} -c "DROP TABLE IF EXISTS ${TABLENAME_BC};"

query="
SELECT first_name, last_name INTO ${TABLENAME_BC} FROM ${TABLENAME_C}
        WHERE ST_DistanceSpheroid(
                geom,
                ST_GeomFromText('POINT(-75.67329768604034 41.39988501005976)',4326),
                'SPHEROID["\""WGS 84"\"",6378137,298.257223563]')
             < 50000;"

psql ${PSQL_PARAM} -c "${query}"

if [ "$?" -eq "0" ]
then
	echo "${TIMESTAMP_PRECISE} - Creating table ${TABLENAME_BC} - Successful" >> ${LOG}
fi


#Exporting to CSV
psql ${PSQL_PARAM} -c "\copy ${TABLENAME_BC} to '"${TABLENAME_BC}.csv"' csv header;"
zip "${TABLENAME_BC}.zip" "${TABLENAME_BC}.csv"

if [ "$?" -eq "0" ]
then
	echo "${TIMESTAMP_PRECISE} - Exporting and compressing table ${TABLENAME_BC} to CSV file - Successful" >> ${LOG}
fi

#Sending second email
msg_body="
                Creation date: ${TIMESTAMP}\n
                Number of rows: `tail +2 "${TABLENAME_BC}.csv" | wc -l`"

echo -e ${msg_body} | mailx -A "${TABLENAME_BC}.zip" -s "BEST CUSTOMERS - ${TIMESTAMP}" kisielewicz.tmp@gmail.com

if [ "$?" -eq "0" ]
then
	echo "${TIMESTAMP_PRECISE} - Sending second email - Successful" >> ${LOG}
fi
