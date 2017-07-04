#!/usr/bin/env bash


#Problems:

#If source todo contains &, part of the todo is printed back to the file

#If source todo contains (), todo fails to be written back


# This script:
#
#  - Scans text files for todo items and syncs them with todos in
#    todo.txt
#
# Usage:
#
#  LOG_LEVEL=7 ./main.sh -f /tmp/x -d (change this for your script)
#
# Based on a template by BASH3 Boilerplate v2.3.0
# http://bash3boilerplate.sh/#authors
#
# The MIT License (MIT)
# Copyright (c) 2013 Kevin van Zonneveld and contributors
# You are not obligated to bundle the LICENSE file with your b3bp projects as long
# as you leave these references intact in the header comments of your source files.

# Exit on error. Append "|| true" if you expect an error.
set -o errexit
# Exit on error inside any functions or subshells.
set -o errtrace
# Do not allow use of undefined vars. Use ${VAR:-} to use an undefined VAR
set -o nounset
# Catch the error in case mysqldump fails (but gzip succeeds) in `mysqldump |gzip`
set -o pipefail
# Turn on traces, useful while debugging but commented out by default
# set -o xtrace

# Any error set to 77 will exit the whole script. Useful if an error
# is called inside a subshell. However, this doesn't work for interpolated
# commands like:
# echo "$(exit 77)"
# However, it's the best I can do at the moment
trap '[ "$?" -ne 77 ] || exit 77' ERR

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
	__i_am_main_script="0" # false

	if [[ "${__usage+x}" ]]; then
		if [[ "${BASH_SOURCE[1]}" = "${0}" ]]; then
			__i_am_main_script="1" # true
		fi

		__b3bp_external_usage="true"
		__b3bp_tmp_source_idx=1
	fi
else
	__i_am_main_script="1" # true
	[[ "${__usage+x}" ]] && unset -v __usage
	[[ "${__helptext+x}" ]] && unset -v __helptext
fi

# Set magic variables for current file, directory, os, etc.
__dir="$(cd "$(dirname "${BASH_SOURCE[${__b3bp_tmp_source_idx:-0}]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[${__b3bp_tmp_source_idx:-0}]}")"
__base="$(basename "${__file}" .sh)"


# Define the environment variables (and their defaults) that this script depends on
LOG_LEVEL="${LOG_LEVEL:-}" # 7 = debug -> 0 = emergency
NO_COLOR="${NO_COLOR:-}"    # true = disable color. otherwise autodetected


### Functions
##############################################################################

function __b3bp_log () {
	local log_level="${1}"
	shift

	# shellcheck disable=SC2034
	local color_debug="\x1b[35m"
	# shellcheck disable=SC2034
	local color_info="\x1b[32m"
	# shellcheck disable=SC2034
	local color_notice="\x1b[34m"
	# shellcheck disable=SC2034
	local color_warning="\x1b[33m"
	# shellcheck disable=SC2034
	local color_error="\x1b[31m"
	# shellcheck disable=SC2034
	local color_critical="\x1b[1;31m"
	# shellcheck disable=SC2034
	local color_alert="\x1b[1;33;41m"
	# shellcheck disable=SC2034
	local color_emergency="\x1b[1;4;5;33;41m"

	local colorvar="color_${log_level}"

	local color="${!colorvar:-${color_error}}"
	local color_reset="\x1b[0m"

	if [[ "${NO_COLOR:-}" = "true" ]] || [[ "${TERM:-}" != "xterm"* ]] || [[ "${TERM:-}" != "screen-256color"* ]] || [[ ! -t 2 ]]; then
		if [[ "${NO_COLOR:-}" != "false" ]]; then
			# Don't use colors on pipes or non-recognized terminals
			color=""; color_reset=""
		fi
	fi

	# all remaining arguments are to be printed
	local log_line=""

	while IFS=$'\n' read -r log_line; do
		echo -e "$(date -u +"%Y-%m-%d %H:%M:%S GMT") ${color}$(printf "[%9s]" "${log_level}")${color_reset} ${log_line}" 1>&2
	done <<< "${@:-}"
}

