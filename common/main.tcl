#!/usr/bin/tclsh8.5

array set hosts_conf {}
set supported_protos { ftp ssh }
set default_root "/net"
set column_names "host_name proto addr mount_point port login pass key_name"
set column_extra "mounted"

proc init_conf {db_path} {
	package require sqlite3
	global hosts
	global hosts_conf
	global supported_protos
	if { [file exists $db_path] } { 
		sqlite3 db $db_path
	} else {
		sqlite3 db $db_path
		db eval { CREATE TABLE hosts (id integer primary key autoincrement, host_name varchar(32) not null, proto varchar(7) not null, addr varchar(64) not null, mount_point varchar(64) not null, port int, login varchar(64), pass varchar(64), key_name varchar(64), key_data blob) }
	}
}

proc init_gui {} {
	package require Tk
	package require BWidget
	package require tablelist
	global hosts
	global hosts_conf
	global column_names
	global column_extra
	global app_title
	set app_title "TkHostMan"
	wm title . $app_title
	tablelist::tablelist .t -columns {0 "Host"
					  0 "Type"
					  0 "Addr"
					  0 "Mount Point"
					  0 "Port"
					  0 "Login"
					  0 "Password"
					  0 "Key"
					  0 "Mounted"} \
				-stretch all \
				-background white \
				-editstartcommand edit_start \
				-editendcommand edit_end
	pack .t -fill both -expand 1 -side top
	tablelist::addBWidgetComboBox
	set i 0
	foreach n [concat $column_names $column_extra] {
		.t columnconfigure $i -name $n -editable yes
		incr i
	}
	.t columnconfigure 1 -editwindow ComboBox
	.t columnconfigure 8 -editwindow ComboBox
	fill_values {}
	event add <<Toggle>> <m>
	event add <<Toggle>> <u>
	event add <<Toggle>> <s>
	event add <<Toggle>> <Delete>
	# event add <<Toggle>> <Space>
	bind [.t bodytag] <<Toggle>> {
		set row [.t curselection]
		if { ![empty_string $row] } {
			set index [.t cellindex "$row,8"]
			set host_id [.t rowcget $row -name]
			switch "%K" {
				m {
					configure_host mount $host_id
					.t cellconfigure $index -text "Yes"
				}
				u {
					configure_host umount $host_id
					.t cellconfigure $index -text "No"
				}
				s {
					ssh_console $host_id
				}
				Delete {
					.t delete $row
					db eval { DELETE FROM hosts WHERE id=$host_id }
				}
			}
		}
	}
	menu .popupMenu
	.popupMenu add command -label "Mount" -command "popupmenu_act mount"
	.popupMenu add command -label "Umount" -command "popupmenu_act umount"
	.popupMenu add command -label "SSH Console" -command "popupmenu_act console"
	.popupMenu add command -label "Delete" -command "popupmenu_act delete"
	bind [.t bodytag] <<Button3>> {
		.t selection clear 0 [.t size]
		set row [.t containing $tablelist::y]
		.t selection set [ expr $row ]
		tk_popup .popupMenu %X %Y
	}
	event add <<Search>> <Control-s>
	bind [.t bodytag] <<Search>> {
		tk::entry .str -textvariable search
		pack .str -fill x
		focus .str
		bind .str <Return> {
			fill_values $search
			if { ![empty_string $search] } { wm title . "$app_title search: $search" }
			destroy .str
			focus .t
		}
		bind .str <Escape> {
			set search {}
			fill_values {}
			wm title . $app_title
			destroy .str
			focus .t
		}
	}
	bind [.t bodytag] <Escape> {
		set search {}
		fill_values {}
		wm title . $app_title
	}
	.t selection set 0
	focus .t
}

proc fill_values {search} {
	global column_names
	set sql { SELECT * FROM hosts }
	if { ![empty_string $search] } {
		set sql "$sql WHERE host_name LIKE '%$search%' OR addr LIKE '%$search%'"
	}
	.t delete 0 end
	db eval $sql values {
		set chunks {}
		foreach col_name $column_names {
			lappend chunks $values($col_name)
		}
		.t insert end $chunks
		.t rowconfigure end -name $values(id)
	}
	.t insert end {}
}

proc popupmenu_act {act} {
	upvar tablelist::x x
	upvar tablelist::y y
	set row [.t containing $y]
	set index [.t cellindex "$row,8"]
	set host_id [.t rowcget $row -name]
	switch $act {
		mount {
			configure_host "mount" $host_id
			.t cellconfigure $index -text "Yes"
		}
		umount {
			configure_host "umount" $host_id
			.t cellconfigure $index -text "No"
		}
		console {
			ssh_console $host_id
		}
		delete {
			.t delete $row
			db eval { DELETE FROM hosts WHERE id=$host_id }
		}
	}
}

proc empty_string {s} {
	return [expr ![string length $s]]
}

proc edit_start {tbl row col text} {
	global supported_protos
	global hostkey_contents
	set w [$tbl editwinpath]
	switch [$tbl columncget $col -name] {
		mounted {
			$w configure -values "Yes No"
		}
		proto {
			$w configure -values $supported_protos
		}
	}
	return $text
}

