#!/bin/bash

# https://github.com/kaicataldo/dotfiles/blob/master/bin/install.sh

# This symlinks all the dotfiles (and .atom/) to ~/
# It also symlinks ~/bin for easy updating

# This is safe to run multiple times and will prompt you about anything unclear


#
# Utils
#
function ask_for_sudo() {
    info "Prompting for sudo password..."
    if sudo --validate; then
        # Keep-alive
        while true; do sudo --non-interactive true; \
            sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
        success "Sudo credentials updated."
    else
        error "Obtaining sudo credentials failed."
        exit 1
    fi
}

function login_to_app_store() {
    info "Logging into app store..."
    if mas account >/dev/null; then
        success "Already logged in."
    else
        open -a "/Applications/App Store.app"
        until (mas account > /dev/null);
        do
            sleep 3
        done
        success "Login to app store successful."
    fi
}

function install_homebrew() {
    info "Installing Homebrew..."
    if hash brew 2>/dev/null; then
        success "Homebrew already exists."
    else
url=https://raw.githubusercontent.com/Sajjadhosn/dotfiles/master/installers/homebrew_installer
        if /usr/bin/ruby -e "$(curl -fsSL ${url})"; then
            success "Homebrew installation succeeded."
        else
            error "Homebrew installation failed."
            exit 1
        fi
    fi
}

function install_packages_with_brewfile() {
    info "Installing packages within ${DOTFILES_REPO}/brew/macOS.Brewfile ..."

    if brew bundle check --file=$DOTFILES_REPO/brew/macOS.Brewfile; then
        info "brew bundle check --file=$DOTFILES_REPO/brew/macOS.Brewfile"
    else
        if brew bundle --file=$DOTFILES_REPO/brew/macOS.Brewfile; then
            success "Brewfile installation succeeded."
        else
            error "Brewfile installation failed."
            exit 1
        fi
    fi
}

function brew_install() {
    package_to_install="$1"
    info "brew install ${package_to_install}"
    if hash "$package_to_install" 2>/dev/null; then
        success "${package_to_install} already exists."
    else
        if brew install "$package_to_install"; then
            success "Package ${package_to_install} installation succeeded."
        else
            error "Package ${package_to_install} installation failed."
            exit 1
        fi
    fi
}

function change_shell_to_zsh() {
    info "zsh shell setup..."
    if grep --quiet zsh <<< "$SHELL"; then
        success "zsh shell already exists."
    else
        user=$(whoami)
        substep "Adding zsh executable to /etc/shells"
        if grep --fixed-strings --line-regexp --quiet \
            "/usr/local/bin/zsh" /etc/shells; then
            substep "zsh executable already exists in /etc/shells"
        else
            if echo /usr/local/bin/zsh | sudo tee -a /etc/shells > /dev/null;
            then
                substep "zsh executable successfully added to /etc/shells"
            else
                error "Failed to add zsh executable to /etc/shells"
                exit 1
            fi
        fi
        substep "Switching shell to zsh for \"${user}\""
        if sudo chsh -s /usr/local/bin/zsh "$user"; then
            success "zsh shell successfully set for \"${user}\""
        else
            error "Please try setting the zsh shell again."
        fi
    fi
}

function configure_git() {
    username="nathanmlim"
    email="nathanmlim@gmail.com"

    info "Configuring git..."
    if git config --global user.name "$username" && \
       git config --global user.email "$email"; then
        success "git configuration succeeded."
    else
        error "git configuration failed."
    fi
}

function clone_dotfiles_repo() {
    info "Cloning dotfiles repository into ${DOTFILES_REPO} ..."
    if test -e $DOTFILES_REPO; then
        substep "${DOTFILES_REPO} already exists."
        pull_latest $DOTFILES_REPO
    else
        url=https://github.com/nathanmlim/dotfiles.git
        if git clone "$url" $DOTFILES_REPO; then
            success "Cloned into ${DOTFILES_REPO}"
        else
            error "Cloning into ${DOTFILES_REPO} failed."
            exit 1
        fi
    fi
}

