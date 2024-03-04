#!/usr/bin/env bash
#
#-------------------------------------------------------
#
# autor: Luciano Brito
# author: Luciano Brito
#
#-------------------------------------------------------
#
# Creation
#
# Data: 28/02/2024 as 16:00
# Date: 02/28/2024 at 04:00 pm
#
#-------------------------------------------------------
#
# Contacts
#
# e-mail: lucianobrito.dev@gmail.com
# github: github.com/lucianobritodev
#
#-------------------------------------------------------
#
# Versions
#
# v1.0.0 - Project created
# v1.2.0 - Add Keycloack support
# v1.3.0 - Add Firebird support
#
#
#-------------------------------------------------------
#
# Para executar o script execute os seguintes comandos:
# To run the script run one of the following commands:
#
# ./docker-tools-installer.sh
#
# or
#
# bash docker-tools-installer.sh
#-------------------------------------------------------
#
#
####################### VARABLES #######################

#Colors
readonly TEXT_COLOR_RED='\033[0;31m'
readonly TEXT_COLOR_RED_BOLD='\033[1;31m'
readonly TEXT_COLOR_GREEM='\033[0;32m'
readonly TEXT_COLOR_GREEM_BOLD='\033[1;32m'
readonly TEXT_COLOR_PURPLE='\033[0;34m'
readonly TEXT_COLOR_PURPLE_BOLD='\033[1;34m'
readonly TEXT_COLOR_BLUE='\033[0;36m'
readonly TEXT_COLOR_BLUE_BOLD='\033[1;36m'
readonly COLOR_OFF='\033[0m'

#Messages
readonly SUCCESS_MESSAGE='foi instalado com sucesso!'
readonly ERROR_MESSAGE='não foi instalado!'
readonly ALREADY_MESSAGE='já está instalado!'

#System and Apps
readonly OS="$(cat /etc/os-release | grep '^NAME=' | sed 's/^NAME=//g;s/"//g' | tr [A-Z] [a-z])"
readonly VERSION_CODENAME="$(cat /etc/os-release | grep 'UBUNTU_CODENAME=' | sed 's/UBUNTU_CODENAME=//g')"
readonly DOCKER_BASE_VOLUMES=/opt/docker-volumes
readonly UBUNTU="ubuntu"
readonly LINUX_MINT="linuxmint"

#Logs
readonly LOG_FILE="$HOME/docker-tools-install.log"
readonly LOG_INFO="[${TEXT_COLOR_PURPLE_BOLD}INFO${COLOR_OFF}] --- "
readonly LOG_SUCCESS="[${TEXT_COLOR_GREEM_BOLD} OK ${COLOR_OFF}] --- "
readonly LOG_ERROR="[${TEXT_COLOR_RED_BOLD}ERRO${COLOR_OFF}] --- "
readonly LOG_DIVISOR="#############################################################################################"

#Password
readonly CONTAINER_PASSWORD_DEFAULT="Sysdba123$"
declare PASSWORD

####################### FUNCTIONS ######################

install_docker() {

    if ! [[ -x $(which docker) ]]; then

        # Add keyrings docker
        echo -e "${LOG_INFO} Instalando Docker..."
        echo "$PASSWORD" | sudo -S install -m 0755 -d /etc/apt/keyrings
        echo "$PASSWORD" | sudo -S curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        echo "$PASSWORD" | sudo -S chmod go+r /etc/apt/keyrings/docker.asc

        # Add the repository to Apt sources:
        echo "$PASSWORD" | sudo -S sh -c "echo 'deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable' >/etc/apt/sources.list.d/docker.list"
        echo "$PASSWORD" | sudo -S apt update
        echo "$PASSWORD" | sudo -S apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

        # Add group user
        echo "$PASSWORD" | sudo -S groupadd docker
        echo "$PASSWORD" | sudo -S usermod -aG docker "$USER"
        newgrp docker

        if [[ -x $(which docker) ]]; then
            echo -e "${LOG_SUCCESS} Docker ${SUCCESS_MESSAGE} $COLOR_OFF"
        else
            echo -e "${LOG_ERROR} Docker ${ERROR_MESSAGE} $COLOR_OFF"
        fi
    fi

    echo "$PASSWORD" | sudo -S systemctl restart docker.service
    sleep 3
    echo "$PASSWORD" | sudo -S mkdir -p "$DOCKER_BASE_VOLUMES"
    echo "$PASSWORD" | sudo -S chown -R "$USER" "$DOCKER_BASE_VOLUMES"
    echo "$PASSWORD" | sudo -S chmod -R 777 "$DOCKER_BASE_VOLUMES"

}