proc edit_end {tbl row col text} {
	global default_root
	global supported_protos
	global column_names
	global hostkey_contents

	set host_id [.t rowcget $row -name]
	if { [empty_string [db eval { SELECT * FROM hosts WHERE id=$host_id }]] } {
		db eval { INSERT INTO hosts (host_name, proto, addr, mount_point, port, key_name) VALUES ("", "ssh", "", $default_root, 22, "<None>") }
		$tbl insert end {}
		set host_id [db last_insert_rowid]
		$tbl rowconfigure $row -name $host_id
	}
	set column_name [$tbl columncget $col -name]
	db eval { SELECT * FROM hosts WHERE id=$host_id } host_conf {
		set i 0
		foreach col_name $column_names {
			set value $host_conf($col_name)
			set c_i [$tbl cellindex "$row,$i"]
			$tbl cellconfigure $c_i -text $value
			incr i
		}
		switch $column_name {
			mounted {
				if { ![string compare $text Yes] } {
					configure_host mount $host_id
					set text Yes
				} else {
					configure_host umount $host_id
					set text No
				}
			}
			proto {
				if { [lsearch $supported_protos $text] == -1} { set text $host_conf(proto) }
			}
			mount_point {
			}
			key_name {
				if { $text != "<None>" } {
					set file_path [tk_getOpenFile]
					if { [empty_string $file_path] } {
						db eval { UPDATE hosts SET key_name='<None>', key_data='' WHERE id=$host_id }
						return <None>
					} else {
						set name_parts [split $file_path "/"]
						set filename [lindex $name_parts [expr [llength $name_parts] - 1]]
						set fp [open $file_path "r"]
						fconfigure $fp -translation binary
						set hostkey_contents [read $fp]
						close $fp
						db eval { UPDATE hosts SET key_name=$filename, key_data=@hostkey_contents WHERE id=$host_id }
						return $filename
					}
				}
			}
		}
		if { [lsearch $column_names $column_name] != -1 } {
			db eval "UPDATE hosts SET $column_name=\"$text\" WHERE id=$host_id"
		}
		return $text
	}
}

proc get_ssh_conf {host_id} {
	global hosts_conf
	upvar conf result
	set conf $hosts_conf($host_id)
	set conf_spec "host_name proto addr mount_point port login pass key_name"
	foreach var_name $conf_spec value $conf {
		set result($var_name) $value
	}
}

proc configure_host {act host_id} {
	db eval { SELECT * FROM hosts WHERE id=$host_id } host_conf {
		switch $act {
			mount {
				set dir $host_conf(mount_point)
				if { ![file exist $dir] } { file mkdir $dir }
			}
		}
		set command "$act\_$host_conf(proto)"
		eval $command
	}
}

proc mount_ssh {} {
	upvar host_conf conf
	set ::env(SSHPASS) $conf(pass)
	if { ![regexp "(.*):(/.*)" $conf(addr) match host path] } {
		tk_messageBox -icon error -message "missing host"
	}
	set sshpass {}
	set to_eval [list exec setsid tkhostman-sshpass sshfs -f "$conf(login)@$conf(addr)" $conf(mount_point) -p $conf(port) -o intr]
	if { $conf(key_name) != "<None>" } {
		set pid [pid]
		set fname "/tmp/$conf(host_name)-$pid.private"
		set tempfile [open $fname "w"]
		fconfigure $tempfile -translation binary
		puts $tempfile $conf(key_data);
		close $tempfile
		exec chmod 0600 $fname
		lappend to_eval -o 
		lappend to_eval "IdentityFile=$fname"
	}
	lappend to_eval "&"
	puts "eval: $to_eval"
	eval $to_eval
}

proc umount_ssh {} {
	upvar host_conf conf
	umount_fuse $conf(mount_point)
}

proc mount_ftp {} {
	upvar host_conf conf
	set to_eval [list exec curlftpfs -o "user=$conf(login):$conf(pass)" $conf(addr) $conf(mount_point) -o intr,cache_timeout=1800]
	eval $to_eval
}

proc umount_ftp {} {
	upvar host_conf conf
	umount_fuse $conf(mount_point)
}

proc umount_fuse {mount_point} {
	exec fusermount -u $mount_point
}

proc ssh_console {host_id} {
	db eval { SELECT * FROM hosts WHERE id=$host_id } conf {
		set chdir {}
		if { [regexp "(.*):(/.*)" $conf(addr) match host path] } {
			set chdir "-chdir $path"
		}
		set ::env(SSHPASS) $conf(pass)
		set colon_index [string first ":" $conf(addr)]
		if { $colon_index == -1 } {
			set ssh_host $conf(addr)
		} else {
			set ssh_host [string range $conf(addr) 0 [expr $colon_index-1]]
		}
		if { $conf(proto) == "ssh" } { set port $conf(port) } else { set port 22 }
#		Gnome-Terminal, XTerm
		set to_eval [list exec /usr/bin/x-terminal-emulator -title $conf(host_name) -e tkhostman-sshpass {*}$chdir ssh $conf(login)@$ssh_host -p $port]
#		Roxterm
#		set to_eval [list exec /usr/bin/x-terminal-emulator --tab --tab-name=$conf(host_name) -e tkhostman-sshpass {*}$chdir ssh $conf(login)@$ssh_host -p $port]
		if { $conf(key_name) != "<None>" } {
			set pid [pid]
			set fname "/tmp/$conf(host_name)-$pid.private"
			set tempfile [open $fname "w"]
			fconfigure $tempfile -translation binary
			puts $tempfile $conf(key_data);
			close $tempfile
			exec chmod 0600 $fname
			lappend to_eval -o 
			lappend to_eval "IdentityFile=$fname"
		}
		lappend to_eval "&"
		eval $to_eval
	}
}

set conf_dir "$env(HOME)/.tkhostman"
if { ![file exists $conf_dir] } {
	file mkdir $conf_dir
}
init_conf "$conf_dir/tkhostman.sqlite"
init_gui
