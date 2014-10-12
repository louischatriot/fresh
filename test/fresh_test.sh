#!/bin/bash

assert_parse_fresh_dsl_args() {
  (
    set -e
    source bin/fresh
    _dsl_fresh_options # init defaults
    _parse_fresh_dsl_args "$@" > $SANDBOX_PATH/test_parse_fresh_dsl_args.out
    echo REPO_NAME="$REPO_NAME"
    echo FILE_NAME="$FILE_NAME"
    echo MODE="$MODE"
    echo MODE_ARG="$MODE_ARG"
    echo REF="$REF"
    echo MARKER="$MARKER"
    echo FILTER="$FILTER"
  ) > $SANDBOX_PATH/test_parse_fresh_dsl_args.log 2>&1
  echo EXIT_STATUS=$? >> $SANDBOX_PATH/test_parse_fresh_dsl_args.log
  assertFileMatches $SANDBOX_PATH/test_parse_fresh_dsl_args.out < /dev/null
  assertFileMatches $SANDBOX_PATH/test_parse_fresh_dsl_args.log
}

it_parses_fresh_dsl_args() {
  assert_parse_fresh_dsl_args aliases/git.sh <<EOF
REPO_NAME=
FILE_NAME=aliases/git.sh
MODE=
MODE_ARG=
REF=
MARKER=
FILTER=
EXIT_STATUS=0
EOF

  assert_parse_fresh_dsl_args twe4ked/dotfiles lib/tmux.conf --file=~/.tmux.conf <<EOF
REPO_NAME=twe4ked/dotfiles
FILE_NAME=lib/tmux.conf
MODE=file
MODE_ARG=~/.tmux.conf
REF=
MARKER=
FILTER=
EXIT_STATUS=0
EOF

  assert_parse_fresh_dsl_args jasoncodes/dotfiles .gitconfig --file <<EOF
REPO_NAME=jasoncodes/dotfiles
FILE_NAME=.gitconfig
MODE=file
MODE_ARG=
REF=
MARKER=
FILTER=
EXIT_STATUS=0
EOF

  assert_parse_fresh_dsl_args sedmv --bin <<EOF
REPO_NAME=
FILE_NAME=sedmv
MODE=bin
MODE_ARG=
REF=
MARKER=
FILTER=
EXIT_STATUS=0
EOF

  assert_parse_fresh_dsl_args scripts/pidof.sh --bin=~/bin/pidof <<EOF
REPO_NAME=
FILE_NAME=scripts/pidof.sh
MODE=bin
MODE_ARG=~/bin/pidof
REF=
MARKER=
FILTER=
EXIT_STATUS=0
EOF

  assert_parse_fresh_dsl_args twe4ked/dotfiles lib/tmux.conf --file=~/.tmux.conf --ref=abc1237 <<EOF
REPO_NAME=twe4ked/dotfiles
FILE_NAME=lib/tmux.conf
MODE=file
MODE_ARG=~/.tmux.conf
REF=abc1237
MARKER=
FILTER=
EXIT_STATUS=0
EOF

  assert_parse_fresh_dsl_args tmux.conf --file --marker <<EOF
REPO_NAME=
FILE_NAME=tmux.conf
MODE=file
MODE_ARG=
REF=
MARKER=#
FILTER=
EXIT_STATUS=0
EOF

  assert_parse_fresh_dsl_args vimrc --file --marker='"' <<EOF
REPO_NAME=
FILE_NAME=vimrc
MODE=file
MODE_ARG=
REF=
MARKER="
FILTER=
EXIT_STATUS=0
EOF

  assert_parse_fresh_dsl_args vimrc --file --filter='sed s/nmap/nnoremap/' <<EOF
REPO_NAME=
FILE_NAME=vimrc
MODE=file
MODE_ARG=
REF=
MARKER=
FILTER=sed s/nmap/nnoremap/
EXIT_STATUS=0
EOF

  assert_parse_fresh_dsl_args foo --file --marker= <<EOF
$ERROR_PREFIX Marker not specified.
EXIT_STATUS=1
EOF

  assert_parse_fresh_dsl_args foo --bin --marker <<EOF
$ERROR_PREFIX --marker is only valid with --file.
EXIT_STATUS=1
EOF

  assert_parse_fresh_dsl_args foo --marker=';' <<EOF
$ERROR_PREFIX --marker is only valid with --file.
EXIT_STATUS=1
EOF

  assert_parse_fresh_dsl_args foo --file --ref <<EOF
$ERROR_PREFIX You must specify a Git reference.
EXIT_STATUS=1
EOF

  assert_parse_fresh_dsl_args foo --filter <<EOF
$ERROR_PREFIX You must specify a filter program.
EXIT_STATUS=1
EOF

  assert_parse_fresh_dsl_args foo --file --bin <<EOF
$ERROR_PREFIX Cannot have more than one mode.
EXIT_STATUS=1
EOF

  assert_parse_fresh_dsl_args <<EOF
$ERROR_PREFIX Filename is required
EXIT_STATUS=1
EOF

  assert_parse_fresh_dsl_args foo bar baz <<EOF
$ERROR_PREFIX Expected 1 or 2 args.
EXIT_STATUS=1
EOF
}

