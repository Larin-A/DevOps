# Пути к файлам
NGINX_TEMPLATE = configs/nginx/site.local.conf.template
NGINX_CONF = configs/nginx/site.local.conf
SSL_KEY = ssl/site.local.key
SSL_CRT = ssl/site.local.crt

help:
	@echo "Доступные команды:"
	@echo "  make ssl   - Сгенерировать SSL-сертификаты (если нет)"
	@echo "  make ip    - Создать конфиг Nginx с вашим IP из шаблона"
	@echo "  make up    - Подготовить всё и запустить контейнеры"
	@echo "  make down  - Остановить контейнеры"
	@echo "  make logs  - Показать логи всех контейнеров"
	@echo "  make clean - Остановить и удалить всё (включая данные)"

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
	@echo "Определяем ваш внешний IP-адрес..."
	@CURRENT_IP=$$(curl -s ifconfig.me); \
	if [ -z "$$CURRENT_IP" ]; then \
		echo "Не удалось определить IP. Проверьте интернет."; \
		exit 1; \
	fi; \
	echo "Ваш IP: $$CURRENT_IP"; \
	echo "Создаём конфиг Nginx из шаблона..."; \
	sed "s/REPLACE_WITH_YOUR_IP/$$CURRENT_IP/g" $(NGINX_TEMPLATE) > $(NGINX_CONF); \
	echo "Конфиг создан: $(NGINX_CONF)"

up: ssl ip
	@echo "Запускаем контейнеры..."
	docker-compose up -d
	@echo "Всё запущено."
	@echo "WordPress: https://site.local (самоподписанный сертификат)"
	@echo "Grafana: http://metrics.local (логин/пароль: admin/admin)"
	@echo "Prometheus: http://localhost:9090"
	@echo "Не забудьте добавить в /etc/hosts: 127.0.0.1 site.local metrics.local"

down:
	@echo "Останавливаем контейнеры..."
	docker-compose down
	@echo "Готово"

logs:
	docker-compose logs -f

clean:
	@echo "Внимание! Это удалит все контейнеры и тома с данными."
	@read -p "Вы уверены? (y/N) " -n 1 -r; \
	echo ""; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose down -v; \
		echo "Всё удалено"; \
	else \
		echo "Отмена"; \
	fi

restart: down up
	@echo "Перезапуск завершён"
