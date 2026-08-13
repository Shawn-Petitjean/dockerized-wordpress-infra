LOGIN = $(or $(SUDO_USER),$(USER))
DATA_PATH = /home/$(LOGIN)/data
COMPOSE = docker-compose -f srcs/docker-compose.yml
all: up
up:
	mkdir -p $(DATA_PATH)/db_data
	mkdir -p $(DATA_PATH)/wp_data
	DATA_PATH=$(DATA_PATH) $(COMPOSE) up --build -d
stop:
	DATA_PATH=$(DATA_PATH) $(COMPOSE) stop
down:
	DATA_PATH=$(DATA_PATH) $(COMPOSE) down
clean: down
	DATA_PATH=$(DATA_PATH) $(COMPOSE) down --rmi all
fclean: clean
	sudo rm -rf $(DATA_PATH)/db_data
	sudo rm -rf $(DATA_PATH)/wp_data
re: fclean all
.PHONY: all up stop down clean fclean re