it_escapes_arguments() {
  (
    set -e
    source bin/fresh
    _escape foo 'bar baz' > $SANDBOX_PATH/escape.out
  )
  assertTrue 'successfully escapes' $?
  assertFileMatches $SANDBOX_PATH/escape.out <<EOF
foo bar\\ baz
EOF
}

it_confirms_query_positive() {
  (
    set -e
    source bin/fresh
    echo y | _confirm 'Test question' > $SANDBOX_PATH/confirm.out
  )
  assertTrue 'returns true' $?
  echo -n 'Test question [Y/n]? ' | assertFileMatches $SANDBOX_PATH/confirm.out
}

it_confirms_query_negative() {
  (
    set -e
    source bin/fresh
    echo n | _confirm 'Test question' > $SANDBOX_PATH/confirm.out
  )
  assertFalse 'returns false' $?
  echo -n 'Test question [Y/n]? ' | assertFileMatches $SANDBOX_PATH/confirm.out
}

it_confirms_query_default() {
  (
    set -e
    source bin/fresh
    echo | _confirm 'Test question' > $SANDBOX_PATH/confirm.out
  )
  assertTrue 'returns true' $?
  echo -n 'Test question [Y/n]? ' | assertFileMatches $SANDBOX_PATH/confirm.out
}

it_confirms_query_invalid() {
  (
    set -e
    source bin/fresh
    echo -e "blah\ny" | _confirm 'Test question' > $SANDBOX_PATH/confirm.out
  )
  assertTrue 'returns true' $?
  echo -n 'Test question [Y/n]? Test question [Y/n]? ' | assertFileMatches $SANDBOX_PATH/confirm.out
}

