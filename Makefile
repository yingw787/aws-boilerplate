PWD ?= pwd_unknown

PROJECT_NAME = $(notdir $(PWD))

STAGE := dev
SERVICE_TARGET := backend
AWS_DEFAULT_REGION := eu-west-2
COMMIT_HASH := $(git describe --tags --first-parent --abbrev=11 --long --dirty --always)

ifeq ($(user),)
# USER retrieved from env, UID from shell.
HOST_USER ?= $(strip $(if $(USER),$(USER),nodummy))
HOST_UID ?= $(strip $(if $(shell id -u),$(shell id -u),4000))
else
# allow override by adding user= and/ or uid=  (lowercase!).
# uid= defaults to 0 if user= set (i.e. root).
HOST_USER = $(user)
HOST_UID = $(strip $(if $(uid),$(uid),0))
endif

THIS_FILE := $(lastword $(MAKEFILE_LIST))
CMD_ARGUMENTS ?= $(cmd)

export PROJECT_NAME
export HOST_USER
export HOST_UID

.PHONY: shell help build rebuild service login test clean prune
.EXPORT_ALL_VARIABLES:

shell:
ifeq ($(CMD_ARGUMENTS),)
	# no command is given, default to shell
	docker-compose -p $(PROJECT_NAME)_$(HOST_UID) run --rm $(SERVICE_TARGET) sh
else
	# run the command
	docker-compose -p $(PROJECT_NAME)_$(HOST_UID) run --rm $(SERVICE_TARGET) sh -c "$(CMD_ARGUMENTS)"
endif

help:
	@echo ''
	@echo 'Usage: make [TARGET] [EXTRA_ARGUMENTS]'
	@echo 'Targets:'
	@echo '  setup    	setup project for current user: $(HOST_USER)(uid=$(HOST_UID))'
	@echo '  build    	build docker --image-- for current user: $(HOST_USER)(uid=$(HOST_UID))'
	@echo '  rebuild  	rebuild docker --image-- for current user: $(HOST_USER)(uid=$(HOST_UID))'
	@echo '  test     	test docker --container-- for current user: $(HOST_USER)(uid=$(HOST_UID))'
	@echo '  service   	run as service --container-- for current user: $(HOST_USER)(uid=$(HOST_UID))'
	@echo '  login   	run as service and login --container-- for current user: $(HOST_USER)(uid=$(HOST_UID))'
	@echo '  clean    	remove docker --image-- for current user: $(HOST_USER)(uid=$(HOST_UID))'
	@echo '  prune    	shortcut for docker system prune -af. Cleanup inactive containers and cache.'
	@echo '  shell      run docker --container-- for current user: $(HOST_USER)(uid=$(HOST_UID))'
	@echo ''
	@echo 'Extra arguments:'
	@echo 'cmd=:	make cmd="whoami"'
	@echo '# user= and uid= allows to override current user. Might require additional privileges.'
	@echo 'user=:	make shell user=root (no need to set uid=0)'
	@echo 'uid=:	make shell user=dummy uid=4000 (defaults to 0 if user= set)'

install-local:
	# Install all service dependencies
	$(MAKE) -C services/backend install

setup-local: install-local
	# setup project
	docker volume create --name=$(PROJECT_NAME)-web-backend-db-data
	$(MAKE) migrate

up:
	# run as a (background) service
	docker-compose -p $(PROJECT_NAME)_$(HOST_UID) up --build --force-recreate

down:
	# run as a (background) service
	docker-compose -p $(PROJECT_NAME)_$(HOST_UID) down

login: up
	# run as a service and attach to it
	docker exec -it $(PROJECT_NAME)_$(HOST_UID) sh

build-backend:
	$(MAKE) -C services/backend build

build: build-backend
	#

clean:
	# remove created images
	@docker-compose -p $(PROJECT_NAME)_$(HOST_UID) down --remove-orphans --rmi all 2>/dev/null \
	&& echo 'Image(s) for "$(PROJECT_NAME):$(HOST_USER)" removed.' \
	|| echo 'Image(s) for "$(PROJECT_NAME):$(HOST_USER)" already removed.'

prune:
	# clean all that is not actively used
	docker system prune -af

test:
	# here it is useful to add your own customised tests
	docker-compose -p $(PROJECT_NAME)_$(HOST_UID) run --rm $(SERVICE_TARGET) sh -c '\
		echo "I am `whoami`. My uid is `id -u`." && echo "Docker runs!"' \
	&& echo success

makemigrations:
	docker-compose -p $(PROJECT_NAME)_$(HOST_UID) run --rm $(SERVICE_TARGET) sh -c "python ./manage.py makemigrations"

migrate:
	docker-compose -p $(PROJECT_NAME)_$(HOST_UID) run --rm $(SERVICE_TARGET) sh -c "python ./manage.py migrate"