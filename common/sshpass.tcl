package require Tk
package require Expect

proc empty_string {s} {
	return [expr ![string length $s]]
}

wm withdraw .

for {set i 0} {$i < [llength $argv]} { incr i } {
	set key [lindex $argv $i]
	if { $key == "-chdir" } {
		incr i
		set conf(chdir) [lindex $argv $i]
	} else {
		break
	}
}

set argv [lrange $argv $i [llength $argv]]

set timeout 30

spawn -noecho {*}$argv
set pass_counter 0

trap {
 set rows [stty rows]
 set cols [stty columns]
 stty rows $rows columns $cols < $spawn_out(slave,name)
} WINCH

expect {
	"*assword:" {
		if { $pass_counter > 0 } {
			tk_messageBox -icon error -message "Invalid password"
			exit
		} else {
			exp_send "$::env(SSHPASS)\n"
			incr pass_counter
			exp_continue
		}
	} "*yes/no)?" {
		exp_send [tk_messageBox -type yesno -message "Are you sure you want to connect?"]
		exp_send "\n"
		exp_continue
	} "Connection refused" {
			tk_messageBox -icon error -message "Connection refused"
			exit
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
			interact
			exit
		}
		exp_continue
	} eof {
		interact
	}
}
