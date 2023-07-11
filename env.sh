# this file should be sourced to get all the variables and functions
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

default_repo_selector_key=f
default_repo_path="$HOME/work"
default_session_switcher_key=b
default_session_window_split=0
default_session_vim_cmd=''
default_session_vim_options=''
default_session_launcher="$CURRENT_DIR/scripts/tfss-default-session-launcher"

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

