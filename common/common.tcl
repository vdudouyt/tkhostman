if { [file exist /usr/lib/tcltk/sqlite3/libtclsqlite3.so] } {
	# 'package require sqlite3' found non-working on Ubuntu 11.10
	load /usr/lib/tcltk/sqlite3/libtclsqlite3.so
} else {
	package require sqlite3
}


set conf_root "$::env(HOME)/.tkhostman"
proc init_conf {} {
	package require sqlite3
	global hosts
	global hosts_conf
	global supported_protos
	global conf_root
	if { ![file exists $conf_root] } {
		mkdir $conf_root
		chmod 0700 $conf_root
	}
	set db_path "$conf_root/tkhostman.sqlite"
	set db_exists [file exists $db_path]
	sqlite3 db $db_path
	if { !$db_exists } {
		chmod 0600 $db_path
		db eval { CREATE TABLE hosts (id integer primary key autoincrement,
					host_name varchar(32) not null,
					proto varchar(7) not null,
					addr varchar(64) not null,
					mount_point varchar(64) not null,
					port int,
					login varchar(64),
					pass varchar(64),
					id_path varchar(128))
			}
	}
	file stat $db_path stat
	if { ($stat(mode) & 0x3f) > 0} {
		sshpass_msg "File mode is too permissive. Change to something like 0600\n$db_path"
		exit
	}
}

proc get_host_by_name {host_name stor} {
	upvar $stor result
	db eval { SELECT * FROM hosts WHERE host_name=$host_name } host_conf { 
		array set result [array get host_conf]
		return
	}
}

proc empty_string {s} {
	return [expr ![string length $s]]
}

# May be overriden by front-ends
proc sshpass_msg {err} {
	puts $err
}

proc sshpass_ask {q} {
	return [gets stdin]
}
# ---

proc sshpass {cmd pass} {
	package require Expect
	package require Tclx
	global spawn_out
	trap {
		set rows [stty rows]
		set cols [stty columns]
		stty rows $rows columns $cols < $spawn_out(slave,name)
	} WINCH 

	spawn -noecho -ignore HUP {*}$cmd
	set pass_counter 0

	set timeout -1
	expect {
		"*assword:" {
			if { $pass_counter > 0 } {
				sshpass_msg "Invalid password"
			} else {
				exp_send "$pass\n"
				incr pass_counter
				exp_continue
			}
		} "*yes/no)?" {
			exp_send [sshpass_ask "The authenticity of host can't be established.
Are you sure you want to continue connecting?"]
			exp_send "\n"
			exp_continue
		} "\n" {
			set line [string trimright $expect_out(buffer) "\n\r"]
			set line [string trimright $line]
			set line [string trim $line]
			if { [empty_string $line]
				|| $line == "yes"
				|| $line == "no"
				|| [regexp "ermanently added" $line] } {
					exp_continue
			} else {
				if { [info exists conf(chdir)] } {
					exp_send "cd $conf(chdir)\n"
				}
				interact {
					-o eof {
						exit 0
					}
				}
			}
			exp_continue
		} eof {
			# Do nothing
		}
	}
}

proc mount { host } {
	upvar $host h
	# Checking mount point existance
	set dir $h(mount_point)
	if { ![file exist $dir] } { file mkdir $dir }
	# Calling approriate mount method
	set proto $h(proto)
	eval "mount_$proto" h
}

proc umount { host } {
	upvar $host h
	exec fusermount -uz $h(mount_point)
}

proc read_mtab { out } {
	upvar $out result
	array unset result
	foreach w [split [read_file "/etc/mtab"] "\n"] {
		set src [lindex $w 0]
		set mount_point [lindex $w 1]
		set result($mount_point) $src
	}
}