create_volume() {

    if ! [[ -d "$1" ]]; then
        echo -e "${LOG_INFO} Criando unidade de volume para $2 em: $1$COLOR_OFF"
        echo "${PASSWORD}" | sudo -S mkdir -p "$1"

        if [[ -d "$1" ]]; then
            echo -e "${LOG_SUCCESS} Volume $1 foi criado com sucesso! $COLOR_OFF"
        else
            echo -e "${LOG_ERROR} Volume $1 não foi criado! $COLOR_OFF"
        fi
    fi

    echo "${PASSWORD}" | sudo -S chown -R "$USER" "$1"
    echo "${PASSWORD}" | sudo -S chmod -R 777 "$1"

}

remove_container() {
    docker rm -f "$1"
}

install_oracle() {
    local TITLE_NAME="Oracle Database 23c"
    local CONTAINER_NAME="oracle-23c-dev"
    local CONTAINER_VOLUME=$DOCKER_BASE_VOLUMES/oracle
    local CONTAINER_USER="$USER"
    local CONTAINER_PORT=1521
    local CONTAINER_ID

    echo -e "${LOG_INFO} Instalando ${TITLE_NAME} Container ${COLOR_OFF}"
    create_volume "${CONTAINER_VOLUME}" "${CONTAINER_NAME}"
    remove_container "$CONTAINER_NAME"
    docker run --name ${CONTAINER_NAME} -p ${CONTAINER_PORT}:1521 -e ORACLE_PASSWORD=${CONTAINER_PASSWORD_DEFAULT} -e BASE_USER="${USER}" -v ${CONTAINER_VOLUME}:/opt/oracle/oradata -d gvenzl/oracle-free
    echo -e "${LOG_INFO} ${TITLE_NAME} está sendo inicializado... ${COLOR_OFF}"
    sleep 8

    CONTAINER_ID=$(docker ps -a | grep ${CONTAINER_NAME} | awk '{print $1}')

    RUNNING="$(docker ps -a | grep "${CONTAINER_ID}" | awk '{print $7}' | tr '[:upper:]' '[:lower:]' | xargs)"
    if [[ ${RUNNING} == 'up' ]]; then
        echo -e "${LOG_SUCCESS} ${TITLE_NAME} Container ${SUCCESS_MESSAGE} ${COLOR_OFF}"
        cat <<EOF >>"${LOG_FILE}"
$LOG_DIVISOR

Dados de conexão para $TITLE_NAME:
user admin: sys
password: $CONTAINER_PASSWORD_DEFAULT
type: Basic
host: localhost
port: $CONTAINER_PORT
service: FREE

CONTAINER_ID: $CONTAINER_ID
CONTAINER_NAME: $CONTAINER_NAME
CONTAINER_VOLUME: $CONTAINER_VOLUME

EOF
        docker stop "${CONTAINER_ID}"
    else
        echo -e "${LOG_ERROR} ${TITLE_NAME} Container ${ERROR_MESSAGE} ${COLOR_OFF}"
    fi

}

