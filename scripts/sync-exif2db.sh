#!/bin/bash

########################################################################################
## SETTINGS
########################################################################################

mysql='/usr/local/mysql/bin/mysql'
mysqlconfig='/usr/local/mysql/my-mariadb.cnf'
mysqluser='root'
mysqlpassword='qnapqnap'
mysqldatabase='s01'
exiftool='/opt/bin/exiftool'

mysqlconnection="$mysql --defaults-file=$mysqlconfig -u $mysqluser -p$mysqlpassword -N -D$mysqldatabase"

########################################################################################
## INIT
########################################################################################

skipUpdates=0
verbose=0
listStatistics=0
exif2mediadb=0
mediadb2exif=0
days=0
userid=0

# Usage info
show_help() {
cat << EOF
Usage: ${0##*/} [-lem] [-hvs] [-u USERID] [-d DAYS]
Sync photo ratings between QNAP MediaLibrary and JPG files on your QNAP NAS.

Actions
    -l          list key statistics of photos synced with these settings
    -e          sync meta data from your photos to the medialibrary
    -m          sync meta data from the media library to your photos

Processing controls
    -h          display this help and exit
    -v          verbose mode
    -s          skip any database or file updates. Use for trial runs
    -u USERID   specify the user in the MediaLibrary to sync to.
    -d DAYS     specify for how many days back modified files should be included in the sync.
EOF
}

function log(){
	printf "%-100s%s\n" "${1:0:98}" "$2"
}


OPTIND=1 # Reset is necessary if getopts was used previously in the script.  It is a good idea to make this local in a function.
while getopts "h?lvsemu:d:" opt; do
    case "$opt" in
        h)
            show_help
            exit 0
            ;;
        l)
            listStatistics=1
            ;;
        v)  verbose=$((verbose+1))
            ;;
        s)  skipUpdates=1
            ;;
        e)  exif2mediadb=1
            ;;
        m)  mediadb2exif=1
            ;;
        u)  userid=$OPTARG
            ;;
        d)  days=$OPTARG
            ;;
        '?')
            show_help >&2
            exit 1
            ;;
    esac
done
shift "$((OPTIND-1))" # Shift off the options and optional --.

if [ $((listStatistics+exif2mediadb+mediadb2exif)) -eq 0 ]; then
	echo "Please select which action to execute"
    show_help >&2
    exit 1
fi

########################################################################################
## LIST STATISTICS 
########################################################################################

if [ $listStatistics -eq 1 ]; then

	echo "Listing statistics"
	echo "--------------------------------------------------------------------------------------"

	echo "Directories scanned for JPGs:"

	totalcount=0
	while read cMediaDir 
	do
		count=0

		SAVEIFS=$IFS
		IFS=$(echo -en "\n\b") #otherwise filenames with a space will be split

		for fname in `find $cMediaDir -name "*.[Jj][Pp][Gg]" | grep -v "@__thumb"` 
		do 
			count=$((count+1))
		done
		totalcount=$((totalcount+count))
		
		IFS=$SAVEIFS	
		printf "  $cMediaDir \t\t\t : $count JPGs\n"
	
	done < <($mysqlconnection -B -e "SELECT CONCAT(s.prefix, d.cFullPath) AS 'cFullName' from dirTable d JOIN StorageTable s ON d.iStorageId=s.iStorageId WHERE iParentDirId=0")
	
	echo "--------------------------------------------------------------------------------------"
	printf "Total files \t\t\t\t : $totalcount JPGs\n"

	dbphotocount=`$mysqlconnection -B -e "select count(*) from pictureTable p JOIN dirTable d ON p.iDirId=d.iDirId WHERE p.cFilename LIKE '%.JPG'"`
	printf "QNAP MediaLibrary \t\t\t : $dbphotocount JPGs\n"

	echo "-----------------------------------------"
fi


########################################################################################
## SYNC EXIF -> MEDIALIBRARY 
########################################################################################

