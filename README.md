## DockerProxyOneKey

在魔法服务器中一键部署docker的镜像加速服务，搭配[Caddy2](https://github.com/caddyserver/caddy)+[Cloudflare](https://dash.cloudflare.com/profile/api-tokens)自动配置TLS.

提供多平台镜像加速服务，支持 Docker、K8s、Quay、Ghcr、Mcr、Elastic 等多种镜像仓库。


## 背景
由于许多镜像仓库（如 Docker）位于国外，国内用户在下载镜像时速度较慢。尽管开源社区提供了一些免费的 Docker 镜像代理服务，但通常需要进行提交白名单等操作，稍微有点繁琐+需要等待审核/镜像同步等耗时。

本项目旨在简化这一过程，整合开源工具，通过一键脚本快速在自己服务器部署镜像加速服务，并利用 Caddy2 自动配置 TLS，为国内用户提供加速访问国外镜像仓库的解决方案。


## 快速使用
```shell
chmod +x run.sh
```
```shell
./run.sh \
--domain your_domain.com \
--reverse_proxy_server http://127.0.0.1 \
--cf_token your_cloudflare_token
```


## 可选操作

[可选] 指定镜像仓库
```shell
./run.sh \
--services hub,ui,caddy \
--domain your_domain.com \
--reverse_proxy_server http://127.0.0.1 \
--cf_token your_cloudflare_token
```

[可选] 自定义configs配置目录
```shell
./run.sh \
--services hub,ui,caddy \
--domain your_domain.com \
--reverse_proxy_server http://127.0.0.1 \
--cf_token your_cloudflare_token \
--custom_cofigs_dir /path/to/your/configs
```

[可选] 自定义yml配置文件中的参数
```shell
./run.sh \
--services hub,ui,caddy \
--domain your_domain.com \
--reverse_proxy_server http://127.0.0.1 \
--cf_token your_cloudflare_token \
--update_yml true \
--proxy_ttl 168h \
--health_enabled true \
--health_interval 10s \
--health_threshold 3 \
--http_max_age 1728000 \
--storage_upload_enabled true \
--storage_upload_age 168h \
--storage_upload_interval 24h \
--storage_readonly false
```

[可选] 参考脚本参数说明
```shell
./run.sh -h
```

[可选] 配置`htpasswd`验证<br>
如果需要`htpasswd`验证，请创建`htpasswd`文件并配置，[在线 htpasswd 生成器>>](https://tool.oschina.net/htpasswd)
```shell
touch .cache/htpasswd
```


## Cloudflare说明
- 购买一个便宜的域名
- 在[Cloudflare](https://dash.cloudflare.com)中添加域名，配置DNS记录，添加A记录+子域名泛解析，指向`IPv4`地址，开启CDN`Proxy`（小黄云）
- 在Cloudflare中[创建API Token](https://dash.cloudflare.com/profile/api-tokens)，并选择`Zone: Zone: DNS: Edit DNS`权限
- 在目标域名的`SSL/TLS`选项卡中开启HTTPS的`完全（严格）/ Full（Strict）`模式
![image](https://github.com/user-attachments/assets/c2ac3b10-8f00-487b-ac65-34e4b15b40ba)
![image](https://github.com/user-attachments/assets/cb27e29d-9945-4829-bc8d-7d285fc98938)



## 鸣谢
感谢以下开源项目的付出：
- [Docker-Proxy](https://github.com/dqzboy/Docker-Proxy)
- [public-image-mirror](https://github.com/DaoCloud/public-image-mirror)


### technical exchange
- [Join Discord >>](https://discord.com/invite/eRuSqve8CE)
- WeChat：`SamgeApp`


### disclaimer
This program is for technical communication only, and all behaviors of users have nothing to do with the author of this project.