install_postgres() {
    local TITLE_NAME="PostgreSQL"
    local CONTAINER_NAME="postgres-dev"
    local CONTAINER_VOLUME=$DOCKER_BASE_VOLUMES/postgres
    local CONTAINER_USER=postgres
    local CONTAINER_PORT=5432
    local CONTAINER_ID

    echo -e "${LOG_INFO} Instalando ${TITLE_NAME} Container ${COLOR_OFF}"
    create_volume "$CONTAINER_VOLUME" "$CONTAINER_NAME"
    remove_container "$CONTAINER_NAME"
    docker run -e POSTGRES_USER="$CONTAINER_USER" -e POSTGRES_PASSWORD="$CONTAINER_PASSWORD_DEFAULT" --name "$CONTAINER_NAME" -p "$CONTAINER_PORT":5432 -v "$CONTAINER_VOLUME":/var/lib/postgresql -d postgres
    echo -e "${LOG_INFO} ${TITLE_NAME} está sendo inicializado... ${COLOR_OFF}"
    sleep 8

    CONTAINER_ID=$(docker ps -a | grep ${CONTAINER_NAME} | awk '{print $1}')
    RUNNING="$(docker ps -a | grep "$CONTAINER_NAME" | awk '{print $7}' | tr '[:upper:]' '[:lower:]' | xargs)"

    if [[ ${RUNNING} == 'up' ]]; then
        echo -e "${LOG_SUCCESS} ${TITLE_NAME} Container ${SUCCESS_MESSAGE} ${COLOR_OFF}"
        cat <<EOF >>"${LOG_FILE}"
$LOG_DIVISOR

Dados de conexão para $TITLE_NAME:
user: $CONTAINER_USER
password: $CONTAINER_PASSWORD_DEFAULT
host: localhost
port: $CONTAINER_PORT

CONTAINER_ID: $CONTAINER_ID
CONTAINER_NAME: $CONTAINER_NAME
CONTAINER_VOLUME: $CONTAINER_VOLUME

EOF
        docker stop "${CONTAINER_ID}"
    else
        echo -e "${LOG_ERROR} ${TITLE_NAME} Container ${ERROR_MESSAGE} ${COLOR_OFF}"
    fi
}

install_mysql() {
    local TITLE_NAME="MySQL"
    local CONTAINER_NAME="mysql-dev"
    local CONTAINER_VOLUME=$DOCKER_BASE_VOLUMES/mysql
    local CONTAINER_USER=root
    local CONTAINER_PORT=3306
    local CONTAINER_ID

    echo -e "${LOG_INFO} Instalando ${TITLE_NAME} Container ${COLOR_OFF}"
    create_volume "$CONTAINER_VOLUME" "$CONTAINER_NAME"
    remove_container "$CONTAINER_NAME"
    docker run -e MYSQL_ROOT_PASSWORD="$CONTAINER_PASSWORD_DEFAULT" --name "$CONTAINER_NAME" -p "$CONTAINER_PORT":3306 -v "$CONTAINER_VOLUME":/var/lib/mysql -d mysql
    echo -e "${LOG_INFO} ${TITLE_NAME} está sendo inicializado... ${COLOR_OFF}"
    sleep 8

    CONTAINER_ID=$(docker ps -a | grep ${CONTAINER_NAME} | awk '{print $1}')
    RUNNING="$(docker ps -a | grep "$CONTAINER_NAME" | awk '{print $7}' | tr '[:upper:]' '[:lower:]' | xargs)"

    if [[ ${RUNNING} == 'up' ]]; then
        echo -e "${LOG_SUCCESS} ${TITLE_NAME} ${SUCCESS_MESSAGE} ${COLOR_OFF}"
        cat <<EOF >>"${LOG_FILE}"
$LOG_DIVISOR

Dados de conexão para $TITLE_NAME:
user: $CONTAINER_USER
password: $CONTAINER_PASSWORD_DEFAULT
host: localhost
port: $CONTAINER_PORT

CONTAINER_ID: $CONTAINER_ID
CONTAINER_NAME: $CONTAINER_NAME
CONTAINER_VOLUME: $CONTAINER_VOLUME

EOF
        docker stop "${CONTAINER_ID}"
    else
        echo -e "${LOG_ERROR} ${TITLE_NAME} ${ERROR_MESSAGE} ${COLOR_OFF}"
    fi
}