function emergency () {                                __b3bp_log emergency "${@}"; exit 1; }
function alert ()     { [[ "${LOG_LEVEL:-0}" -ge 1 ]] && __b3bp_log alert "${@}"; true; }
function critical ()  { [[ "${LOG_LEVEL:-0}" -ge 2 ]] && __b3bp_log critical "${@}"; true; }
function error ()     { [[ "${LOG_LEVEL:-0}" -ge 3 ]] && __b3bp_log error "${@}"; true; }
function warning ()   { [[ "${LOG_LEVEL:-0}" -ge 4 ]] && __b3bp_log warning "${@}"; true; }
function notice ()    { [[ "${LOG_LEVEL:-0}" -ge 5 ]] && __b3bp_log notice "${@}"; true; }
function info ()      { [[ "${LOG_LEVEL:-0}" -ge 6 ]] && __b3bp_log info "${@}"; true; }
function debug ()     { [[ "${LOG_LEVEL:-0}" -ge 7 ]] && __b3bp_log debug "${@}"; true; }

function help () {
	echo "" 1>&2
	echo " ${*}" 1>&2
	echo "" 1>&2
	echo "  ${__usage:-No usage available}" 1>&2
	echo "" 1>&2

	if [[ "${__helptext:-}" ]]; then
		echo " ${__helptext}" 1>&2
		echo "" 1>&2
	fi

	exit 1
}


### Parse commandline options
##############################################################################

# Commandline options. This defines the usage page, and is used to parse cli
# opts & defaults from. The parsing is unforgiving so be precise in your syntax
# - A short option must be preset for every long option; but every short option
#   need not have a long option
# - `--` is respected as the separator between options and arguments
# - We do not bash-expand defaults, so setting '~/app' as a default will not resolve to ${HOME}.
#   you can use bash variables to work around this (so use ${HOME} instead)


# shellcheck disable=SC2015
[[ "${__usage+x}" ]] || read -r -d '' __usage <<-'EOF' || true # exits non-zero when EOF encountered
usage: todoSync.sh --file <name> [-vduh]

-f --file [arg]       File to be scanned. Required.
-v --verbose          Enable verbose mode, print script as it is executed
-d --debug            Enables debug mode
-u --dummy            Dummy run (do not commit changes)
-h --help             This page
EOF

# shellcheck disable=SC2015
[[ "${__helptext+x}" ]] || read -r -d '' __helptext <<-'EOF' || true # exits non-zero when EOF encountered

--------------

todoSync.sh

-------------


This todo synchroniser looks through a text file and identifies todo items. 

Default format is:

- [ ] Get the milk @shopping

