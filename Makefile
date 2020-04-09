# Makefile

DOCKER_REPO=ngenetzky/dsind
DOCKER_TAG=latest
IMAGE_NAME=${DOCKER_REPO}:${DOCKER_TAG}

################################################################################
# This will output the help for each task
# thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
help: ## This help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
################################################################################

.PHONY: help
.DEFAULT_GOAL := help

build: ## Build the image
	docker build -t "${DOCKER_REPO}:${DOCKER_TAG}" ./

run: ## Run the container
	docker run -it -u 0:0 "${DOCKER_REPO}:${DOCKER_TAG}"
