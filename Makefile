# Makefile

# Makefile util
SHELL := /bin/bash
# The directory of this file
DIR := $(shell echo $(shell cd "$(shell  dirname "${BASH_SOURCE[0]}" )" && pwd ))

DOCKER_REPO=ngenetzky/dsind
DOCKER_TAG=latest
IMAGE_NAME=${DOCKER_REPO}:${DOCKER_TAG}

DOCKER_ARGS_RUN=-v $(DIR):/mnt/

################################################################################
# This will output the help for each task
# thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
help: ## This help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
################################################################################

.PHONY: help
.DEFAULT_GOAL := help

build: ## Build the image
	${DIR}/hooks/build \
		"${DOCKER_REPO}" \
		"${DOCKER_TAG}"

run: ## Run the container
	docker run -it \
		--user 0:0 \
		"${DOCKER_REPO}:${DOCKER_TAG}"

login: ## Run login shell in the container
	docker run -it \
		--entrypoint /bin/bash \
		${DOCKER_ARGS_RUN} \
		"${DOCKER_REPO}:${DOCKER_TAG}" \
		--login

.PHONY: test
test: ## Run arbitrary test on the container
	docker run -it \
		--entrypoint /bin/bash \
		--workdir '/root/' \
		"${DOCKER_REPO}:${DOCKER_TAG}" \
		--login \
		-c "set -x && ( \
			cd .dsind/ \
			&& git ls-files \
			&& git log \
				--oneline \
				--graph \
				--name-only \
		)"
