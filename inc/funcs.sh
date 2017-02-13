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
export -f echoError

# Prints a warning message to terminal
echoWarning() {
  local _MSG=$1

  echo $_MSG | cecho ORANGE
}
export -f echoWarning

# Prints a success message to terminal
echoSuccess() {
  local _MSG=$1

  echo $_MSG | cecho GREEN
}
export -f echoSuccess

# Prints an info message to terminal
echoInfo() {
  local _MSG=$1

  echo $_MSG
}
export -f echoInfo

# Prints a debug message to terminal
echoDebug() {
  local _MSG=$1

  echo $_MSG | cecho CYAN
}
export -f echoDebug

echoStep() {
  local _MSG=$1

  echo "-> $_MSG"
}