function pull_latest() {
    info "Pulling latest changes in ${1} repository..."
    if git -C $1 pull origin master &> /dev/null; then
        success "Pull successful in ${1} repository."
    else
        error "Please pull the latest changes in ${1} repository manually."
    fi
}

function setup_vim() {
    info "Setting up vim..."
    substep "Installing Vundle"
    if test -e ~/.vim/bundle/Vundle.vim; then
        substep "Vundle already exists."
        pull_latest ~/.vim/bundle/Vundle.vim
    else
        url=https://github.com/VundleVim/Vundle.vim.git
        if git clone "$url" ~/.vim/bundle/Vundle.vim; then
            substep "Vundle installation succeeded."
        else
            error "Vundle installation failed."
            exit 1
        fi
    fi
    substep "Installing all plugins"
    if vim +PluginInstall +qall 2> /dev/null; then
        substep "Plugin installation succeeded."
    else
        error "Plugin installation failed."
        exit 1
    fi
    success "vim successfully setup."
}


function configure_iterm2() {
    info "Configuring iTerm2..."
    if \
        defaults write com.googlecode.iterm2 \
            LoadPrefsFromCustomFolder -int 1 && \
        defaults write com.googlecode.iterm2 \
            PrefsCustomFolder -string "${DOTFILES_REPO}/iTerm2";
    then
        success "iTerm2 configuration succeeded."
    else
        error "iTerm2 configuration failed."
        exit 1
    fi
    substep "Opening iTerm2"
    if osascript -e 'tell application "iTerm" to activate'; then
        substep "iTerm2 activation successful"
    else
        error "Failed to activate iTerm2"
        exit 1
    fi
}

function setup_symlinks() {
    #POWERLINE_ROOT_REPO=/anaconda/lib/python3.6/site-packages
    #POWERLINE_ROOT_REPO=~/.local/lib/python3.6/site-packages
    ln -s ${POWERLINE_ROOT_REPO}/scripts/powerline ~/.local/bin
    info "Setting up symlinks..."
    symlink "vim" ${DOTFILES_REPO}/vim/vimrc ~/.vimrc
    symlink "powerline" \
        ${DOTFILES_REPO}/powerline \
        ${POWERLINE_ROOT_REPO}/powerline/config_files

}

function symlink() {
    application=$1
    point_to=$2
    destination=$3
    destination_dir=$(dirname "$destination")

    if test ! -e "$destination_dir"; then
        substep "Creating ${destination_dir}"
        mkdir -p "$destination_dir"
    fi
    if rm -rf "$destination" && ln -s "$point_to" "$destination"; then
        success "Symlinking ${application} done."
    else
        error "Symlinking ${application} failed."
        exit 1
    fi
}

function update_hosts_file() {
    info "Updating /etc/hosts"

    if grep --quiet "someonewhocares" /etc/hosts; then
        success "/etc/hosts already updated."
    else
        substep "Backing up /etc/hosts to /etc/hosts_old"
        if sudo cp /etc/hosts /etc/hosts_old; then
            substep "Backup succeeded."
        else
            error "Backup failed."
            exit 1
        fi
        substep "Appending ${DOTFILES_REPO}/hosts/hosts content to /etc/hosts"
        if test -e ${DOTFILES_REPO}/hosts/hosts; then
            cat ${DOTFILES_REPO}/hosts/hosts | \
                sudo tee -a /etc/hosts > /dev/null
            success "/etc/hosts updated."
        else
            error "Failed to update /etc/hosts"
            exit 1
        fi
    fi
}

function setup_macOS_defaults() {
    info "Updating macOS defaults..."

    current_dir=$(pwd)
    cd ${DOTFILES_REPO}/macOS
    if bash defaults.sh; then
        cd $current_dir
        success "macOS defaults setup succeeded."
    else
        cd $current_dir
        error "macOS defaults setup failed."
        exit 1
    fi
}