install_sqlserver() {
    local TITLE_NAME="SqlServer"
    local CONTAINER_NAME="sqlserver-dev"
    local CONTAINER_VOLUME=$DOCKER_BASE_VOLUMES/sqlserver
    local CONTAINER_USER=sa
    local CONTAINER_PORT=1433
    local CONTAINER_ID

    echo -e "${LOG_INFO} Instalando ${TITLE_NAME} Container ${COLOR_OFF}"
    create_volume "$CONTAINER_VOLUME" "$CONTAINER_NAME"
    remove_container "$CONTAINER_NAME"
    docker run -e ACCEPT_EULA=Y -e MSSQL_SA_PASSWORD="$CONTAINER_PASSWORD_DEFAULT" --name "$CONTAINER_NAME" -p "$CONTAINER_PORT":1433 -v "$CONTAINER_VOLUME":/var/lib/sqlserver -d mcr.microsoft.com/mssql/server
    echo -e "${LOG_INFO} ${TITLE_NAME} está sendo inicializado... ${COLOR_OFF}"
    sleep 8

    CONTAINER_ID=$(docker ps -a | grep ${CONTAINER_NAME} | awk '{print $1}')
    RUNNING="$(docker ps -a | grep "$CONTAINER_NAME" | awk '{print $7}' | tr '[:upper:]' '[:lower:]' | xargs)"

    if [[ ${RUNNING} == 'up' ]]; then
        echo -e "${LOG_SUCCESS} ${TITLE_NAME} Container ${SUCCESS_MESSAGE} ${COLOR_OFF}"
        cat <<EOF >>"${LOG_FILE}"
$LOG_DIVISOR

Dados de conexão para $TITLE_NAME:
user: $CONTAINER_USER
password: $CONTAINER_PASSWORD_DEFAULT
host: localhost
port: $CONTAINER_PORT

CONTAINER_ID: $CONTAINER_ID
CONTAINER_NAME: $CONTAINER_NAME
CONTAINER_VOLUME: $CONTAINER_VOLUME

EOF
        docker stop "${CONTAINER_ID}"
    else
        echo -e "${LOG_ERROR} ${TITLE_NAME} Container ${ERROR_MESSAGE} ${COLOR_OFF}"
    fi
}

install_firebird() {
    local TITLE_NAME="Firebird"
    local CONTAINER_NAME="firebird-dev"
    local CONTAINER_VOLUME=$DOCKER_BASE_VOLUMES/firebird
    local CONTAINER_USER=sysdba
    local CONTAINER_PORT=3050
    local CONTAINER_ID

    echo -e "${LOG_INFO} Instalando ${TITLE_NAME} Container ${COLOR_OFF}"
    create_volume "$CONTAINER_VOLUME" "$CONTAINER_NAME"
    remove_container "$CONTAINER_NAME"
    docker run -e TZ="America/Sao_Paulo" -e ISC_PASSWORD="$CONTAINER_PASSWORD_DEFAULT" --name "$CONTAINER_NAME" -p "$CONTAINER_PORT":3050 -v "$CONTAINER_VOLUME":/firebird -d jacobalberty/firebird
    echo -e "${LOG_INFO} ${TITLE_NAME} está sendo inicializado... ${COLOR_OFF}"
    sleep 8

    CONTAINER_ID=$(docker ps -a | grep ${CONTAINER_NAME} | awk '{print $1}')
    RUNNING="$(docker ps -a | grep "$CONTAINER_NAME" | awk '{print $7}' | tr '[:upper:]' '[:lower:]' | xargs)"

    if [[ ${RUNNING} == 'up' ]]; then
        echo -e "${LOG_SUCCESS} ${TITLE_NAME} Container ${SUCCESS_MESSAGE} ${COLOR_OFF}"
        cat <<EOF >>"${LOG_FILE}"
$LOG_DIVISOR

Dados de conexão para $TITLE_NAME:
user: $CONTAINER_USER
password: $CONTAINER_PASSWORD_DEFAULT
host: localhost
port: $CONTAINER_PORT

CONTAINER_ID: $CONTAINER_ID
CONTAINER_NAME: $CONTAINER_NAME
CONTAINER_VOLUME: $CONTAINER_VOLUME

EOF
        docker stop "${CONTAINER_ID}"
    else
        echo -e "${LOG_ERROR} ${TITLE_NAME} Container ${ERROR_MESSAGE} ${COLOR_OFF}"
    fi
}