When this script encounters such a todo for the first time, this todo is then 
added to the todotxt file using the standard todo.sh command see 
[https://github.com/ginatrapani/todo.txt-cli]. Note that the marked todo
text is sent to this command raw., e.g.:

t add Get milk @shopping ID:4h7f

(And note that a random five-letter ID code is added.)

Just after, this script flags the todo with an ID:

- [ ] Get the milk @shopping, ID:4h7f

The next time the script is run, it will come across this todo
item with the ID 4h7f. It will check the $DONE_FILE to see
if it has indeed been done (using the ID). If this exists in
the $DONE_FILE, it will mark it as done:

- [x] Get the milk @shopping, ID:4h7f

But wait, there's more. The script will attempt identify
context in terms of a heading and a project. If your file
looks like this:

# Latest list
- [ ] Get the milk

...the script will look for the most recent heading (marked
by a hash character) and use that as context, i.e. generating
the following todotxt command:

Get the milk in 'Latest list', ID:MjFlN, SOURCE:unitTestFile.markdown

Additionally, if the heading contains a project (marked by a +
character), this will be pulled out of the heading and added to the
todotxt command as a project. Thus, the following:

# Latest list +latest
- [ ] Get the milk

...Will generate this todotxt command:

Get the milk +latest in 'Latest list', ID:MjFlN, SOURCE:unitTestFile.markdown

Created by Ian Hocking <ihocking@gmail.com>
EOF

# Translate usage string -> getopts arguments, and set $arg_<flag> defaults
while read -r __b3bp_tmp_line; do
	if [[ "${__b3bp_tmp_line}" =~ ^- ]]; then
		# fetch single character version of option string
		__b3bp_tmp_opt="${__b3bp_tmp_line%% *}"
		__b3bp_tmp_opt="${__b3bp_tmp_opt:1}"

		# fetch long version if present
		__b3bp_tmp_long_opt=""

		if [[ "${__b3bp_tmp_line}" = *"--"* ]]; then
			__b3bp_tmp_long_opt="${__b3bp_tmp_line#*--}"
			__b3bp_tmp_long_opt="${__b3bp_tmp_long_opt%% *}"
		fi

		# map opt long name to+from opt short name
		printf -v "__b3bp_tmp_opt_long2short_${__b3bp_tmp_long_opt//-/_}" '%s' "${__b3bp_tmp_opt}"
		printf -v "__b3bp_tmp_opt_short2long_${__b3bp_tmp_opt}" '%s' "${__b3bp_tmp_long_opt//-/_}"

		# check if option takes an argument
		if [[ "${__b3bp_tmp_line}" =~ \[.*\] ]]; then
			__b3bp_tmp_opt="${__b3bp_tmp_opt}:" # add : if opt has arg
			__b3bp_tmp_init=""  # it has an arg. init with ""
			printf -v "__b3bp_tmp_has_arg_${__b3bp_tmp_opt:0:1}" '%s' "1"
		elif [[ "${__b3bp_tmp_line}" =~ \{.*\} ]]; then
			__b3bp_tmp_opt="${__b3bp_tmp_opt}:" # add : if opt has arg
			__b3bp_tmp_init=""  # it has an arg. init with ""
			# remember that this option requires an argument
			printf -v "__b3bp_tmp_has_arg_${__b3bp_tmp_opt:0:1}" '%s' "2"
		else
			__b3bp_tmp_init="0" # it's a flag. init with 0
			printf -v "__b3bp_tmp_has_arg_${__b3bp_tmp_opt:0:1}" '%s' "0"
		fi
		__b3bp_tmp_opts="${__b3bp_tmp_opts:-}${__b3bp_tmp_opt}"
	fi

	[[ "${__b3bp_tmp_opt:-}" ]] || continue

	if [[ "${__b3bp_tmp_line}" =~ (^|\.\ *)Default= ]]; then
		# ignore default value if option does not have an argument
		__b3bp_tmp_varname="__b3bp_tmp_has_arg_${__b3bp_tmp_opt:0:1}"

		if [[ "${!__b3bp_tmp_varname}" != "0" ]]; then
			__b3bp_tmp_init="${__b3bp_tmp_line##*Default=}"
			__b3bp_tmp_re='^"(.*)"$'
			if [[ "${__b3bp_tmp_init}" =~ ${__b3bp_tmp_re} ]]; then
				__b3bp_tmp_init="${BASH_REMATCH[1]}"
			else
				__b3bp_tmp_re="^'(.*)'$"
				if [[ "${__b3bp_tmp_init}" =~ ${__b3bp_tmp_re} ]]; then
					__b3bp_tmp_init="${BASH_REMATCH[1]}"
				fi
			fi
		fi
	fi

	if [[ "${__b3bp_tmp_line}" =~ (^|\.\ *)Required\. ]]; then
		# remember that this option requires an argument
		printf -v "__b3bp_tmp_has_arg_${__b3bp_tmp_opt:0:1}" '%s' "2"
	fi

	printf -v "arg_${__b3bp_tmp_opt:0:1}" '%s' "${__b3bp_tmp_init}"
done <<< "${__usage:-}"

# run getopts only if options were specified in __usage
if [[ "${__b3bp_tmp_opts:-}" ]]; then
	# Allow long options like --this
	__b3bp_tmp_opts="${__b3bp_tmp_opts}-:"

	# Reset in case getopts has been used previously in the shell.
	OPTIND=1

	# start parsing command line
	set +o nounset # unexpected arguments will cause unbound variables
	# to be dereferenced
	# Overwrite $arg_<flag> defaults with the actual CLI options
	while getopts "${__b3bp_tmp_opts}" __b3bp_tmp_opt; do
		[[ "${__b3bp_tmp_opt}" = "?" ]] && help "Invalid use of script: ${*} "

		if [[ "${__b3bp_tmp_opt}" = "-" ]]; then
			# OPTARG is long-option-name or long-option=value
			if [[ "${OPTARG}" =~ .*=.* ]]; then
				# --key=value format
				__b3bp_tmp_long_opt=${OPTARG/=*/}
				# Set opt to the short option corresponding to the long option
				__b3bp_tmp_varname="__b3bp_tmp_opt_long2short_${__b3bp_tmp_long_opt//-/_}"
				printf -v "__b3bp_tmp_opt" '%s' "${!__b3bp_tmp_varname}"
				OPTARG=${OPTARG#*=}
			else
				# --key value format
				# Map long name to short version of option
				__b3bp_tmp_varname="__b3bp_tmp_opt_long2short_${OPTARG//-/_}"
				printf -v "__b3bp_tmp_opt" '%s' "${!__b3bp_tmp_varname}"
				# Only assign OPTARG if option takes an argument
				__b3bp_tmp_varname="__b3bp_tmp_has_arg_${__b3bp_tmp_opt}"
				printf -v "OPTARG" '%s' "${@:OPTIND:${!__b3bp_tmp_varname}}"
				# shift over the argument if argument is expected
				((OPTIND+=__b3bp_tmp_has_arg_${__b3bp_tmp_opt}))
			fi
			# we have set opt/OPTARG to the short value and the argument as OPTARG if it exists
		fi
		__b3bp_tmp_varname="arg_${__b3bp_tmp_opt:0:1}"
		__b3bp_tmp_default="${!__b3bp_tmp_varname}"

		__b3bp_tmp_value="${OPTARG}"
		if [[ -z "${OPTARG}" ]] && [[ "${__b3bp_tmp_default}" = "0" ]]; then
			__b3bp_tmp_value="1"
		fi

		printf -v "${__b3bp_tmp_varname}" '%s' "${__b3bp_tmp_value}"
		debug "cli arg ${__b3bp_tmp_varname} = (${__b3bp_tmp_default}) -> ${!__b3bp_tmp_varname}"
	done
	set -o nounset # no more unbound variable references expected

	shift $((OPTIND-1))

	if [[ "${1:-}" = "--" ]] ; then
		shift
	fi
fi


### Automatic validation of required option arguments
##############################################################################

for __b3bp_tmp_varname in ${!__b3bp_tmp_has_arg_*}; do
	# validate only options which required an argument
	[[ "${!__b3bp_tmp_varname}" = "2" ]] || continue

	__b3bp_tmp_opt_short="${__b3bp_tmp_varname##*_}"
	__b3bp_tmp_varname="arg_${__b3bp_tmp_opt_short}"
	[[ "${!__b3bp_tmp_varname}" ]] && continue

	__b3bp_tmp_varname="__b3bp_tmp_opt_short2long_${__b3bp_tmp_opt_short}"
	printf -v "__b3bp_tmp_opt_long" '%s' "${!__b3bp_tmp_varname}"
	[[ "${__b3bp_tmp_opt_long:-}" ]] && __b3bp_tmp_opt_long=" (--${__b3bp_tmp_opt_long//_/-})"

	help "Option -${__b3bp_tmp_opt_short}${__b3bp_tmp_opt_long:-} requires an argument"
done


### Cleanup Environment variables
##############################################################################

for __tmp_varname in ${!__b3bp_tmp_*}; do
	unset -v "${__tmp_varname}"
done

unset -v __tmp_varname


### Externally supplied __usage. Nothing else to do here
##############################################################################

if [[ "${__b3bp_external_usage:-}" = "true" ]]; then
	unset -v __b3bp_external_usage
	return
fi


### Signal trapping and backtracing
##############################################################################

function __b3bp_cleanup_before_exit () {

	#removeTempFiles

	debug "Cleaning up. Done"
}
trap __b3bp_cleanup_before_exit EXIT

# requires `set -o errtrace`
__b3bp_err_report() {
	local error_code
	error_code=${?}
	error "Error in ${__file} in function ${1} on line ${2}"
	exit ${error_code}
}

# export LOG_LEVEL=7 # Shows INFO and DEBUG
# export LOG_LEVEL=6 # Shows INFO


# All of these go to STDERR, so you can use STDOUT for piping machine readable information to other software
#debug "Info useful to developers for debugging the application, not useful during operations
#info "Normal operational messages - may be harvested for reporting, measuring throughput, etc. - no action required."
#notice "Events that are unusual but not error conditions - might be summarized in an email to developers or admins to spot potential problems - no immediate action required."
#warning "Warning messages, not an error, but indication that an error will occur if action is not taken, e.g. file system 85% full - each item must be resolved within a given time. This is a debug message"
#error "Non-urgent failures, these should be relayed to developers or admins; each item must be resolved within a given time."
#critical "Should be corrected immediately, but indicates failure in a primary system, an example is a loss of a backup ISP connection."
#alert "Should be corrected immediately, therefore notify staff who can fix the problem. An example would be the loss of a primary ISP connection."
#emergency "A \"panic\" condition usually affecting multiple apps/servers/sites. At this level it would usually notify all tech staff on call."


function checkSet () {

	# This function inspects certain default variables (set in yaml by the user)
	# and ensures that there are set, if needs be. If they are set, directory 
	# or file targets are verified to exist


	debug "Function: checkset"

	# Ingore 'unbound' errors for the time being
	set +o nounset

	# shellcheck disable=SC2154
	if [ -z "${TODO_DIR+x}" ]; then

		help "Required variable \$TODO_DIR has not been set." 
		exit 77	 

	elif  [ ! -d "$TODO_DIR" ]; then


		help "The directory of \$TODO_DIR has been set to $TODO_DIR. However, this directory does not seem to exist."
		exit 77

	fi 



	# No more unbound errors expected
	set -o nounset


}

function generateID () {

	debug "Function: generateID"

	# This function generates a random (ish) five-character mixture
	# of upper and lower case characters

	seed=$(($(date +%s%n) + $RANDOM)) 
	echo $seed | md5 | base64 | head -c 5

}


function escapeRegEx () {

	debug "Function: escapeRegEx"
			pipedInput="$(cat)" # Capture input from Stdin

	# http://stackoverflow.com/a/2705678/120999
	echo "$pipedInput" | sed -e 's/[]\/$*.^|[]/\\&/g' | sed 's/\&/\\&/g'
}



function sourceFileHasTodo () {

	egrep -q "$todoTag" "$sourceFile" || return 1
}

function todoHasNoID () {

	[[ "$todoSource" != *"$idTagShort"* ]] || return 1
}

function todoHasID () {

	[[ "$todoSource" == *"$idTagShort"* ]] || return 1

}

function IDisInDoneFile () {

	debug "Function: IDisInDoneFile"
	egrep -q "$id" "$DONE_FILE"  || return 1



}

function NotMarkedAsDoneInSource () {

	[[ "$todoSource" != *"$doneTagShort"* ]] || return 1 

}

function MarkedAsDoneInSource () {

	[[ "$todoSource" == *"$doneTagShort"* ]] || return 1

}

function getTextOfTodosFromSource () {

	todosInSource=$(egrep "$todoTag" < "$sourceFile")

}

function addIDtoTodo () {

	debug "Function: addIDtoTodo"

	# This gets an ID and writes the todo item,
	# with ID, back to the source file

	newID="$(generateID)"
	debug "    New ID (\$newID): $newID"
	todoSourceEscaped="$(echo "$todoSource" | escapeRegEx )"
	todoSourceWithID=$(echo "$todoSource, ID:$newID")
	todoSourceWithIDescaped="$(echo "$todoSourceWithID" | escapeRegEx )"
	debug "    Current todo with ID added will look like: $todoSourceWithIDescaped"
	debug "    Current todo without ID will look like:    $todoSourceEscaped"

	# Now replace the old todo tag with the new one in the source file
	# whereas replacing just one might be very 
	# difficult
	# Solution might be to loop through file

	sourceText=$(cat "$sourceFile")

	if [[ "$DUMMY_RUN" = "true" ]]; then

		echo "[Dummy run:] Here the script would add an ID $newID to $todoSource in $sourceFile"

	else
		spliceOnce "$sourceText" "$todoSourceEscaped" "$todoSourceWithIDescaped" "overwrite" > "$sourceFile"
	fi



	debug "    Todo with ID $newID written to $sourceFile"

}

function spliceOnce () {

	debug "Function: spliceOnce"

	# Insert [multi-line] REPLACEMENT string
	# into [multi-line] SOURCE string
	# after the line matched by PATTERN


	# - takes the arguments:
	#   source, pattern, replacement
	# - returns multi-line text

	sourceText="$1"
	pattern="$2"
	replacement="$3"
	mode="$4"

done="false"

while read -r line; do
	if test "${line#*$pattern}" != "$line"; then

		if [[ "$mode" == "insert" ]]; then
			echo "$line"
		fi

		if [[ "$done" == "false" ]]; then

			if [[ "$line" == *"ID:"* ]]; then 
				echo "$line"
				continue
			fi

			echo "$line" | sed "s/$pattern/$replacement/g" 

		done="true"

	else
		echo "$line"

	fi

	continue	
fi
echo "$line"
done < <(echo "$sourceText" )

debug "Function: splice completed for pattern $pattern"

}

function addTodoInTodotxt () {

	debug "Function: addTodoInTodotxt"

	# This function inherits variables $todoSourceWithID
	# and $newID  

	getTodoContext

	debug "                         todoSourceSection (alpha)=$todoSourceSection"

	# Remove project info so we don't include this twice
	if [[ "$todoSourceSection" == *"+"* ]]; then

		todoSourceWithIDwithoutProject="$(echo $todoSource | sed "s@$todoProject@@")"
		todoSourceSection="$(echo $todoSourceSection | sed "s@ $todoProject@@")"
		debug "                         todoSourceWithIDwithoutProject is $todoSourceWithIDwithoutProject"
		debug "                         todoProject is $todoProject"

	else todoSourceWithIDwithoutProject="$todoSource"

	fi

	if [[ "$todoSourceSection" = "unknown" ]]; then


		todoTxtCommand="$(echo "$todoSourceWithIDwithoutProject $todoProject, ID:$newID, SOURCE:"${sourceFile##*/}"" | sed "s/$todoTag//g")"

	else

		todoTxtCommand="$(echo "$todoSourceWithIDwithoutProject $todoProject in '$todoSourceSection', ID:$newID, SOURCE:"${sourceFile##*/}"" | sed "s/$todoTag//g")"

	fi

	debug "    Command to be passed to todo.sh (\$todoTxtCommand): $todoTxtCommand"



	if [[ "$DUMMY_RUN" = "true" ]]; then

		echo "[Dummy run:] The command to be passed to todo.sh is: $todoTxtCommand"
	else
		todo.sh add "$todoTxtCommand"
	fi
}

function getIDfromTodoSource () {

	debug "Function: getIDfromTodoSource"

	# This function inherits the variables $todoSource

	id="$(echo "$todoSource" | egrep -o "$idTag")"
}

function getDoneFormOfTodoSource () {

	debug "                     Function: getDoneFormOfToDoSource"
	todoSourceWithIDescaped="$(echo "$todoSource" | escapeRegEx)"

	todoSourceWithIDescapedDone="$(echo "$todoSource" | sed "s/$(echo $todoTag)/$(echo $doneTag)/g" | sed 's/^\^//' | escapeRegEx)"

	debug "                     todoSourceWithIDescapedDone=$todoSourceWithIDescapedDone"


}

function writeDoneToSource () {

	# Now replace the old todo tag with the new one in the source file

	if [[ "$DUMMY_RUN" = "true" ]]; then

		echo "[Dummy run:] Here the script would mark $todoSourceWithID as done in the source file, $sourceFile"
	else
		sed -i "" "s/$(echo "$todoSourceWithIDescaped")/$(echo "$todoSourceWithIDescapedDone")/g" "$sourceFile"
	fi




}

function getTodotxtNumber () {


	todoTxtNumber="$(cat "$TODO_FILE" | egrep "$id" -n | egrep -o '^[0-9]*:' | sed 's/://')"

}


function getTodoSourceLine () {


	# todoSourceLine="$(cat "$sourceFile" | egrep "$todoSource" -n | egrep -o '^[0-9]*:' | sed 's/://')"
	todoSourceLine="0" # Can't quite get the above to work without an egrep error where it thinks
	# it has been passed an option
}



function setAsDoneInTodotxt () {


	if [[ "$DUMMY_RUN" = "true" ]]; then

		echo "[Dummy run:] Here the script would mark todo number $todoTxtNumber as done in the todotxt todo list"
	else
		todo.sh do "$todoTxtNumber"
	fi




}

function getTodoContext () {

	# Attempt to determine the context of the todo item
	# in the source file by finding the most recent heading

	debug "         Function: getTodoContext"
	debug "                   sourceFile is $sourceFile"
	debug "                   todoSourceEscaped is $todoSourceEscaped"
	debug "                  todoSourceWithIDescaped is $todoSourceWithIDescaped"
	todoSourceSection=""
	todoSourceSection="$(cat "$sourceFile" | tail -r | sed "/^>/ d" | sed -n "/$(echo "$todoSourceWithIDescaped")/,/#/p" | tail -1 | sed 's/#//g ; s/^ *//g')"

	
	if [[ "$DUMMY_RUN" = "true" ]]; then
		todoSourceSection="$(cat "$sourceFile" | tail -r | sed "/^>/ d" | sed -n "/$(echo "$todoSourceEscaped")/,/#/p" | tail -1 | sed 's/#//g ; s/^ *//g')"
	fi
		
	if [ -z "$todoSourceSection" ]; then

		todoSourceSection="unknown"

	fi



	todoProject=""
	if [[ "$todoSourceSection" == *"+"* ]]; then

		todoProject="$(echo "$todoSourceSection" | egrep -o "\+.*")"

	fi



	debug "         todoSourceSection is be $todoSourceSection"

}

# MAIN

debug "__i_am_main_script: ${__i_am_main_script}"
debug "__file: ${__file}"
debug "__dir: ${__dir}"
debug "__base: ${__base}"
debug "OSTYPE: ${OSTYPE}"

# shellcheck disable=SC2154
debug "arg_f: ${arg_f}"
# shellcheck disable=SC2154
debug "arg_u: ${arg_u}"
# shellcheck disable=SC2154
debug "arg_v: ${arg_v}"
# shellcheck disable=SC2154
debug "arg_h: ${arg_h}"

todoTag="^\- \[.\]"
doneTag="^\- \[x\]"
doneTagShort="- [x] "
idTag=" ID:....."
idTagShort=" ID:"

# Detect verbose mode
if [[ "${arg_v:?}" = "1" ]]; then
	set -o verbose
fi


# Detect scope
if [ ! -f "${arg_f}" ]; then
	error "Specified file not found"
	exit 77
else
	scope=${arg_f}
fi

# Detect dummy run
if [[ "${arg_u:?}" = "1" ]]; then
	DUMMY_RUN="true"
	echo "todoSync is in dummy run mode"
else
	DUMMY_RUN="false"
fi

# Detect debug mode
if [[ "${arg_d:?}" = "1" ]]; then
	# set -o xtrace
	LOG_LEVEL="7"
	# Enable error backtracing
	trap '__b3bp_err_report "${FUNCNAME:-.}" ${LINENO}' ERR
fi


checkSet # Have the shell variables refering to todo.txt files etc. been set?

sourceFile=${arg_f}


debug "--------------------------"
debug "Current file is: $sourceFile"



if sourceFileHasTodo ; then

	getTextOfTodosFromSource


	echo "$todosInSource" | while IFS= read -r todoSource

do

	debug "  Current todo item (\$todoSource): $todoSource"

	getTodoSourceLine 

	if todoHasNoID ; then

		debug "    Current todo does not contain an ID. Should be added to todo.txt."

		addIDtoTodo

		addTodoInTodotxt

	fi

	if  todoHasID ; then

		debug "    This todo appears to have an ID."

		getIDfromTodoSource

		debug "    ID is ..$id.."

		if IDisInDoneFile; then


			debug "      FOUND the task in the DONE file"

			# Check if todotxt version has different text; if so, update source

			if NotMarkedAsDoneInSource; then

				debug "      Not marked as done in the Source file"

				getDoneFormOfTodoSource

				debug "      Looking to replace $todoSourceWithIDescaped with $todoSourceWithIDescapedDone"

				writeDoneToSource

			fi

		else

			debug "      DID NOT FIND the task in the DONE file"

			# Check if todotxt version has different text; if so, update source

			# But is it marked as done in the source file? If so, mark it as done in the DONE file

			if MarkedAsDoneInSource; then
				debug "      Todo has been marked as done in source but is not marked"
				debug "      as done in the DONE file. We need to mark it as done."
				debug "      id is $id"   

				getTodotxtNumber
				debug "          todoTxtNumber is $todoTxtNumber"

				setAsDoneInTodotxt
			fi


		fi

		id=""
	fi
done


	fi

	debug "---------------"

