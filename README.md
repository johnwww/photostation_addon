# Photostation Addon
QNAP PhotoStation is an web based photo manager that enables managing photos on your QNAP NAS. While the MediaLibrary backend is quite solid (it  indexes & processes new images realtime reliably), the front-end is a bit cumbersome, lacking some simplicity and missing some key features. These have been added via a custom web interface. Key improvements are:

Added Simplicity:
- Summary view by day
- Single click rating
- Clean photo browser

Added Features:
- Sync ratings back & from EXIF of every photo
- Move photos to new location while keeping meta-data

# Media Library
The QNAP NAS keeps track of all media in a central MediaLibrary. This is a process that monitors selected folders and updates a MariaDB database with media metadata.

This database can be accessed like this (with user:root and password:qnapqnap) :

/usr/local/mysql/bin/mysql --defaults-file=/usr/local/mysql/my-mariadb.cnf -u root -pqnapqnap

# Solution Design
Using the web server on the QNAP a web api has been developed 
- medialibrary_api.php : web api with all SQL queries into the medialibrary database
- rater.html : simple webapp that enables undisturbed browsing & single-click rating of photos
- albums.html : simple webapp that enables undisturbed browsing of albums
- sync-exif2db.sh : script that enables syncing EXIF ratings into the database and vice versa