install_activemq() {
    local TITLE_NAME="ActiveMQ Artemis"
    local CONTAINER_NAME="activemq-artemis-dev"
    local CONTAINER_USER=artemis
    local CONTAINER_ARTEMIS_PASSWORD=artemis
    local CONTAINER_PORT=61616
    local CONTAINER_ADMIN_CONSOLE_PORT=8161
    local CONTAINER_ID

    echo -e "${LOG_INFO} Instalando ${TITLE_NAME} Container ${COLOR_OFF}"
    remove_container "$CONTAINER_NAME"
    docker run --name "$CONTAINER_NAME" -p "$CONTAINER_PORT":61616 -p "$CONTAINER_ADMIN_CONSOLE_PORT":8161 -d apache/activemq-artemis:latest-alpine
    echo -e "${LOG_INFO} ${TITLE_NAME} está sendo inicializado... ${COLOR_OFF}"
    sleep 20

    CONTAINER_ID=$(docker ps -a | grep "$CONTAINER_NAME" | awk '{print $1}')
    RUNNING="$(docker ps -a | grep "$CONTAINER_NAME" | awk '{print $8}' | tr '[:upper:]' '[:lower:]' | xargs)"

    if [[ ${RUNNING} == 'up' ]]; then
        echo -e "${LOG_SUCCESS} ${TITLE_NAME} Container ${SUCCESS_MESSAGE} ${COLOR_OFF}"
        cat <<EOF >>"${LOG_FILE}"
$LOG_DIVISOR

Dados de conexão para $TITLE_NAME:
user: $CONTAINER_USER
password: $CONTAINER_ARTEMIS_PASSWORD
host: localhost
port: $CONTAINER_PORT
console admin: http://localhost:$CONTAINER_ADMIN_CONSOLE_PORT/console
rest api: http://localhost:$CONTAINER_ADMIN_CONSOLE_PORT/console/jolokia

CONTAINER_ID: $CONTAINER_ID
CONTAINER_NAME: $CONTAINER_NAME

EOF
        docker stop "${CONTAINER_ID}"
    else
        echo -e "${LOG_ERROR} ${TITLE_NAME} Container ${ERROR_MESSAGE} ${COLOR_OFF}"
    fi
}

install_rabbitmq() {
    local TITLE_NAME="RabbitMQ"
    local CONTAINER_NAME="rabbitmq-dev"
    local CONTAINER_USER=guest
    local CONTAINER_RABBIT_PASSWORD=guest
    local CONTAINER_PORT=5672
    local CONTAINER_ADMIN_CONSOLE_PORT=15672
    local CONTAINER_ID

    echo -e "${LOG_INFO} Instalando ${TITLE_NAME} Container ${COLOR_OFF}"
    remove_container "$CONTAINER_NAME"
    docker run -e RABBITMQ_DEFAULT_USER="$CONTAINER_USER" -e RABBITMQ_DEFAULT_PASS="$CONTAINER_RABBIT_PASSWORD" --name "$CONTAINER_NAME" -p "$CONTAINER_PORT":5672 -p "$CONTAINER_ADMIN_CONSOLE_PORT":15672 -d rabbitmq:3-management
    echo -e "${LOG_INFO} ${TITLE_NAME} está sendo inicializado... ${COLOR_OFF}"
    sleep 20

    CONTAINER_ID=$(docker ps -a | grep "$CONTAINER_NAME" | awk '{print $1}')
    RUNNING="$(docker ps -a | grep "$CONTAINER_NAME" | awk '{print $7}' | tr '[:upper:]' '[:lower:]' | xargs)"

    if [[ ${RUNNING} == 'up' ]]; then
        echo -e "${LOG_SUCCESS} ${TITLE_NAME} Container ${SUCCESS_MESSAGE} ${COLOR_OFF}"
        cat <<EOF >>"${LOG_FILE}"
$LOG_DIVISOR

Dados de conexão para $TITLE_NAME:
user: $CONTAINER_USER
password: $CONTAINER_ARTEMIS_PASSWORD
host: localhost
port: $CONTAINER_PORT
console admin: http://localhost:$CONTAINER_ADMIN_CONSOLE_PORT

CONTAINER_ID: $CONTAINER_ID
CONTAINER_NAME: $CONTAINER_NAME

EOF
        docker stop "${CONTAINER_ID}"
    else
        echo -e "${LOG_ERROR} ${TITLE_NAME} Container ${ERROR_MESSAGE} ${COLOR_OFF}"
    fi
}

