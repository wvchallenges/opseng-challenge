#!/bin/bash

# Prints message using color in terminal
# Function from http://aarvik.dk/echo-colors/
# Usage: echo "Hej" | cecho ORANGE
cecho(){
  BLACK="\033[0;30m"
  BLUE="\033[0;34m"
  GREEN="\033[0;32m"
  CYAN="\033[0;36m"
  RED="\033[0;31m"
  PURPLE="\033[0;35m"
  ORANGE="\033[0;33m"
  LGRAY="\033[0;37m"
  DGRAY="\033[1;30m"
  LBLUE="\033[1;34m"
  LGREEN="\033[1;32m"
  LCYAN="\033[1;36m"
  LRED="\033[1;31m"
  LPURPLE="\033[1;35m"
  YELLOW="\033[1;33m"
  WHITE="\033[1;37m"
  NORMAL="\033[m"

  color=\$${1:-NORMAL}

  echo -ne "$(eval echo ${color})"
  cat

  echo -ne "${NORMAL}"
}

# Prints an error message to terminal
echoError() {
  local _MSG=$1

  echo $_MSG | cecho RED
}

# Prints a warning message to terminal
echoWarning() {
  local _MSG=$1

  echo $_MSG | cecho ORANGE
}

# Prints a success message to terminal
echoSuccess() {
  local _MSG=$1

  echo $_MSG | cecho GREEN
}

# Prints an info message to terminal
echoInfo() {
  local _MSG=$1

  echo $_MSG
}

# Prints a debug message to terminal
echoDebug() {
  local _MSG=$1

  echo $_MSG | cecho CYAN
}

echoStep() {
  local _MSG=$1

  echo "-> $_MSG"
}

printHelp() {
  cat << EOF
usage: $0 [-b|--branch-or-tag <branch-or-tag>][-h|--help]

-b|--branch-or-tag <branch-or-tag>  Sets the branch or tag name of the GitHub repository to deploy to AWS
-h|--help                           Prints this help message

Sets up required AWS resources and deploys Python app available here: https://github.com/wvchallenges/opseng-challenge-app
Thanks for this challenge! Julien
EOF
}

cleanupAndExit() {
  local _EXIT_CODE=$1

  if [ -f ./instance.id ]; then
    rm -f ./instance.id
  fi
  find /tmp -maxdepth 1 -type f -name "julien.*.out" -exec rm -f {} \;

  exit $_EXIT_CODE
}