if [ $exif2mediadb -eq 1 ]; then
	totalcount=0
	if [ $days -eq 0 ]; then
		echo "Sync all photo metadata to the medialibrary"
		echo "------------------------------------------------------------------------------------------------------------------------"

		while read cMediaDir 
		do
			count=0

			while read line 
			do 
				if [ $count -eq 0 ]; then printf "Syncing photos @ $cMediaDir\n"; fi
				OLDIFS=$IFS
				IFS=,
				field=( $line )
				fname=${field[0]//\'/''}
				rating=${field[1]//\'/''}
				IFS=$OLDIFS			
				
				

				rating=$((rating*20))

				if [ $skipUpdates -eq 0 ]; then
					#push EXIF rating through to user db if it changed vs prior sync in main db
					#in case of a sync conflict this means that EXIF changes are leading over User 
					#DB changes
					$mysqlconnection -se "UPDATE pictureMyFavorite f JOIN pictureTable p ON f.iPictureId=p.iPictureId AND f.UserId=$userid JOIN dirTable d ON p.iDirId=d.iDirId JOIN StorageTable s ON p.iStorageId=s.iStorageId SET f.iRating=$rating WHERE p.iRating<>$rating AND CONCAT(s.prefix,d.cFullPath,p.cFilename) LIKE '$fname' ; UPDATE pictureTable p JOIN dirTable d ON p.iDirId=d.iDirId JOIN StorageTable s ON  p.iStorageId=s.iStorageId SET p.iRating=$rating WHERE p.iRating<>$rating AND CONCAT(s.prefix,d.cFullPath,p.cFilename) LIKE '$fname'"
			
					log " + SYNC: $fname" ": Done (rating: $rating)"
				else
					log " + SYNC: $fname" ": Skipped (rating: $rating)"
				fi
				count=$((count+1))
			done < <($exiftool -rating -m -r -s3 -csv -ext jpg $cMediaDir)  
			log "Syncing photos @ $cMediaDir" ": Done ($count processed)"
			
			totalcount=$((totalcount+count))
		done < <($mysqlconnection -B -e "SELECT CONCAT(s.prefix, d.cFullPath) AS 'cFullName' from dirTable d JOIN StorageTable s ON d.iStorageId=s.iStorageId WHERE iParentDirId=0")
	else
		echo "Sync photo metadata changed in last $days days to the medialibrary"
		echo "------------------------------------------------------------------------------------------------------------------------"

		while read cMediaDir 
		do
			count=0

			while read fname 
			do 
				if [ $count -eq 0 ]; then log "Syncing photos @ $cMediaDir" ""; fi

				rating=$($exiftool -m -fast2 -s3 -rating "$fname")

				rating=$((rating*20))
				fname=${fname//\'/''}

				if [ $skipUpdates -eq 0 ]; then
					#push EXIF rating through to user db if it changed vs prior sync in main db
					#in case of a sync conflict this means that EXIF changes are leading over User 
					#DB changes
					$mysqlconnection -se "UPDATE pictureMyFavorite f JOIN pictureTable p ON f.iPictureId=p.iPictureId AND f.UserId=$userid JOIN dirTable d ON p.iDirId=d.iDirId JOIN StorageTable s ON p.iStorageId=s.iStorageId SET f.iRating=$rating WHERE p.iRating<>$rating AND CONCAT(s.prefix,d.cFullPath,p.cFilename) LIKE '$fname' ; UPDATE pictureTable p JOIN dirTable d ON p.iDirId=d.iDirId JOIN StorageTable s ON  p.iStorageId=s.iStorageId SET p.iRating=$rating WHERE p.iRating<>$rating AND CONCAT(s.prefix,d.cFullPath,p.cFilename) LIKE '$fname'"
			
					log " + SYNC: $fname" ": Done (rating: $rating)"
				else
					log " + SYNC: $fname" ": Skipped (rating: $rating)"
				fi
				count=$((count+1))
			done < <(find $cMediaDir -mtime -$days -name "*.[Jj][Pp][Gg]" | grep -v "@__thumb")  
			log "Syncing photos @ $cMediaDir" ": Done ($count processed)"
			log ""
			
			totalcount=$((totalcount+count))
		done < <($mysqlconnection -B -e "SELECT CONCAT(s.prefix, d.cFullPath) AS 'cFullName' from dirTable d JOIN StorageTable s ON d.iStorageId=s.iStorageId WHERE iParentDirId=0")
	fi


	if [ $skipUpdates -eq 0 ]; then

		#SYNC USER FAVORITES FOR PICTURES WITHOUT PRIOR RATING 
		$mysqlconnection -se "INSERT INTO pictureMyFavorite (iPictureId, UserId, AddTime, iRating) SELECT p.iPictureId, $userid AS UserId, UNIX_TIMESTAMP(Now()) AS AddTime, p.iRating AS iRating FROM pictureTable p WHERE p.iRating<>0 ON DUPLICATE KEY UPDATE iRating=pictureMyFavorite.iRating"

		log "Final sync of medialibrary in metadata to user $userid)" ": Done"
	else
		log "Final sync of medialibrary in metadata to user $userid)" ": Skipped"
	fi

	echo "------------------------------------------------------------------------------------------------------------------------"
	log "Sync photo metadata to the medialibrary" ": Done ($totalcount processed)"
fi

########################################################################################
## SYNC MEDIALIBRARY -> EXIF 
########################################################################################

if [ $mediadb2exif -eq 1 ]; then
	echo "Sync changed metadata from the medialibrary to the photos"
	echo "-----------------------------------------"
	count=0
	while read line 
	do
		f=$(echo $line | awk '{print $1}')
		mrating=$(echo $line | awk '{print $2}')
		rating=$((mrating/20))
		printf "SYNC: MediaLibrary $f -> EXIF \t\t : "

		if [ $skipUpdates -eq 0 ]; then
			$exiftool -m -s3 -rating=$rating "$f" > /dev/null
			echo "rating: $mrating"
			$mysqlconnection -se "UPDATE pictureTable p JOIN dirTable d ON p.iDirId=d.iDirId JOIN StorageTable s ON p.iStorageId=s.iStorageId SET p.iRating=$mrating WHERE CONCAT(s.prefix,d.cFullPath,p.cFilename) LIKE '${f//\'/''}'"
			
			printf "Done (rating: $rating)\n"
		else
			printf "Skipped (rating: $rating)\n"
		fi
		count=$((count+1))		
	done < <($mysqlconnection -B -e "SELECT CONCAT(s.prefix,d.cFullPath,p.cFilename), f.iRating FROM pictureTable p, dirTable d, StorageTable s, pictureMyFavorite f WHERE p.iDirId=d.iDirId and p.iStorageId=s.iStorageId AND f.iPictureId=p.iPictureId AND p.iRating<>f.iRating AND f.UserId=$userid AND p.cFilename LIKE '%.JPG'")

	printf "Syncing photos \t\t\t\t : Completed ($count JPGs)\n"
fi