install_keycloak() {
    local TITLE_NAME="KeyCloak"
    local CONTAINER_NAME="keycloack-dev"
    local CONTAINER_USER=admin
    local CONTAINER_KEYCLOAK_PASSWORD=admin
    local CONTAINER_PORT=8081
    local CONTAINER_ID

    echo -e "${LOG_INFO} Instalando ${TITLE_NAME} Container ${COLOR_OFF}"
    remove_container "$CONTAINER_NAME"
    docker run --name "$CONTAINER_NAME" -p "$CONTAINER_PORT":8080 -e KEYCLOAK_ADMIN="$CONTAINER_USER" -e KEYCLOAK_ADMIN_PASSWORD="$CONTAINER_KEYCLOAK_PASSWORD" -d quay.io/keycloak/keycloak:23.0.7 start-dev
    echo -e "${LOG_INFO} ${TITLE_NAME} está sendo inicializado... ${COLOR_OFF}"
    sleep 20

    CONTAINER_ID=$(docker ps -a | grep "$CONTAINER_NAME" | awk '{print $1}')
    RUNNING="$(docker ps -a | grep "$CONTAINER_NAME" | awk '{print $7}' | tr '[:upper:]' '[:lower:]' | xargs)"

    if [[ ${RUNNING} == 'up' ]]; then
        echo -e "${LOG_SUCCESS} ${TITLE_NAME} Container ${SUCCESS_MESSAGE} ${COLOR_OFF}"
        cat <<EOF >>"${LOG_FILE}"
$LOG_DIVISOR

Dados de conexão para $TITLE_NAME:
user: $CONTAINER_USER
password: $CONTAINER_KEYCLOAK_PASSWORD
host: localhost
port: $CONTAINER_PORT
console admin: http://localhost:$CONTAINER_PORT/admin
console account admin: http://localhost:$CONTAINER_PORT/realms/\${myrealm}/account

CONTAINER_ID: $CONTAINER_ID
CONTAINER_NAME: $CONTAINER_NAME

EOF
        docker stop "${CONTAINER_ID}"
    else
        echo -e "${LOG_ERROR} ${TITLE_NAME} Container ${ERROR_MESSAGE} ${COLOR_OFF}"
    fi
}

install_containers() {
    echo ""

    install_oracle
    install_postgres
    install_mysql
    install_sqlserver
    install_firebird
    install_activemq
    install_rabbitmq
    install_keycloak

}

finish() {

    echo ""
    echo "$LOG_DIVISOR" >>"$LOG_FILE"
    cat "$LOG_FILE"
    echo ""
    echo -e "$LOG_INFO As informações de conexão com os containers criados estão disponíveis em ${LOG_FILE}"
    echo ""

}

log_init() {

    rm -f "$LOG_FILE"
    touch "$LOG_FILE"
    cat <<EOF >"$LOG_FILE"
$LOG_DIVISOR
##################################  DOCKER TOOLS INSTALLER ##################################
EOF

}

main() {

    PASSWORD="$(zenity --title="Credenciais de usuário $(lsb_release -i | sed 's/.*://g;s/[\s|\t]//g')" --password)"
    [ "$PASSWORD" = '' ] && exit 1

    log_init
    install_docker
    install_containers
    finish
}

######################## EXECUTION #####################

main