function update_login_items() {
    info "Updating login items..."
    login_item /Applications/Alfred\ 3.app
    login_item /Applications/Amphetamine.app
    login_item /Applications/Bartender\ 3.app
    login_item /Applications/Docker.app
    login_item /Applications/Dropbox.app
    login_item /Applications/iTerm.app
    login_item /Applications/HighSierraMediaKeyEnabler.app
    login_item /Applications/Spectacle.app
    login_item /Applications/NordVPN.app
    login_item /Applications/1Password\ 7.app
    success "Login items successfully updated."
}

function login_item() {
    path=$1
    hidden=${2:-false}
    name=$(basename "$path")

    # "¬" charachter tells osascript that the line continues
    if osascript &> /dev/null << EOM
tell application "System Events" to make login item with properties ¬
{name: "$name", path: "$path", hidden: "$hidden"}
EOM
then
    success "Login item ${name} successfully added."
else
    error "Adding login item ${name} failed."
    exit 1
fi
}

function pip3_install() {
    packages_to_install=("$@")

    for package_to_install in "${packages_to_install[@]}"
    do
        info "pip install ${package_to_install}"
        if pip --quiet show "$package_to_install"; then
            success "${package_to_install} already exists."
        else
            if pip install "$package_to_install"; then
                success "Package ${package_to_install} installation succeeded."
            else
                error "Package ${package_to_install} installation failed."
                exit 1
            fi
        fi
    done
}

function install_zsh () {
  # Test to see if zshell is installed.  If it is:
  if [ -f /bin/zsh -o -f /usr/bin/zsh ]; then
    # Install Oh My Zsh if it isn't already present
    if [[ ! -d $dir/oh-my-zsh/ ]]; then
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
    fi
    # Set the default shell to zsh if it isn't currently set to zsh
    if [[ ! $(echo $SHELL) == $(which zsh) ]]; then
      chsh -s $(which zsh)
    fi
  else
    # If zsh isn't installed, get the platform of the current machine
    platform=$(uname);
    # If the platform is Linux, try an apt-get to install zsh and then recurse
    if [[ $platform == 'Linux' ]]; then
      if [[ -f /etc/redhat-release ]]; then
        sudo yum install zsh
        install_zsh
      fi
      if [[ -f /etc/debian_version ]]; then
        sudo apt-get install zsh
        install_zsh
      fi
    # If the platform is OS X, tell the user to install zsh :)
    elif [[ $platform == 'Darwin' ]]; then
      echo "We'll install zsh, then re-run this script!"
      brew install zsh
      exit
    fi
  fi
}
function coloredEcho() {
    local exp="$1";
    local color="$2";
    local arrow="$3";
    if ! [[ $color =~ '^[0-9]$' ]] ; then
       case $(echo $color | tr '[:upper:]' '[:lower:]') in
        black) color=0 ;;
        red) color=1 ;;
        green) color=2 ;;
        yellow) color=3 ;;
        blue) color=4 ;;
        magenta) color=5 ;;
        cyan) color=6 ;;
        white|*) color=7 ;; # white or invalid color
       esac
    fi
    tput bold;
    tput setaf "$color";
    echo "$arrow $exp";
    tput sgr0;
}

function info() {
    coloredEcho "$1" blue "========>"
}

function substep() {
    coloredEcho "$1" magenta "===="
}

function success() {
    coloredEcho "$1" green "========>"
}

function error() {
    coloredEcho "$1" red "========>"
}

answer_is_yes() {
  [[ "$REPLY" =~ ^[Yy]$ ]] \
    && return 0 \
    || return 1
}

ask() {
  print_question "$1"
  read
}

ask_for_confirmation() {
  print_question "$1 (y/n) "
  read -n 1
  printf "\n"
}

cmd_exists() {
  [ -x "$(command -v "$1")" ] \
    && printf 0 \
    || printf 1
}

