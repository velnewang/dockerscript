#!/bin/sh

# Settings
TITLE=manage-redis-cluster
REDIS_IMAGE=redis:alpine
REDIS_FILES=/dockerdata/redis-cluster/
LOCAL_VOLUME=${REDIS_FILES}volume/
CONF_TMPL=${REDIS_FILES}${TITLE}.conf.tmpl
CONFIG_PUBLIC_SH=${REDIS_FILES}${TITLE}.public.sh
CONFIG_PRIVATE_SH=${REDIS_FILES}${TITLE}.private.sh
PORT_START=7000
TIMEOUT=2000
NODES=6
REPLICAS=1

# Config
if test -f ${CONFIG_PUBLIC_SH}; then
	. ${CONFIG_PUBLIC_SH}
fi
if test -f ${CONFIG_PRIVATE_SH}; then
	. ${CONFIG_PRIVATE_SH}
fi


PORT_END=$((PORT_START+NODES-1))
PORTS=`seq ${PORT_START} ${PORT_END}`
case "$1" in
	init)
		for port in ${PORTS}; do
			mkdir -p ${LOCAL_VOLUME}${port}/data
			mkdir -p ${LOCAL_VOLUME}${port}/conf
			PORT=${port} TIMEOUT=${TIMEOUT} envsubst < ${CONF_TMPL} > ${LOCAL_VOLUME}${port}/conf/redis.conf
		done
		;;
	create)
		for port in ${PORTS}; do
			docker run -d -it \
				-p ${port}:${port} -p 1${port}:1${port} \
				-v ${LOCAL_VOLUME}${port}/conf/redis.conf:/usr/local/etc/redis/redis.conf \
				-v ${LOCAL_VOLUME}${port}/data:/data \
				--name redis-${port} --restart always --sysctl net.core.somaxconn=1024 \
				${REDIS_IMAGE} redis-server /usr/local/etc/redis/redis.conf;
		done
		;;
	cluster)
		REDIS_SOCKETS=""
		for port in ${PORTS}; do
			NODE_IP=`docker container inspect redis-${port} --format {{.NetworkSettings.IPAddress}}`
			REDIS_SOCKETS="${REDIS_SOCKETS} ${NODE_IP}:${port}"
		done
		echo docker run --rm -it --network=host ${REDIS_IMAGE} \
			redis-cli \
			--cluster create ${REDIS_SOCKETS} \
			--cluster-replicas ${REPLICAS}
		;;
	stop)
		for port in ${PORTS}; do
			docker stop redis-${port}
		done
		;;
	start)
		for port in ${PORTS}; do
			docker start redis-${port}
		done
		;;
	status | check)
		docker run --rm -it --network=host ${REDIS_IMAGE} redis-cli --cluster check localhost:${PORT_START}
		;;
	delete)
		for port in ${PORTS}; do
			docker container rm redis-${port}
		done
		;;
	clean)
		for port in ${PORTS}; do
			echo rm -rf ${LOCAL_VOLUME}${port}/
			rm -rf ${LOCAL_VOLUME}${port}/
		done
		;;
	temp)
		docker run --rm -it --network=host ${REDIS_IMAGE} redis-cli -c -h localhost -p ${PORT_START}
		;;
	*)
		echo "{init|create|cluster|start|stop|status|check|delete|clean|temp}"
		exit 1
esac

