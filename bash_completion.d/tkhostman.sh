#!/bin/bash
# Completions file

_tkhostman () {
	local cur prev opts
	COMPREPLY=()
	cur="${COMP_WORDS[COMP_CWORD]}"
	TXT=$(sqlite3 "$HOME/.tkhostman/tkhostman.sqlite" "SELECT host_name FROM hosts WHERE host_name LIKE '%$cur%'")
	COMPREPLY=( 	$(compgen -W '$TXT' -- ${cur}) )
	return 0
}

complete -F _tkhostman sshto
complete -F _tkhostman hostmount
complete -F _tkhostman hostinfo
