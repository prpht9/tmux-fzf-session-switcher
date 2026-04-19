# this file should be sourced to get all the variables and functions
_TFSS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

default_repo_selector_key=f
default_repo_path="$HOME/work"
default_session_switcher_key=b
default_session_window_split=0
default_session_vim_cmd=''
default_session_vim_options=''
default_session_launcher="$_TFSS_DIR/scripts/tfss-default-session-launcher"
default_new_repo_key=n

get_tmux_option() {
	local option="$1"
	local default_value="$2"
	local option_value=$(tmux show-option -gqv "$option")
	if [ -z "$option_value" ]; then
		echo "$default_value"
	else
		echo "$option_value"
	fi
}

get_bare_repo_prefix() {
	local bare_dir="$1"
	git -C "$bare_dir" config tfss.prefix 2>/dev/null
}

