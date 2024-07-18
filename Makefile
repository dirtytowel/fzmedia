CONFIG_FILE_PATH=$(HOME)/.config/fzmedia/config
INSTALL_PATH=/usr/local/bin

config:
	@if [ ! -f "$(CONFIG_FILE_PATH)" ]; then \
		echo "File $(CONFIG_FILE_PATH) not found. Creating from template..."; \
		mkdir -p "$(dir $(CONFIG_FILE_PATH))"; \
		cp config.template "$(CONFIG_FILE_PATH)"; \
		echo "Created $(CONFIG_FILE_PATH)"; \
	else \
		echo "File $(CONFIG_FILE_PATH) already exists."; \
	fi

install: config
	@echo "This step requires root privileges"
	@sudo cp fzmedia.sh $(INSTALL_PATH)/fzmedia && echo "Installed script at $(INSTALL_PATH)/fzmedia"