execute() {
  $1 &> /dev/null
  print_result $? "${2:-$1}"
}

get_answer() {
  printf "$REPLY"
}

get_os() {

  declare -r OS_NAME="$(uname -s)"
  local os=""

  if [ "$OS_NAME" == "Darwin" ]; then
    os="osx"
  elif [ "$OS_NAME" == "Linux" ] && [ -e "/etc/lsb-release" ]; then
    os="ubuntu"
  fi

  printf "%s" "$os"

}

is_git_repository() {
  [ "$(git rev-parse &>/dev/null; printf $?)" -eq 0 ] \
    && return 0 \
    || return 1
}

mkd() {
  if [ -n "$1" ]; then
    if [ -e "$1" ]; then
      if [ ! -d "$1" ]; then
        print_error "$1 - a file with the same name already exists!"
      else
        print_success "$1"
      fi
    else
      execute "mkdir -p $1" "$1"
    fi
  fi
}

print_error() {
  # Print output in red
  printf "\e[0;31m  [✖] $1 $2\e[0m\n"
}

print_info() {
  # Print output in purple
  printf "\n\e[0;35m $1\e[0m\n\n"
}

print_question() {
  # Print output in yellow
  printf "\e[0;33m  [?] $1\e[0m"
}

print_result() {
  [ $1 -eq 0 ] \
    && print_success "$2" \
    || print_error "$2"

  [ "$3" == "true" ] && [ $1 -ne 0 ] \
    && exit
}

print_success() {
  # Print output in green
  printf "\e[0;32m  [✔] $1\e[0m\n"
}

# Warn user this script will overwrite current dotfiles
while true; do
  read -p "Warning: this will overwrite your current dotfiles. Continue? [y/n] " yn
  case $yn in
    [Yy]* ) break;;
    [Nn]* ) exit;;
    * ) echo "Please answer yes or no.";;
  esac
done

# Cloning Dotfiles repository for install_packages_with_brewfile
# to have access to Brewfile
clone_dotfiles_repo

# Get the dotfiles directory's absolute path
SCRIPT_DIR="$(cd "$(dirname "$0")"; pwd -P)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"


dir=~/dotfiles                        # dotfiles directory
dir_backup=~/dotfiles_old             # old dotfiles backup directory

# Get current dir (so run this script from anywhere)

export DOTFILES_DIR
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Create dotfiles_old in homedir
echo -n "Creating $dir_backup for backup of any existing dotfiles in ~..."
mkdir -p $dir_backup
echo "done"

# Change to the dotfiles directory
echo -n "Changing to the $dir directory..."
cd $dir
echo "done"

# Atom editor settings
echo -n "Copying Atom settings.."
mv -f ~/.atom ~/dotfiles_old/
ln -s $HOME/dotfiles/atom ~/.atom
echo "done"


declare -a FILES_TO_SYMLINK=(

  'shell/shell_aliases'
  'shell/shell_config'
  'shell/shell_exports'
  'shell/shell_functions'
  'shell/bash_profile'
  'shell/bash_prompt'
  'shell/bashrc'
  'shell/zshrc'
  'shell/ztheme'
  'shell/ackrc'
  'shell/curlrc'
  'shell/gemrc'
  'shell/inputrc'
  'shell/screenrc'

  'git/gitattributes'
  'git/gitconfig'
  'git/gitignore'

  'vim/vimrc'

)

# Move any existing dotfiles in homedir to dotfiles_old directory, then create symlinks from the homedir to any files in the ~/dotfiles directory specified in $files

