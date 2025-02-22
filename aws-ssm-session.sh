#!/bin/bash
trap '' 20
if [ -f /.dockerenv ]; then
    IS_CONTAINER=true
    NOBROWSER="--no-browser"
else
    IS_CONTAINER=false
fi
bold=$(tput bold)
normal=$(tput sgr0)
red=$(tput setaf 1)
yellow=$(tput setaf 3)
green=$(tput setaf 2)
t_changecolor() { echo "$1"; }
t_reset() { echo "${normal}"; }
rulem() { printf -v _hr "%*s" "$(tput cols)" && echo -en "${_hr// /${2--}}" && echo -e "\r\033[2C$1\n"; }
usage() {
echo -e "\nUsage:
aws-ssm-session.sh <-p aws-profile> <-i instance-id>

  -p (optional)    AWS CLI Profile defined in ~/.aws/config
  -i (optional)    Instance-ID to target with Session Manager\n"
}
export COLUMNS=0
clear
PS3=$'\n'"${bold}${yellow}Your selection >>> ${normal}"
while getopts 'p:i:hb' opt; do
  case "$opt" in
    p) SELECTEDPROFILE="${OPTARG}" ;;
    i) SELECTEDINSTANCE="${OPTARG}" ;;
    h) usage; exit ;;
    *) echo -e "\n${bold}${red}Error in argument${normal}"; exit ;;
  esac
