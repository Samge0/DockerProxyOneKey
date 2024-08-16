#!/bin/bash

show_help() {
  echo "用法: $0 [选项]"
  echo ""
  echo "选项:"
  echo "  services                  设置服务名称列表，用逗号分隔。可选的服务包括： hub, ghcr, gcr, k8sgcr, k8s, quay, mcr, elastic, ui, caddy"
  echo "  domain                    设置域名"
  echo "  reverse_proxy_server      设置反向代理服务地址"
  echo "  cf_token                  设置Cloudflare令牌"
  echo "  custom_cofigs_dir         设置自定义的配置目录，末尾不要带斜杠/，默认为 .cache/configs"

  echo "  proxy_ttl                 设置 proxy.ttl 的值，默认为 168h"

  echo "  health_enabled            设置 health.storagedriver.enabled 的值，默认为 true"
  echo "  health_interval           设置 health.storagedriver.interval 的值，默认为 10s"
  echo "  health_threshold          设置 health.storagedriver.threshold 的值，默认为 3"

  echo "  http_max_age              设置 http.headers.Access-Control-Max-Age 的值，默认为 1728000"

  echo "  storage_upload_enabled    设置 storage.maintenance.uploadpurging.enabled 的值，默认为 true"
  echo "  storage_upload_age        设置 storage.maintenance.uploadpurging.age 的值，默认为 168h"
  echo "  storage_upload_interval   设置 storage.maintenance.uploadpurging.interval 的值，默认为 24h"

  echo "  storage_readonly          设置 storage.maintenance.readonly 的值，默认为 false"

  echo "  update_yml                设置 是否允许更新yml配置文件的参数，默认为 false"

  echo "  proxy_url                 设置 代理ip地址，默认为空值"

  echo "  secret_key_base           设置 registry-ui中的SECRET_KEY_BASE，默认为随机值"
  echo ""
  echo "示例:"
  echo "  $0 --services hub,ui --domain your_domain.com --reverse_proxy_server http://127.0.0.1 --cf_token your_cloudflare_token"
  echo ""
  echo "如果未提供services参数，将默认启动所有服务。"
}

# 检查是否提供了 -h 或 --help 参数
if [[ "$#" -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
  show_help
  exit 0
fi

# 检查yq是否安装
if ! command -v yq &> /dev/null
then
    echo "yq 命令未找到，请先安装 yq。"
    exit 1
fi

# 检查openssl是否安装
if ! command -v openssl &> /dev/null
then
    echo "openssl 命令未找到，请先安装 openssl。"
    exit 1
fi

# 默认参数值
domain=""
reverse_proxy_server=""
cf_token=""

# 默认的 Caddy 配置目录
caddy_dir=".cache/caddy2"
caddyfile="$caddy_dir/Caddyfile"

# 配置文件的目录
configs_dir=".cache/configs"

# 可选的yml配置参数
update_yml="false"
proxy_ttl="168h"
health_enabled="true"
health_interval="10s"
health_threshold="3"
http_max_age="1728000"
storage_upload_enabled="true"
storage_upload_age="168h"
storage_upload_interval="24h"
storage_readonly="false"

# 代理ip地址
proxy_url=""

# 生成随机的 16 字节（32位十六进制字符）的密钥，并赋值给 secret_key_base
secret_key_base=$(openssl rand -hex 16)
# 打印生成的密钥（可选）
echo "Generated secret_key_base: $secret_key_base"

# 检查是否提供了参数
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --services)
      shift
      IFS=',' read -r -a containers <<< "$1"
      ;;
    --domain)
      shift
      domain="$1"
      ;;
    --reverse_proxy_server)
      shift
      reverse_proxy_server="$1"
      ;;
    --cf_token)
      shift
      cf_token="$1"
      ;;
    --custom_cofigs_dir)
      shift
      custom_cofigs_dir="$1"
      ;;
    --proxy_ttl)
      shift
      proxy_ttl="$1"
      ;;
    --health_enabled)
      shift
      health_enabled="$1"
      ;;
    --health_interval)
      shift
      health_interval="$1"
      ;;
    --health_threshold)
      shift
      health_threshold="$1"
      ;;
    --http_max_age)
      shift
      http_max_age="$1"
      ;;
    --storage_upload_enabled)
      shift
      storage_upload_enabled="$1"
      ;;
    --storage_upload_age)
      shift
      storage_upload_age="$1"
      ;;
    --storage_upload_interval)
      shift
      storage_upload_interval="$1"
      ;;
    --storage_readonly)
      shift
      storage_readonly="$1"
      ;;
    --update_yml)
      shift
      update_yml="$1"
      ;;
    --proxy_url)
      shift
      proxy_url="$1"
      ;;
    --secret_key_base)
      shift
      secret_key_base="$1"
      ;;
    *)
      echo "未识别的参数：$1"
      exit 1
      ;;
  esac
  shift
