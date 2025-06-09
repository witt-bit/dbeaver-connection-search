#!/bin/bash

# version
VERSION="1.0.2";

# 定义 usage 信息
usage() {
  cat <<EOF
Usage: $(basename "$0") [options]
该脚本用于查询DBeaver的明文连接信息

Options:
  -h,   --help                       显示当前使用信息
  -v,   --version                    显示脚本的版本信息
  -d,   --dir                        设置dbeaver的workspace
  -f,   --grep                       显示过滤选项

Examples:
  $(basename "$0") -h
  $(basename "$0") -v
  $(basename "$0") -d /path
  $(basename "$0") -d /path --grep mysql
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      usage
      exit 0
      ;;
    -d|--dir|--workspace)
      WORKSPACE="$2";
      shift 2;
    ;;
    -f|--grep)
      keywords="$2";
      filter=1;
      shift 2;
    ;;
    -v|--version)
      echo "dbeaver-connection-search v${VERSION}."
      exit 0
      ;;
    *)
      echo -e "\033[31mUnknown option: $1\033[0m";
      usage
      exit 1
      ;;
  esac
done

if [[ -z "${WORKSPACE}" ]]; then
  echo "Workspace [] is required !";
  exit 1;
fi

CACHE_HOME="${HOME}/.cache/DBeaver/DecryptMetaCache"
DRAW_TABLE_URL="https://github.com/witt-bit/draw-shell-table/releases/download/1.0.0/draw_table.sh"

# Download draw_table.sh if not exists
if [ ! -f "${CACHE_HOME}/draw_table.sh" ]; then
  mkdir -p "${CACHE_HOME}";
  echo "Downloading draw_table.sh ."
  curl -s -L -o "${CACHE_HOME}/draw_table.sh" "$DRAW_TABLE_URL" || wget "$DRAW_TABLE_URL" -O "${CACHE_HOME}/draw_table.sh"
  if [ $? -ne 0 ]; then
    echo "Failed to download draw_table.sh"
    exit 1
  fi
fi

# /General/.dbeaver
WORKSPACE="${WORKSPACE%/}/General/.dbeaver";
if [ ! -f "${WORKSPACE}/data-sources.json" ] || [ ! -f "${WORKSPACE}/credentials-config.json" ]; then
  echo "Not DBeaver workspace !"
  exit 1
fi

# 解密文件，输出到${CACHE_HOME}/credentials.json下
decrypt-credentials-file() {
  openssl aes-128-cbc -d -K babb4a9f774ab853c96c2d653dfe544a \
  -iv 00000000000000000000000000000000 \
  -in "${WORKSPACE}/credentials-config.json" | dd bs=1 \
  skip=16 2>/dev/null > "${CACHE_HOME}/credentials.json"

  # Check if the decryption was successful
  if [ $? -ne 0 ]; then
    echo "Failed to decrypt credentials-config.json"
    exit 1
  fi
}

# 生成数据源原始信息
generate-meta() {
  decrypt-credentials-file;
  echo -e "DBeaver Connections Search" > "${CACHE_HOME}/datasource-meta.dat"
  echo -e "Connection Name\tUsername\tPassword" >> "${CACHE_HOME}/datasource-meta.dat"
  # Loop through each key-value pair in the connections object
  jq -c '.connections | to_entries[]' "${WORKSPACE}/data-sources.json" | while read -r connection_entry; do
    local connection_id=$(echo "${connection_entry}" | jq -r '.key')
    local connection=$(echo "${connection_entry}" | jq -r '.value')
    local connection_name=$(echo "$connection" | jq -r '.name')
    local username=$(jq -r --arg ID "$connection_id" '.[$ID]["#connection"].user' "${CACHE_HOME}/credentials.json")
    local password=$(jq -r --arg ID "$connection_id" '.[$ID]["#connection"].password' "${CACHE_HOME}/credentials.json")

    echo -e "${connection_name}\t${username}\t${password}" >> "${CACHE_HOME}/datasource-meta.dat"
  done
}

if [ -f "${CACHE_HOME}/datasource-meta.dat" ]; then
  # 获取文件的最后修改时间 (以秒为单位)
  PASSWD_MOD_TIME=$(stat -c %Y "${WORKSPACE}/credentials-config.json")
  DPASSWD_MOD_TIME=$(stat -c %Y "${CACHE_HOME}/datasource-meta.dat")

  if [ "$DPASSWD_MOD_TIME" -lt "$PASSWD_MOD_TIME" ]; then
    generate-meta
  fi
else
  generate-meta
fi

if [[ "$filter" -ne 1 ]]; then
  bash "${CACHE_HOME}/draw_table.sh" -15 -black < "${CACHE_HOME}/datasource-meta.dat"
  exit 0;
fi

result_file=$(mktemp);
head -n 2 "${CACHE_HOME}/datasource-meta.dat" > "${result_file}";

if [[ -n "${keywords}" ]]; then
    tail -n +3 "${CACHE_HOME}/datasource-meta.dat" | grep "${keywords}" >> "${result_file}";
else
    echo "No such result.";
    exit 0;
fi

bash "${CACHE_HOME}/draw_table.sh" -15 -black < "${result_file}";