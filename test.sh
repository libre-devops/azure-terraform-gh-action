#!/usr/bin/env bash

print_success() {
    lightcyan='\033[1;36m'
    nocolor='\033[0m'
    echo -e "${lightcyan}$1${nocolor}"
}

print_error() {
    lightred='\033[1;31m'
    nocolor='\033[0m'
    echo -e "${lightred}$1${nocolor}"
}

print_alert() {
    yellow='\033[1;33m'
    nocolor='\033[0m'
    echo -e "${yellow}$1${nocolor}"
}

print_alert "checkov version = $(print_success $(checkov --version))"
print_alert "tfsec version = $(print_success $(tfsec --version))"

print_alert "terraform-compliance version =" 
terraform-compliance --version

print_alert "terraform version = " 
terraform -v