it_adds_lines_to_freshrc_for_local_files() {
  mkdir -p $FRESH_PATH/source/user/repo/.git
  touch $FRESH_PATH/source/user/repo/file

  echo 'fresh existing' >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL
  touch $FRESH_LOCAL/{existing,new\ file}

  yes | runFresh 'new file'
  assertTrue 'successfully adds' $?

  assertFileMatches $FRESH_RCFILE <<EOF
fresh existing
fresh new\\ file
EOF
  assertFileMatches $SANDBOX_PATH/out.log <<EOF
Add \`fresh new\\ file\` to $FRESH_RCFILE [Y/n]? Adding \`fresh new\\ file\` to $FRESH_RCFILE...
$(echo $'Your dot files are now \033[1;32mfresh\033[0m.')
EOF
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
EOF
}

it_adds_lines_to_freshrc_for_new_remotes() {
  stubGit

  yes | runFresh user/repo file
  assertTrue 'successfully adds' $?

  assertFileMatches $FRESH_RCFILE <<EOF
fresh user/repo file
EOF
  assertFileMatches $SANDBOX_PATH/out.log <<EOF
Add \`fresh user/repo file\` to $FRESH_RCFILE [Y/n]? Adding \`fresh user/repo file\` to $FRESH_RCFILE...
$(echo $'Your dot files are now \033[1;32mfresh\033[0m.')
EOF
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
EOF
  assertFileMatches $SANDBOX_PATH/git.log <<EOF
cd $SANDBOX_PATH
git clone https://github.com/user/repo $FRESH_PATH/source/user/repo
EOF
}

it_adds_lines_to_freshrc_for_new_remotes_by_url() {
  stubGit

  yes | runFresh https://github.com/user/repo/blob/master/file
  assertTrue 'successfully adds' $?

  assertFileMatches $FRESH_RCFILE <<EOF
fresh user/repo file
EOF
  assertFileMatches $SANDBOX_PATH/out.log <<EOF
Add \`fresh user/repo file\` to $FRESH_RCFILE [Y/n]? Adding \`fresh user/repo file\` to $FRESH_RCFILE...
$(echo $'Your dot files are now \033[1;32mfresh\033[0m.')
EOF
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
EOF
  assertFileMatches $SANDBOX_PATH/git.log <<EOF
cd $SANDBOX_PATH
git clone https://github.com/user/repo $FRESH_PATH/source/user/repo
EOF
}

it_adds_lines_to_freshrc_for_existing_remotes_and_updates_if_the_file_does_not_exist() {
  mkdir -p $FRESH_PATH/source/user/repo/.git
  echo "touch \"$FRESH_PATH/source/user/repo/file\"" > "$FRESH_PATH/source/user/repo/.git/commands"

  stubGit

  yes | runFresh user/repo file
  assertTrue 'successfully adds' $?

  assertFileMatches $FRESH_RCFILE <<EOF
fresh user/repo file
EOF
  assertFileMatches $SANDBOX_PATH/out.log <<EOF
Add \`fresh user/repo file\` to $FRESH_RCFILE [Y/n]? Adding \`fresh user/repo file\` to $FRESH_RCFILE...
* Updating user/repo
| Current branch master is up to date.
$(echo $'Your dot files are now \033[1;32mfresh\033[0m.')
EOF
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
EOF
  assertFileMatches $SANDBOX_PATH/git.log <<EOF
cd $FRESH_PATH/source/user/repo
git pull --rebase
EOF
}

it_does_not_add_lines_to_freshrc_if_declined() {
  echo 'fresh existing' >> $FRESH_RCFILE
  mkdir -p $FRESH_LOCAL
  touch $FRESH_LOCAL/{existing,new}

  yes n | runFresh new
  assertTrue 'successfully adds' $?

  assertFileMatches $FRESH_RCFILE <<EOF
fresh existing
EOF
  assertFileMatches $SANDBOX_PATH/out.log <<EOF
Add \`fresh new\` to $FRESH_RCFILE [Y/n]? $(echo $'\033[1;33mNote\033[0m:') Use \`fresh edit\` to manually edit your $FRESH_RCFILE.
EOF
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
EOF
}

it_adds_lines_to_freshrc_without_updating_existing_repo_if_the_file_exists() {
  mkdir -p $FRESH_PATH/source/user/repo/.git
  touch $FRESH_PATH/source/user/repo/file

  stubGit

  yes | runFresh user/repo file
  assertTrue 'successfully adds' $?

  assertFileMatches $FRESH_RCFILE <<EOF
fresh user/repo file
EOF
  assertFileMatches $SANDBOX_PATH/out.log <<EOF
Add \`fresh user/repo file\` to $FRESH_RCFILE [Y/n]? Adding \`fresh user/repo file\` to $FRESH_RCFILE...
$(echo $'Your dot files are now \033[1;32mfresh\033[0m.')
EOF
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
EOF
  assertFalse 'did not run git' '[ -f $SANDBOX_PATH/git.log ]'
}

parse_fresh_add_args() {
  yes n | runFresh "$@"
  assertTrue "line matches" "grep -q '^Add \`fresh .*\` to' < $SANDBOX_PATH/out.log"
  sed -e 's/^Add `//' -e 's/`.*$//' $SANDBOX_PATH/out.log
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
EOF
}

