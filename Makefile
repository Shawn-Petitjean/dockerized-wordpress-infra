LOGIN = $(or $(SUDO_USER),$(USER))
DATA_PATH = /home/$(LOGIN)/data
COMPOSE = docker-compose -f srcs/docker-compose.yml
all: up
up:
 	mkdir -p $(DATA_PATH)/db_data
 	mkdir -p $(DATA_PATH)/wp_data
 	$(COMPOSE) up --build -d
stop:
 	$(COMPOSE) stop
down:
 	$(COMPOSE) down
clean: down
 	$(COMPOSE) down --rmi all
fclean: clean
 	sudo rm -rf $(DATA_PATH)/db_data
 	sudo rm -rf $(DATA_PATH)/wp_data
re: fclean all
.PHONY: all up stop down clean fclean re