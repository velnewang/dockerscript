#/bin/sh

echo "get_script   : curl -fsSL https://get.docker.com -o get-docker.sh"
echo "script_source: https://github.com/docker/docker-install"

echo "date_static  : 2020-03-05T18:36:30Z"
echo "sha1_static  : 49374C43C7D3F72E1B9C41AC158987D88F85B486  get.docker.com.sh"
echo "sha1_current : $(sha1sum $(dirname $0)/get-docker.sh)"

echo "from_mirror_1: sh get-docker.sh --mirror Aliyun"
echo "from_mirror_2: sh get-docker.sh --mirror AzureChinaCloud"