it_adds_lines_to_freshrc_from_github_urls() {
  # auto add --bin
  assertEquals "fresh twe4ked/catacomb bin/catacomb --bin" "$(parse_fresh_add_args https://github.com/twe4ked/catacomb/blob/master/bin/catacomb)"

  # --bin will not duplicate
  assertEquals "fresh twe4ked/catacomb bin/catacomb --bin" "$(parse_fresh_add_args https://github.com/twe4ked/catacomb/blob/master/bin/catacomb --bin)"

  # works out --ref
  assertEquals "fresh twe4ked/catacomb bin/catacomb --bin --ref=a62f448" "$(parse_fresh_add_args https://github.com/twe4ked/catacomb/blob/a62f448/bin/catacomb)"

  # auto add --file
  assertEquals "fresh twe4ked/dotfiles config/pryrc --file" "$(parse_fresh_add_args https://github.com/twe4ked/dotfiles/blob/master/config/pryrc)"

  # --file will not duplicate
  assertEquals "fresh twe4ked/dotfiles config/pryrc --file" "$(parse_fresh_add_args https://github.com/twe4ked/dotfiles/blob/master/config/pryrc --file)"

  # auto add --file preserves other options
  assertEquals "fresh twe4ked/dotfiles config/pryrc --marker --file" "$(parse_fresh_add_args https://github.com/twe4ked/dotfiles/blob/master/config/pryrc --marker)"

  # doesn't add --bin or --file to other files
  assertEquals "fresh twe4ked/dotfiles shell/aliases/git.sh" "$(parse_fresh_add_args https://github.com/twe4ked/dotfiles/blob/master/shell/aliases/git.sh)"
}

it_edits_freshrc_files() {
  FRESH_RCFILE=~/.freshrc
  assertEquals "$HOME/.freshrc" "$(EDITOR=echo fresh edit)"
}

it_edits_linked_freshrc_files() {
  FRESH_RCFILE=~/.freshrc
  mkdir -p ~/.dotfiles/
  touch ~/.dotfiles/freshrc
  ln -s ~/.dotfiles/freshrc ~/.freshrc
  assertEquals "$HOME/.dotfiles/freshrc" "$(EDITOR=echo fresh edit)"
}

it_edits_relative_linked_freshrc_files() {
  FRESH_RCFILE=~/.freshrc
  mkdir -p ~/.dotfiles/
  touch ~/.dotfiles/freshrc
  ln -s .dotfiles/freshrc ~/.freshrc
  assertEquals "$HOME/.dotfiles/freshrc" "$(EDITOR=echo fresh edit)"
}

it_applies_fresh_options_to_multiple_lines() {
  echo 'fresh-options --file=~/.vimrc --marker=\"' >> $FRESH_RCFILE
  echo "fresh mappings.vim --filter='tr a x'" >> $FRESH_RCFILE
  echo "fresh autocmds.vim" >> $FRESH_RCFILE
  echo "fresh-options" >> $FRESH_RCFILE
  echo "fresh zshrc --file" >> $FRESH_RCFILE

  mkdir -p $FRESH_LOCAL
  echo "mappings" >> $FRESH_LOCAL/mappings.vim
  echo "autocmds" >> $FRESH_LOCAL/autocmds.vim
  echo "zsh config" >> $FRESH_LOCAL/zshrc

  runFresh

  assertFileMatches $FRESH_PATH/build/vimrc <<EOF
" fresh: mappings.vim # tr a x

mxppings

" fresh: autocmds.vim

autocmds
EOF

  assertFileMatches $FRESH_PATH/build/zshrc <<EOF
zsh config
EOF
}

it_runs_subcommands() {
  bin="$SANDBOX_PATH/bin/fresh-foo"
  echo "echo foobar" > $bin
  chmod +x $bin

  runFresh foo

  assertFileMatches $SANDBOX_PATH/out.log <<EOF
foobar
EOF
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
EOF
}

it_errors_for_unknown_commands() {
  runFresh fails foo
  assertFileMatches $SANDBOX_PATH/out.log <<EOF
EOF
  assertFileMatches $SANDBOX_PATH/err.log <<EOF
$ERROR_PREFIX Unknown command: foo
EOF
}

source test/test_helper.sh