for i in ${FILES_TO_SYMLINK[@]}; do
  echo "Moving any existing dotfiles from ~ to $dir_backup"
  mv ~/.${i##*/} ~/dotfiles_old/
done


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

main() {
  # First things first, asking for sudo credentials
  ask_for_sudo
  # Installing Homebrew, the basis of anything and everything
  install_homebrew

  local i=''
  local sourceFile=''
  local targetFile=''

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  for i in ${FILES_TO_SYMLINK[@]}; do

    sourceFile="$(pwd)/$i"
    targetFile="$HOME/.$(printf "%s" "$i" | sed "s/.*\/\(.*\)/\1/g")"

    if [ ! -e "$targetFile" ]; then
      execute "ln -fs $sourceFile $targetFile" "$targetFile → $sourceFile"
    elif [ "$(readlink "$targetFile")" == "$sourceFile" ]; then
      print_success "$targetFile → $sourceFile"
    else
      ask_for_confirmation "'$targetFile' already exists, do you want to overwrite it?"
      if answer_is_yes; then
        rm -rf "$targetFile"
        execute "ln -fs $sourceFile $targetFile" "$targetFile → $sourceFile"
      else
        print_error "$targetFile → $sourceFile"
      fi
    fi

  done

  unset FILES_TO_SYMLINK

  # Copy binaries
  ln -fs $HOME/dotfiles/bin $HOME

  declare -a BINARIES=(
    'batcharge.py'
    'crlf'
    'dups'
    'git-delete-merged-branches'
    'nyan'
    'passive'
    'proofread'
    'ssh-key'
    'weasel'
  )

  for i in ${BINARIES[@]}; do
    echo "Changing access permissions for binary script :: ${i##*/}"
    chmod +rwx $HOME/bin/${i##*/}
  done

  unset BINARIES

  # Symlink online-check.sh
  ln -fs $HOME/dotfiles/lib/online-check.sh $HOME/online-check.sh

  # Write out current crontab
  crontab -l > mycron
  # Echo new cron into cron file
  echo "* * * * * ~/online-check.sh" >> mycron
  # Install new cron file
  crontab mycron
  rm mycron

  install_zsh
  change_shell_to_zsh

  # Package managers & packages
  info "$DOTFILES_DIR/install/brew.sh"

  if [ "$(uname)" == "Darwin" ]; then
      info "$DOTFILES_DIR/install/brew-cask.sh"
  fi

  # Install Zsh settings
  ln -s ~/dotfiles/zsh/themes/nick.zsh-theme $HOME/.oh-my-zsh/themes

  # Configuring git config file
  configure_git
  # github.com/rupa/z - hooked up in .zshrc
  # consider reusing your current .z file if possible. it's painful to rebuild :)
  # or use autojump instead https://github.com/wting/autojump
  git clone https://github.com/rupa/z.git ~/z
  chmod +x ~/z/z.sh
  # Installing powerline-status so that setup_symlinks can setup the symlinks
  # and requests and dotenv as the basis for a regular python script
  export PATH=/usr/local/anaconda3/bin:${PATH}
  pip_packages=(powerline-status requests python-dotenv flake8)
  pip3_install "${pip_packages[@]}"

  # Setting up symlinks so that setup_vim can install all plugins
  #setup_symlinks
  # Setting up Vim
  setup_vim
  # Configuring iTerm2
  configure_iterm2

  # Only use UTF-8 in Terminal.app
  defaults write com.apple.terminal StringEncodings -array 4

  # Install the Solarized Dark theme for iTerm
  open "${HOME}/dotfiles/iterm/themes/Solarized Dark.itermcolors"

  # Don’t display the annoying prompt when quitting iTerm
  defaults write com.googlecode.iterm2 PromptOnQuit -bool false

  # Reload zsh settings
  source ~/.zshrc

  # Update /etc/hosts
  update_hosts_file
  # Setting up macOS defaults
  # setup_macOS_defaults
  #sh osx/set-defaults.sh
  # Updating login items
  #update_login_items

  # symlink atom
  ln -s /Applications/Atom.app/Contents/Resources/app/atom.sh /usr/local/bin/atom

  # Copy over Atom configs
  cp -r atom/packages.list $HOME/.atom

  # Install community packages
  apm list --installed --bare - get a list of installed packages
  apm install --packages-file $HOME/.atom/packages.list


}

main
