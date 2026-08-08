# Пути к файлам
NGINX_TEMPLATE = configs/nginx/site.local.conf.template
NGINX_CONF = configs/nginx/site.local.conf
SSL_KEY = ssl/site.local.key
SSL_CRT = ssl/site.local.crt
ENV_FILE = .env
ENV_TEMPLATE = .env.template

help:
	@echo "Доступные команды:"
	@echo "  make up             - Подготовить всё и запустить контейнеры"
	@echo "  make ssl            - Сгенерировать SSL-сертификаты (если нет)"
	@echo "  make ip             - Создать конфиг Nginx с вашим IP из шаблона"
	@echo "  make check-env      - Проверка и создание .env из шаблона"
	@echo "  make set-enviroment - Выбрать окружение (make set-enviroment ENV=prod)"
	@echo "  make check-override - Проверка и создание .env из шаблона"
	@echo "  make down           - Остановить контейнеры"
	@echo "  make logs           - Показать логи всех контейнеров"
	@echo "  make clean          - Остановить и удалить всё (включая данные)"
	@echo "  make restart        - Перезапуск"

set-enviroment:
	@if [ -z "$(ENV)" ]; then \
		echo "Использование: make set-enviroment ENV=dev|prod|debug"; \
		exit 1; \
	fi
	@sed -i "s/^ENVIRONMENT=.*/ENVIRONMENT=$(ENV)/" $(ENV_FILE)
	@echo "Окружение изменено на: $(ENV)"
	@echo "Перезапустите стек: make down && make up"

check-env:
	@if [ ! -f "$(ENV_FILE)" ]; then \
		echo "Файл .env не найден. Создаю из шаблона..."; \
		cp $(ENV_TEMPLATE) $(ENV_FILE); \
		CURRENT_IP=$$(hostname -I | awk '{print $$1}'); \
		if [ -z "$$CURRENT_IP" ]; then \
			echo "Не удалось определить IP. Используем 127.0.0.1"; \
			CURRENT_IP="127.0.0.1"; \
		fi; \
		echo "Определён IP хоста: $$CURRENT_IP"; \
		sed -i "s/{{ADMIN_IP}}/$$CURRENT_IP/g" $(ENV_FILE); \
		echo "Создан $(ENV_FILE) с IP: $$CURRENT_IP"; \
		echo "При необходимости отредактируйте $(ENV_FILE) вручную."; \
	else \
		echo "Файл .env уже существует."; \
	fi

ssl:
	@echo "Проверка SSL-сертификатов..."
	@if [ -f "$(SSL_KEY)" ] && [ -f "$(SSL_CRT)" ]; then \
		echo "Сертификаты уже есть, пропускаем"; \
	else \
		echo "Генерируем сертификаты..."; \
		mkdir -p ssl; \
		openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
			-keyout $(SSL_KEY) \
			-out $(SSL_CRT) \
			-subj "/CN=site.local/O=Test/C=RU"; \
		echo "Сертификаты созданы"; \
	fi

ip:
	@echo "Подставляем IP из .env в конфиг Nginx..."
	@source $(ENV_FILE); \
	if [ -z "$$ADMIN_IP" ]; then \
		echo "ADMIN_IP не задан в .env. Используем 127.0.0.1"; \
		ADMIN_IP="127.0.0.1"; \
	fi; \
	echo "Используем IP: $$ADMIN_IP"; \
	if [ -f "$(NGINX_CONF)" ] && grep -q "$$ADMIN_IP" $(NGINX_CONF); then \
		echo "Конфиг Nginx уже содержит актуальный IP, пропускаем"; \
	else \
		echo "Создаём конфиг Nginx из шаблона..."; \
		sed "s/REPLACE_WITH_YOUR_IP/$$ADMIN_IP/g" $(NGINX_TEMPLATE) > $(NGINX_CONF); \
		echo "Конфиг создан: $(NGINX_CONF)"; \
	fi

up: check-env check-override ssl ip
	@echo "Запускаем контейнеры..."
	docker compose up -d
	@echo "Всё запущено."
	@echo "WordPress: https://site.local (самоподписанный сертификат)"
	@echo "Grafana: http://metrics.local (логин/пароль из .env)"
	@echo "Prometheus: http://localhost:9090"
	@echo "Не забудьте добавить в /etc/hosts: 127.0.0.1 site.local metrics.local"

check-override:
	@echo "Определяем окружение..."
	@ENVIRONMENT=$$(grep '^ENVIRONMENT=' $(ENV_FILE) | cut -d'=' -f2 | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$$//' || echo ""); \
	if [ -z "$$ENVIRONMENT" ]; then \
		echo "ENVIRONMENT не задан в .env. Устанавливаю prod по умолчанию..."; \
		ENVIRONMENT=prod; \
		sed -i "s/^ENVIRONMENT=.*/ENVIRONMENT=prod/" $(ENV_FILE); \
	fi; \
	echo "Текущее окружение: $$ENVIRONMENT"; \
	OVERRIDE_FILE="docker-compose.override.yml"; \
	OVERRIDE_TEMPLATE="docker-compose.override.$$ENVIRONMENT.template.yml"; \
	if [ ! -f "$$OVERRIDE_FILE" ] && [ -f "$$OVERRIDE_TEMPLATE" ]; then \
		echo "Оверлей для окружения $$ENVIRONMENT не найден. Создаю из шаблона..."; \
		cp "$$OVERRIDE_TEMPLATE" "$$OVERRIDE_FILE"; \
		echo "Создан $$OVERRIDE_FILE"; \
	elif [ ! -f "$$OVERRIDE_TEMPLATE" ]; then \
		echo "Шаблон $$OVERRIDE_TEMPLATE не найден. Пропускаю."; \
	else \
		echo "Оверлей $$OVERRIDE_FILE уже существует."; \
	fi; \
	echo "OVERRIDE_FILE=$$OVERRIDE_FILE" >> /tmp/make_override.tmp

down:
	@echo "Останавливаем контейнеры..."
	docker compose down
	@echo "Готово"

logs:
	docker compose logs -f

clean:
	@echo "Внимание! Это удалит все контейнеры и тома с данными."
	@read -p "Вы уверены? (y/N) " -n 1 -r; \
	echo ""; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker compose down -v; \
		echo "Всё удалено"; \
	else \
		echo "Отмена"; \
	fi

restart: down up
	@echo "Перезапуск завершён"