done
echo -e "${bold}${green}"
echo "---------------------------------------------------------------------"
echo "    ___      _____   ___ ___ __  __   ___ ___ ___ ___ ___ ___  _  _  "
echo "   /_\ \    / / __| / __/ __|  \/  | / __| __/ __/ __|_ _/ _ \| \| | "
echo "  / _ \ \/\/ /\__ \ \__ \__ \ |\/| | \__ \ _|\__ \__ \| | (_) | .  | "
echo " /_/ \_\_/\_/ |___/ |___/___/_|  |_| |___/___|___/___\___/___/|_|\_| "
echo "                                                        by Gunslito  "
echo "---------------------------------------------------------------------"
echo -e "${normal}"
shift "$(($OPTIND -1))"
OPTCOMMAND=0
if [ -z "$SELECTEDPROFILE" ]; then
    let "OPTCOMMAND+=1"
    PFS=$(awk -F'[][]' '/profile / && !/sso_start_url/ {sub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' ~/.aws/config | sed 's/profile\ //g')
    PROFILES=($PFS)
    if [ ${#PROFILES[@]} -eq 0 ]; then
        echo "No AWS CLI profiles found. Please configure at least one using 'aws configure sso'."
        exit 1
    fi
    rulem "${bold}${green}[ Please select your AWS Profile ]${normal}" "="
    select opt in "${PROFILES[@]}"; do
        [ $REPLY -gt $((${#PROFILES[@]})) -o $REPLY -lt 1 ] && echo "Error, please select a valid option." || break
    done
    REPLYENV=$(echo "$REPLY")
    SELECTEDPROFILE=$(echo "${PROFILES[(($REPLYENV)-1)]}")
fi
echo -e "\n${normal}${bold}Selected profile: ${normal}${green}$SELECTEDPROFILE${normal}\n"
echo -e "⌚ ${bold}${yellow}Validating selected profile...${normal}"
aws --profile "$SELECTEDPROFILE" sts get-caller-identity > /dev/null 2>&1
if [ "$?" != 0 ]; then
    echo -e "${bold}${red}[INFO] SSO token expired. Logging out and retrying...${normal}"
    aws sso logout --profile "$SELECTEDPROFILE"
    aws sso login --profile "$SELECTEDPROFILE" ${NOBROWSER}
    aws --profile "$SELECTEDPROFILE" sts get-caller-identity > /dev/null 2>&1
    if [ "$?" != 0 ]; then
        echo -e "${bold}[${red}Error${normal}${bold}] - Problem with profile \"${bold}${green}$SELECTEDPROFILE\"${normal}${bold}, please try logging in manually.\n\n${green}aws sso login --profile $SELECTEDPROFILE${normal}\n\n"
        exit
    fi
fi
echo -e "${bold}${green}\nProfile \"$SELECTEDPROFILE\" authenticated successfully.\n${normal}"
declare -A INSTANCE_LIBRARY
if [ -z "$SELECTEDINSTANCE" ]; then
    let "OPTCOMMAND+=1"
    echo -e "⌚${bold}${yellow} Downloading target instance list...${normal}\n"
    INSTANCES_FILTERED=$(aws --profile $SELECTEDPROFILE ec2 describe-instances --filters "Name=tag:ssm,Values=enabled" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].[Tags[?Key=='Name']|[0].Value,InstanceId,Tags[?Key=='securitylevel']|[0].Value]" --output text)
    INSTANCES_FILTERED=$(echo "$INSTANCES_FILTERED" | awk '$NF == "1" || $NF == "2" || $NF == "3" || $NF == "4" {print $(NF-2), $2}')
    if [ -z "$INSTANCES_FILTERED" ]; then
        echo "No running instances found with required tags."
        exit 1
    fi
    IFSOLD=$IFS
    while read -r NAME ID; do
        [ -n "$NAME" ] && [ -n "$ID" ] && INSTANCE_LIBRARY["$NAME"]="$ID"
    done <<< "$(echo "$INSTANCES_FILTERED" | awk '{print $1, $2}')"
    IFS="$IFSOLD"
    rulem "[ Select target instance ]" "="
    select INSTANCE_NAME in "${!INSTANCE_LIBRARY[@]}"; do
        [ -n "$INSTANCE_NAME" ] && break
        echo "Error, please select a valid option."
    done
    SELECTEDINSTANCE="${INSTANCE_LIBRARY[$INSTANCE_NAME]}"
fi
IFS="$IFSTEMP"
if [ -z "$INSTANCE_NAME" ]; then
    INSTANCE_NAME=$(aws --profile $SELECTEDPROFILE ec2 describe-instances --instance-ids $SELECTEDINSTANCE --query "Reservations[*].Instances[*].[Tags[?Key=='Name'].Value]" --output text)
    if [ "$?" -ne 0 ]; then
        echo "${bold}${red}[ERROR] - Instance $SELECTEDINSTANCE not found.${normal}"
        exit
    fi
fi
echo -e "\n${normal}${bold}Selected instance: ${normal}${green}$INSTANCE_NAME ($SELECTEDINSTANCE)${normal}\n"
rulem "${bold}[ Starting Session Manager session ]${normal}" "="
aws --profile $SELECTEDPROFILE ssm start-session --target $SELECTEDINSTANCE
SSM_SESSION_STATUS=$?
rulem "${bold}[ Session ended ]${normal}" "="
if [ "$OPTCOMMAND" -gt 0 ]; then
    if [ "$IS_CONTAINER" = true ]; then
        echo -e "Command to connect in container mode:\n${bold}${green}docker run --rm -it -v \$HOME/.aws:/root/.aws aws-ssm-session -p $SELECTEDPROFILE -i $SELECTEDINSTANCE${normal}\n"
    else
        echo -e "Command to connect directly to ${yellow}${bold}$INSTANCE_NAME${normal}:\n${bold}${green}$(readlink -f "${BASH_SOURCE}") -p $SELECTEDPROFILE -i $SELECTEDINSTANCE${normal}\n"
    fi
    echo -e "\nSSH Proxy command (for SCP/SSH):"
    echo -e "${bold}${green}ssh -o ProxyCommand='aws --profile $SELECTEDPROFILE ssm start-session --target %h --document-name AWS-StartSSHSession --parameters portNumber=22' user@$SELECTEDINSTANCE${normal}\n"
    rulem "" "="
    set -m
fi
