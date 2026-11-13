# How to build server
## Prerequisite
As the docker images are built from source in Linux environment, below tools are required:
- Docker community edition
- git


## Code Repositories
|Repo Name|Github Link|Branch Name|
|-|---|--|
|azerothcore-wotlk|https://github.com/mod-playerbots/azerothcore-wotlk|Playerbot|
|mod-playerbots|https://github.com/mod-playerbots/mod-playerbots|master|
|mod-autobalance|https://github.com/azerothcore/mod-autobalance|master|
|mod-individual-progression|https://github.com/ZhengPeiRu21/mod-individual-progression|master|
|mod-transmog|https://github.com/azerothcore/mod-transmog|master|
|mod-ale|https://github.com/azerothcore/mod-ale|master|
|mod-ah-bot|https://github.com/azerothcore/mod-ah-bot|master|
|mod-ollama-chat|https://github.com/DustinHendrickson/mod-ollama-chat|main|


For exploring available modules, access [Azerothcore Catalogue](https://www.azerothcore.org/catalogue.html#/)

## (Optional) Proxy Setting
This helps a lot when pulling packages/code in container
```bash
# Ubuntu 26.04
cat <<EOF | sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=http://[PROXY_IP]:[PROXY_PORT]"
Environment="HTTPS_PROXY=http://[PROXY_IP]:[PROXY_PORT]"
Environment="NO_PROXY=localhost,127.0.0.1,192.168.0.0/16"
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker
```

## Clone code and Build images locally
```bash
# Create WORK_DIR first, put everything into the folder
cd $WORK_DIR/
git clone https://github.com/mod-playerbots/azerothcore-wotlk --branch Playerbot --depth 1
cd azerothcore-wotlk/modules
# Clone required modules from github one by one
git clone <MODULE_GITHUB_LINK>
# Once the code is downloaded, build images from source
cd ../
DOCKER_IMAGE_TAG=v20261113 docker compose build
# Check images after image building
docker images
```





