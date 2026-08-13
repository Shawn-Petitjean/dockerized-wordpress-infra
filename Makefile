LOGIN = $(or $(SUDO_USER),$(USER))
DATA_PATH = /home/$(LOGIN)/data
COMPOSE = docker-compose -f srcs/docker-compose.yml
all: up
up:
nmkdir -p $(DATA_PATH)/db_data
nmkdir -p $(DATA_PATH)/wp_data
n$(COMPOSE) up --build -d
stop:
n$(COMPOSE) stop
down:
n$(COMPOSE) down
clean: down
n$(COMPOSE) down --rmi all
fclean: clean
nsudo rm -rf $(DATA_PATH)/db_data
nsudo rm -rf $(DATA_PATH)/wp_data
re: fclean all
.PHONY: all up stop down clean fclean re