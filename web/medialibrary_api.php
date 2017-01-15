<?php
$servername = "127.0.0.1";
$username = "root";
$password = "qnapqnap";
$port = "3310";
$dbname = "s01";

$sql = "";
$cmd = $_REQUEST['cmd'];

switch ($cmd){
	case 'recent':
		$sql = 
			"SELECT p.iPictureId as 'pid', ".
			"p.iWidth as 'width', ".
			"p.iHeight as 'height', ".
			"CONCAT(d.cFullPath,p.cFilename) AS 'original', ".
			"CONCAT(d.cFullPath,'.@__thumb/s800',p.cFilename) AS 'preview', ".
			"CONCAT(d.cFullPath,'.@__thumb/default',p.cFilename) AS 'thumb', ".
			"IFNULL(f.iRating/20,0) as 'rating', ".
			"p.YearMonthDay as 'datecreated' ".
			"FROM pictureTable p JOIN dirTable d ON p.iDirId=d.iDirId LEFT JOIN (SELECT * FROM pictureMyFavorite WHERE UserId=0) f ON f.iPictureId=p.iPictureId ORDER BY p.YearMonthDay DESC LIMIT 200";		
		break;
	case 'date':
		$d = $_REQUEST['date'];
		$r = !empty($_REQUEST['rating']) ? "AND f.iRating>=".((int)$_REQUEST['rating'])*20 : "";
		
		$sql = 
			"SELECT p.iPictureId as 'pid', ".
			"p.iWidth as 'width', ".
			"p.iHeight as 'height', ".
			"CONCAT(d.cFullPath,p.cFilename) AS 'original', ".
			"CONCAT(d.cFullPath,'.@__thumb/s800',p.cFilename) AS 'preview', ".
			"CONCAT(d.cFullPath,'.@__thumb/default',p.cFilename) AS 'thumb', ".
			"IFNULL(f.iRating/20,0) as 'rating', ".
			"p.YearMonthDay as 'datecreated' ".
			"FROM pictureTable p JOIN dirTable d ON p.iDirId=d.iDirId LEFT JOIN (SELECT * FROM pictureMyFavorite WHERE UserId=0) f ON f.iPictureId=p.iPictureId WHERE p.YearMonthDay='".$d."' ".$r." ORDER BY p.YearMonthDay DESC";
		break;
	case 'summary':
		$sql_filter_rating_join="LEFT JOIN";
		$sql_filter_rating="";
		if(!empty($_REQUEST['filter_rating']) && $_REQUEST['filter_rating'] != "0") {
			$sql_filter_rating="AND iRating>=".$_REQUEST['filter_rating'];
			$sql_filter_rating_join="JOIN";
			$sql = 	"SELECT a.YearMonthDay as 'datecreated', a.thumb, a.iRating, max(a.rnd+a.iRating) FROM (SELECT CONCAT(d.cFullPath,'.@__thumb/s100',p2.cFilename) AS 'thumb', p2.YearMonthDay, p2.iRating, rand() as 'rnd' FROM pictureTable p2 JOIN dirTable d ON p2.iDirId=d.iDirId JOIN (SELECT * FROM pictureMyFavorite WHERE UserId=0 ".$sql_filter_rating.") f ON f.iPictureId=p2.iPictureId ORDER BY rand()) a GROUP BY a.YearMonthDay ORDER BY a.YearMonthDay DESC;";
		} else {
			$sql = "SELECT p.YearMonthDay as 'datecreated', ".
			"COUNT(*) as 'picturecount', ".
			"(SELECT CONCAT(d.cFullPath,'.@__thumb/s100',p2.cFilename) AS 'thumb' FROM pictureTable p2 JOIN dirTable d ON p2.iDirId=d.iDirId LEFT JOIN (SELECT * FROM pictureMyFavorite WHERE UserId=0) f ON f.iPictureId=p2.iPictureId WHERE p2.YearMonthDay=p.YearMonthDay ORDER BY f.iRating DESC, rand() LIMIT 1) as 'thumb' ".
			"FROM pictureTable p GROUP BY p.YearMonthDay ORDER BY p.YearMonthDay DESC";
		}
		break;
	case 'albums':
		$sql = "SELECT cAlbumTitle, iPhotoAlbumId, CONCAT(d.cFullPath,'.@__thumb/default',p.cFilename) AS 'thumb' FROM pictureAlbumTable pa LEFT JOIN pictureTable p ON pa.iAlbumCover=p.iPictureId LEFT JOIN dirTable d ON p.iDirId=d.iDirId WHERE albumType=1";
		break;
	case 'albummapping':
		$sql = "SELECT pa.iMediaId AS 'pid', pa.iPhotoAlbumId FROM pictureAlbumMapping pa WHERE type=1";
		break;
	case 'album':
		$id = $_REQUEST['album'];
		$r = !empty($_REQUEST['rating']) ? "AND f.iRating>=".((int)$_REQUEST['rating'])*20 : "";
		
		$sql = 
			"SELECT p.iPictureId as 'pid', ".
			"p.iWidth as 'width', ".
			"p.iHeight as 'height', ".
			"CONCAT(d.cFullPath,p.cFilename) AS 'original', ".
			"CONCAT(d.cFullPath,'.@__thumb/s800',p.cFilename) AS 'preview', ".
			"CONCAT(d.cFullPath,'.@__thumb/default',p.cFilename) AS 'thumb', ".
			"IFNULL(f.iRating/20,0) as 'rating', ".
			"p.YearMonthDay as 'datecreated' ".
			"FROM pictureTable p JOIN dirTable d ON p.iDirId=d.iDirId JOIN pictureAlbumMapping pa ON pa.iMediaId=p.iPictureId LEFT JOIN (SELECT * FROM pictureMyFavorite WHERE UserId=0) f ON f.iPictureId=p.iPictureId WHERE pa.iPhotoAlbumId='".$id."' ".$r." ORDER BY p.dateTime ASC";
		break;
	case 'updaterating':
		$id = $_REQUEST['pid'];
		$rating = $_REQUEST['rating'];
		if (is_numeric($id) && is_numeric($rating) && $rating>=0 && $rating<=5) {
			$sql = sprintf("INSERT INTO pictureMyFavorite (iPictureId, UserId, AddTime, iRating) VALUES (%d, %d, UNIX_TIMESTAMP(Now()), %d) ON DUPLICATE KEY UPDATE iRating=%d", $id, $userid, $rating*20, $rating*20);
		}
		else
			die("error: non numeric value provided");
		break;
	case 'addalbummapping':
		$id = $_REQUEST['pid'];
		$albumid = $_REQUEST['iPhotoAlbumId'];
		if (is_numeric($id) && is_numeric($albumid)) {
			$sql = sprintf("INSERT IGNORE INTO pictureAlbumMapping (iMediaId, type, iPhotoAlbumId) VALUES (%d, 1, %d)", $id, $albumid);
		}
		else
			die("error: non numeric value provided");
		break;
	case 'removealbummapping':
		$id = $_REQUEST['pid'];
		$albumid = $_REQUEST['iPhotoAlbumId'];
		if (is_numeric($id) && is_numeric($albumid)) {
			$sql = sprintf("DELETE FROM pictureAlbumMapping WHERE iMediaId=%d AND iPhotoAlbumId=%d", $id, $albumid);
		}
		else
			die("error: non numeric value provided");
		break;
	default:
		die("Please specify which cmd you want (recent, date, summary, albums, albummapping, updaterating, updatealbummapping)"); 
}

// Create connection
$conn = new mysqli($servername, $username, $password, $dbname, $port);
// Check connection
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
} 

$result = $conn->query($sql);
$output = array();

if ($result->num_rows > 0) {
    // output data of each row
    while($row = $result->fetch_assoc()) {
		$output[] = $row;
    }
} else {
    //echo "0 results";
}
$conn->close();
echo json_encode($output);
?> 