# fsyncremote
remote sync that uses hashes to check if files have changed and understands moves

One liner:
	if you have many files that you frequently move them and change their names (ex.rename a video file) and you need to sync them to a backup location, then fsyncremote, will understnad that the files chnaged names and changed location and will NOT copy again these files as rsync does, but will just rename/move the files in the backup location to reflect the chnages.
	
