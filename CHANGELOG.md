# Changelog

### v0.11, Feb 15, 2024

- add disable=gems to ruby shebang for faster exec
- remvoe duplicate rd option for hidden files

### v0.8, Aug 32, 2023

- README.md updates and fix for worktrees vs repos

### v0.7, July 17, 2023

- More fixes to tmux-git to work in and out of tmux

### v0.6, July 12, 2023

- fix tmux-git to work inside and outside tmux

### v0.5, July 12, 2023

- remove some debuggin

### v0.4, July 12, 2023

- fix current_dir resolv of symlink tmux-git use
- fix misspelled vars
- get autoload of vim to work
- get second pane to load

### v0.3, July 11, 2023

- fix bug with rake release on '-F'
- moved everything to real tmux options
- add dependency on fd
- add env.sh to reuse vars and functions
- add default session launcher script
- set launcher so it can be overridden by option
- update README with all new option info

### v0.2, July 10, 2023

- add gitattribute for eol
- add LICENSE
- add dependency info to README
- add Rakefile to make tasks easier

### v0.1, July 10, 2023

- Initial functional commit
- <prefix>f open a :Files like menu for repos in $WORK
- <prefix>b open a :Buffers like meno for tmux sessions
- project correctly installs via tpm
- tmux-git install script correctly links to $HOME/tmux-git
  enabling use from cli outside of tmux
  
