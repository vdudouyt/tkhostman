if { [info exists supported_protos] } {
	lappend supported_protos "ftp"
}

proc mount_ftp { host } {
	upvar $host conf
	# Checking mount point existance
	set dir $conf(mount_point)
	if { ![file exist $dir] } { file mkdir $dir }

	exec curlftpfs -o "user=$conf(login):$conf(pass)" $conf(addr) $conf(mount_point) -o "intr,cache_timeout=1800"
}
