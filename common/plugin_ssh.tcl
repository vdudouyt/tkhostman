if { [info exists supported_protos] } {
	lappend supported_protos "ssh"
}

proc mount_ssh { host } {
	upvar $host conf
	# Remote dir is not specified - use "/"
	if { [string first ":" $conf(addr)] == -1 } {
		set conf(addr) "$conf(addr):/"
	}
	# Preparing statement to eval
	set extra_args {}
	if { ![empty_string $conf(id_path)] } { lappend extra_args -o IdentityFile=$conf(id_path) }
	sshpass [list sshfs "$conf(login)@$conf(addr)" $conf(mount_point) -p $conf(port) -o intr {*}$extra_args] -pass $conf(pass)
}
