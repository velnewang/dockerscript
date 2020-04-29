#!/bin/sh

# Setting
DOCKER_DATA_DIR=/root/gitted/dockerscript
MYSQL_ROOT_PASSWORD=mypassword
MYSQL_DOCKER_IMAGE=mysql:8.0.19
MYSQL_ROOT_HOST=%
PORT_START=33061
NODES=2
TITLE=mysql
MANAGE_TMPL=mysql.cnf

MANAGE_TITLE=manage-${TITLE}
LOCAL_DIR=${DOCKER_DATA_DIR}/${TITLE}
LOCAL_VOLUME=${LOCAL_DIR}/volume
LOCAL_CONF_TMPL=${LOCAL_DIR}/${MANAGE_TITLE}.${MANAGE_TMPL}.tmpl
LOCAL_CONFIG_PUBLIC_SH=${LOCAL_DIR}/${MANAGE_TITLE}.public.sh
LOCAL_CONFIG_PRIVATE_SH=${LOCAL_DIR}/${MANAGE_TITLE}.private.sh
VOLUME_CONF=conf
VOLUME_DATA=data
VOLUME_LOGS=logs

# Config
if test -f ${LOCAL_CONFIG_PUBLIC_SH}; then
	. ${LOCAL_CONFIG_PUBLIC_SH}
fi
if test -f ${LOCAL_CONFIG_PRIVATE_SH}; then
	. ${LOCAL_CONFIG_PRIVATE_SH}
fi
PORTS=`seq ${PORT_START} $((PORT_START+NODES-1))`
CONTAINERS=""
for port in ${PORTS}; do
	CONTAINERS="${CONTAINERS} ${TITLE}-${port}"
done


# Command
case "$1" in
	start)
		docker start ${CONTAINERS}
		;;
	stop)
		docker stop ${CONTAINERS}
		;;
	delete)
		docker rm ${CONTAINERS}
		;;
	clean)
		for port in ${PORTS}; do
			echo rm -rf ${LOCAL_VOLUME}/${TITLE}-${port}/
			rm -rf ${LOCAL_VOLUME}/${TITLE}-${port}/
		done
		;;
	init)
		for port in ${PORTS}; do
			mkdir -p ${LOCAL_VOLUME}/${TITLE}-${port}/${VOLUME_CONF}
			mkdir -p ${LOCAL_VOLUME}/${TITLE}-${port}/${VOLUME_DATA}
			mkdir -p ${LOCAL_VOLUME}/${TITLE}-${port}/${VOLUME_LOGS}
		done
		echo [Done][1/2] mkdir in ${LOCAL_VOLUME}/
		for port in ${PORTS}; do
			SERVER_ID=${port} envsubst < ${LOCAL_CONF_TMPL} > ${LOCAL_VOLUME}/${TITLE}-${port}/${VOLUME_CONF}/${MANAGE_TMPL}
		done
		echo [Done][2/2] envsubst in ${LOCAL_VOLUME}/
		;;
	initialize)
		for port in ${PORTS}; do
			docker run \
			--name ${TITLE}-${port}-temp \
			--rm -d \
			-p ${port}:3306 \
			-v ${LOCAL_VOLUME}/${TITLE}-${port}/${VOLUME_CONF}:/etc/mysql/conf.d \
			-v ${LOCAL_VOLUME}/${TITLE}-${port}/${VOLUME_DATA}:/var/lib/mysql \
			-v ${LOCAL_VOLUME}/${TITLE}-${port}/${VOLUME_LOGS}:/var/log \
			-e MYSQL_ROOT_HOST=${MYSQL_ROOT_HOST} \
			-e MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD} \
			${MYSQL_DOCKER_IMAGE}
		done
		;;
	create)
		for port in ${PORTS}; do
			docker stop ${TITLE}-${port}-temp
			docker run \
			--name ${TITLE}-${port} \
			--restart unless-stopped \
			-d \
			-p ${port}:3306 \
			-v ${LOCAL_VOLUME}/${TITLE}-${port}/${VOLUME_CONF}:/etc/mysql/conf.d \
			-v ${LOCAL_VOLUME}/${TITLE}-${port}/${VOLUME_DATA}:/var/lib/mysql \
			-v ${LOCAL_VOLUME}/${TITLE}-${port}/${VOLUME_LOGS}:/var/log \
			-e MYSQL_ROOT_HOST=${MYSQL_ROOT_HOST} \
			${MYSQL_DOCKER_IMAGE}
		done
		;;
	dual)
		MASTER_LOG_VALS=""
		for port in ${PORTS}; do
			MASTER_STATUS=`
				docker run \
				--rm -it \
				--network=host \
				${MYSQL_DOCKER_IMAGE} \
				mysql -uroot -h127.0.0.1 -P${port} -p${MYSQL_ROOT_PASSWORD} \
				--default-character-set=utf8mb4 \
				-e "show master status" | grep "| mysql-bin." | awk '{print $2 " " $4}'`
			MASTER_LOG_VALS="${MASTER_LOG_VALS} ${MASTER_STATUS}"
		done
		MASTER_PORT_1=`echo ${PORTS}|awk '{print $1}'`
		IP_1=`docker container inspect ${TITLE}-${MASTER_PORT_1} --format {{.NetworkSettings.IPAddress}}`
		MASTER_LOG_FILE_1=`echo ${MASTER_LOG_VALS}|awk '{print $3}'`
		MASTER_LOG_POS_1=`echo ${MASTER_LOG_VALS}|awk '{print $4}'`
		echo "CHANGE MASTER TO master_host='${IP_1}',master_user='root',master_port=${MASTER_PORT_1},master_password='${MYSQL_ROOT_PASSWORD}',master_log_file='${MASTER_LOG_FILE_1}',master_log_pos=${MASTER_LOG_POS_1};"
		MASTER_PORT_2=`echo ${PORTS}|awk '{print $2}'`
		IP_2=`docker container inspect ${TITLE}-${MASTER_PORT_2} --format {{.NetworkSettings.IPAddress}}`
		MASTER_LOG_FILE_2=`echo ${MASTER_LOG_VALS}|awk '{print $3}'`
		MASTER_LOG_POS_2=`echo ${MASTER_LOG_VALS}|awk '{print $4}'`
		echo "CHANGE MASTER TO master_host='${IP_2}',master_user='root',master_port=${MASTER_PORT_2},master_password='${MYSQL_ROOT_PASSWORD}',master_log_file='${MASTER_LOG_FILE_2}',master_log_pos=${MASTER_LOG_POS_2};"
		;;
	*)
		echo "${MANAGE_TITLE}.sh {start|stop|create|delete} {init|initialize|clean} {status}"
		exit 1
esac