done



# ---------------------------------------------------- 生成 docker-compose.yaml 文件 ----------------------------------------------------
# 生成 docker-compose.yaml 文件
docker_compose_file="docker-compose.yaml"
cp docker-compose.dev.yaml "$docker_compose_file"

# 检查 SECRET_KEY_BASE 是否已定义并且是32位长度
if [ -z "$secret_key_base" ]; then
  echo "Error: secret_key_base is not defined."
  exit 1
elif [ ${#secret_key_base} -ne 32 ]; then
  echo "Error: secret_key_base must be exactly 32 characters long."
  exit 1
fi

# 动态替换随机密钥
sed -i "s/SECRET_KEY_BASE=.*/SECRET_KEY_BASE=$secret_key_base/" "$docker_compose_file"

# 动态替换 http 和 https 的环境变量为指定的代理地址
if [ -n "$proxy_url" ]; then
  # 替换 http 代理
  if ! sed -i "s|- http=$|- http=$proxy_url|g" "$docker_compose_file"; then
    echo "sed command failed: 替换 http 代理地址"
    exit 1
  fi

  # 替换 https 代理
  if ! sed -i "s|- https=$|- https=$proxy_url|g" "$docker_compose_file"; then
    echo "sed command failed: 替换 https 代理地址"
    exit 1
  fi
else
  echo "Info: Proxy URL is not defined, skipping proxy replacement."
fi

# 检查自定义配置目录是否存在并且是一个目录
if [ -n "$custom_cofigs_dir" ] && [ -d "$custom_cofigs_dir" ]; then
  if ! sed -i "s|- \./\.cache/configs|- $custom_cofigs_dir|g" "$docker_compose_file"; then
    echo "sed command failed: 替换自定义配置目录"
    exit 1
  fi
else
  echo "The directory '$custom_cofigs_dir' does not exist or is not a valid directory."
  exit 1
fi

# ---------------------------------------------------- 生成 docker-compose.yaml 文件 ----------------------------------------------------



# ---------------------------------------------------- 如果没有设置自定义的配置目录，则使用默认配置 ----------------------------------------------------
if [ -z "${custom_cofigs_dir}" ]; then
  # 检查 $configs_dir 是否存在，如果存在则删除它
  if [ -d "$configs_dir" ]; then
    rm -rf "$configs_dir"
  fi

  # 确保目标目录存在
  mkdir -p "$configs_dir"

  # 复制默认目录到./.cache/
  cp -r ./configs/* "$configs_dir"

  # 检查 $configs_dir 是否为空，如果为空则打印消息并退出
  if [ -z "$(find "$configs_dir" -type f)" ]; then
    echo "The directory $configs_dir is empty. Exiting the script."
    exit 1
  fi

  # 判断是否更新yml文件
  if [ "$update_yml" == "true" ]; then
    # 遍历目标目录下的所有yml文件，动态替换多个配置参数
    find "$configs_dir" -type f -name "*.yml" | while read -r file; do
      echo "Updating $file..."

      # 使用yq工具一次性替换多个参数值
      if ! yq eval "
        .proxy.ttl = \"$proxy_ttl\" |
        .health.storagedriver.enabled = $health_enabled |
        .health.storagedriver.interval = \"$health_interval\" |
        .health.storagedriver.threshold = $health_threshold |
        .http.headers.Access-Control-Max-Age = [$http_max_age] |
        .storage.maintenance.uploadpurging.enabled = $storage_upload_enabled |
        .storage.maintenance.uploadpurging.age = \"$storage_upload_age\" |
        .storage.maintenance.uploadpurging.interval = \"$storage_upload_interval\" |
        .storage.maintenance.readonly = $storage_readonly
      " -i "$file"; then
    echo "yq command failed: 替换自定义yml文件($file)"
    exit 1
  fi
    done
  fi

  echo "All YAML files in $target_dir have been updated."
fi
# ---------------------------------------------------- 如果没有设置自定义的配置目录，则使用默认配置 ----------------------------------------------------



# ---------------------------------------------------- 组装 需要运行的docker-compose 服务 ----------------------------------------------------
# 默认选择所有服务
if [ -z "${containers}" ]; then
  selected_services="hub ghcr gcr k8sgcr k8s quay mcr elastic ui caddy"
else
  # 定义一个空的容器列表
  selected_services=""

  # 循环检查哪些服务被选择
  for container in "${containers[@]}"; do
    case $container in
      hub)
        selected_services+="hub "
        ;;
      ghcr)
        selected_services+="ghcr "
        ;;
      gcr)
        selected_services+="gcr "
        ;;
      k8sgcr)
        selected_services+="k8sgcr "
        ;;
      k8s)
        selected_services+="k8s "
        ;;
      quay)
        selected_services+="quay "
        ;;
      mcr)
        selected_services+="mcr "
        ;;
      elastic)
        selected_services+="elastic "
        ;;
      ui)
        selected_services+="ui "
        ;;
      caddy)
        selected_services+="caddy "
        ;;
      *)
        echo "未识别的容器名称：$container"
        ;;
    esac
  done

  # 如果没有有效的服务被选择，退出脚本
  if [ -z "$selected_services" ]; then
    echo "没有有效的服务被选择。"
    exit 1
  fi
fi

# 显示参数信息
echo "Domain: $domain"
echo "Reverse Proxy: $reverse_proxy_server"
echo "CF Token: $cf_token"
# ---------------------------------------------------- 组装 需要运行的docker-compose 服务 ----------------------------------------------------



# ---------------------------------------------------- 组装 Caddyfile 文件 ----------------------------------------------------
# 检查必须的参数是否已设置
if [ -z "$domain" ] || [ -z "$reverse_proxy_server" ] || [ -z "$cf_token" ]; then
  echo "domain、reverse_proxy_server 和 cf_token 是必需的参数。"
  exit 1
fi

# 创建输出目录
mkdir -p "$caddy_dir/config"
mkdir -p "$caddy_dir/data"
mkdir -p "$caddy_dir/logs"

# 清空旧的 Caddyfile（如果存在）
> "$caddyfile"

# 模板定义
template="DOMAIN_VALUE {
    encode gzip
    reverse_proxy REVERSE_PROXY_VALUE
    tls {
        dns cloudflare CLOUDFLARE_API_TOKEN
    }
}"

# 从 docker-compose.yaml 中解析端口
get_service_port() {
  local service=$1
  local port=$(yq e ".services.$service.ports | .[] | split(\":\")[0]" docker-compose.yaml)
  echo "$port"
}

# 遍历选定的服务并生成 Caddyfile 条目
IFS=' ' read -r -a selected_service_list <<< "$selected_services"
for service in "${selected_service_list[@]}"; do

  # 如果是caddy的服务，不需要配置域名，跳过
  if [ "$service" == "caddy" ]; then
    continue 
  fi

  # 获取服务端口
  port=$(get_service_port "$service")
  
  if [ -z "$port" ]; then
    echo "未找到服务 $service 的端口映射。"
    exit 1
  fi
  
  # 拼接 REVERSE_PROXY_VALUE
  reverse_proxy_value="$reverse_proxy_server:$port"

  # 生成 Caddyfile 条目
  entry="${template//DOMAIN_VALUE/local$service.$domain}"
  entry="${entry//REVERSE_PROXY_VALUE/$reverse_proxy_value}"
  entry="${entry//CLOUDFLARE_API_TOKEN/$cf_token}"

  echo "$entry" >> "$caddyfile"
  echo "" >> "$caddyfile"  # 在每个条目之间添加空行
done

echo "Caddyfile 已生成并保存到 $caddyfile"
# ---------------------------------------------------- 组装 Caddyfile 文件 ----------------------------------------------------


# 使用 docker-compose 构建和启动指定的服务
docker-compose up -d $selected_services
