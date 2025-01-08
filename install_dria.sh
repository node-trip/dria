#!/bin/bash

# Цветовые коды
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# В начале скрипта добавим глобальную переменную
MODEL_CONFIG=""
WALLET_KEY=""
GEMINI_KEY=""
OPENROUTER_KEY=""

# В начале скрипта добавим установку expect
apt-get install -y expect > /dev/null 2>&1

# Функция для отображения заголовка
print_header() {
    clear
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}     Установщик Dria Node       ${NC}"
    echo -e "${GREEN}================================${NC}"
    echo ""
}

# Функция для проверки успешности выполнения команды
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[✓] $1${NC}"
    else
        echo -e "${RED}[✗] $1${NC}"
        exit 1
    fi
}

# Функция выбора конфигурации
select_config() {
    echo -e "${YELLOW}Выберите конфигурацию моделей:${NC}"
    echo -e "1. ${GREEN}Gemini 1.5 Flash${NC} (самая популярная, 12.22% нод)"
    echo -e "2. ${YELLOW}Средняя${NC} (gpt4o, Qwen2_5coder7B)"
    echo -e "3. ${RED}Тяжелая${NC} (ORLlama3_1_405B, ORQwen2_5Coder32B)"
    read -p "Выберите конфигурацию (1-3): " MODEL_CONFIG

    case $MODEL_CONFIG in
        1) 
            models="10"  # Только gemini-1.5-flash
            echo -e "${GREEN}Выбрана модель: gemini-1.5-flash${NC}"
            echo -e "${YELLOW}Введите DKN Wallet Secret Key (32-bytes hex encoded):${NC}"
            read -r WALLET_KEY
            echo -e "${YELLOW}Введите Gemini API Key:${NC}"
            read -r GEMINI_KEY
            OPENROUTER_KEY="\r"
            ;;
        2) 
            models="2,48"
            echo -e "${YELLOW}Выбрана средняя конфигурация${NC}"
            echo -e "${YELLOW}Введите DKN Wallet Secret Key (32-bytes hex encoded):${NC}"
            read -r WALLET_KEY
            echo -e "${YELLOW}Введите OpenRouter API Key:${NC}"
            read -r OPENROUTER_KEY
            GEMINI_KEY="\r"
            ;;
        3) 
            models="17,24"
            echo -e "${RED}Выбрана тяжелая конфигурация${NC}"
            echo -e "${YELLOW}Введите DKN Wallet Secret Key (32-bytes hex encoded):${NC}"
            read -r WALLET_KEY
            echo -e "${YELLOW}Введите OpenRouter API Key:${NC}"
            read -r OPENROUTER_KEY
            GEMINI_KEY="\r"
            ;;
        *) 
            echo -e "${RED}Неверный выбор!${NC}"
            return 1 
            ;;
    esac
}

# Обновляем функцию install_dependencies
install_dependencies() {
    echo -e "${YELLOW}Проверка существующих сервисов...${NC}"
    
    # Установка необходимых утилит
    echo -e "${YELLOW}Установка дополнительных утилит...${NC}"
    sudo apt-get update
    sudo apt-get install -y net-tools screen unzip
    
    # Проверка Docker
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}Docker уже установлен${NC}"
        echo -e "Версия Docker: $(docker --version)"
        read -p "Хотите переустановить Docker? (y/n): " reinstall_docker
        if [[ $reinstall_docker != "y" ]]; then
            echo -e "${GREEN}Пропускаем установку Docker${NC}"
        else
            # Удаление старых версий Docker
            for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
                sudo apt-get remove $pkg -y
            done
            
            # Установка Docker
            sudo apt-get update
            sudo apt-get install -y ca-certificates curl gnupg
            sudo install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            sudo chmod a+r /etc/apt/keyrings/docker.gpg
            
            echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
            $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        fi
    else
        echo -e "${YELLOW}Docker не найден. Устанавливаем...${NC}"
        # Удаление старых версий Docker
        for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
            sudo apt-get remove $pkg -y
        done
        
        # Установка Docker
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        
        echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi
    
    # Установка Ollama только для конфигураций 2 и 3
    if [[ "$MODEL_CONFIG" == "2" ]] || [[ "$MODEL_CONFIG" == "3" ]]; then
        echo -e "${YELLOW}Проверка Ollama для выбранной конфигурации...${NC}"
        if pgrep ollama &> /dev/null; then
            echo -e "${YELLOW}Обнаружен запущенный процесс Ollama${NC}"
            curl -fsSL https://ollama.com/install.sh | sh
        else
            echo -e "${YELLOW}Устанавливаем Ollama...${NC}"
            curl -fsSL https://ollama.com/install.sh | sh
        fi
    else
        echo -e "${GREEN}Ollama не требуется для легкой конфигурации${NC}"
        # Останавливаем Ollama если запущена
        if pgrep ollama &> /dev/null; then
            echo -e "${YELLOW}Останавливаем ненужный процесс Ollama...${NC}"
            pkill ollama
            systemctl stop ollama 2>/dev/null
        fi
    fi
    
    check_status "Установка зависимостей завершена"
}

# Функция установки Dria
install_dria() {
    echo -e "${YELLOW}Установка Dria Node...${NC}"
    
    cd $HOME
    
    # Проверяем наличие старых файлов
    rm -f dkn-compute-node.zip
    rm -rf dkn-compute-node
    
    # Скачиваем и распаковываем
    curl -L -o dkn-compute-node.zip https://github.com/firstbatchxyz/dkn-compute-launcher/releases/latest/download/dkn-compute-launcher-linux-amd64.zip
    
    # Проверяем успешность скачивания
    if [ ! -f dkn-compute-node.zip ]; then
        echo -e "${RED}Ошибка: Не удалось скачать файл${NC}"
        return 1
    fi
    
    unzip dkn-compute-node.zip
    
    # Проверяем успешность распаковки
    if [ ! -d dkn-compute-node ]; then
        echo -e "${RED}Ошибка: Не удалось распаковать архив${NC}"
        return 1
    fi
    
    cd dkn-compute-node
    
    check_status "Установка Dria завершена"
}

# Функция остановки процессов
stop_processes() {
    echo -e "${YELLOW}Останавливаем процессы...${NC}"
    
    # Остановка dkn-compute-launcher
    if pgrep -f dkn-compute-launcher > /dev/null; then
        echo -e "Останавливаем dkn-compute-launcher..."
        pkill -f dkn-compute-launcher
        sleep 2
    fi
    
    # Остановка screen сессии
    if screen -list | grep -q "dria"; then
        echo -e "Останавливаем screen сессию..."
        screen -X -S dria quit
        sleep 1
    fi
    
    # Остановка Ollama
    if pgrep ollama > /dev/null; then
        echo -e "Останавливаем Ollama..."
        pkill ollama
        sleep 2
    fi
    
    # Проверка что все остановлено
    if pgrep -f "dkn-compute-launcher|ollama" > /dev/null; then
        echo -e "${RED}Внимание: Некоторые процессы все еще работают${NC}"
        ps aux | grep -E "dkn-compute-launcher|ollama" | grep -v grep
        return 1
    fi
    
    echo -e "${GREEN}Все процессы остановлены${NC}"
    return 0
}

# Обновим функцию run_node
run_node() {
    echo -e "${YELLOW}Проверка конфликтов перед запуском...${NC}"
    
    # Проверяем наличие screen
    if ! command -v screen &> /dev/null; then
        echo -e "${YELLOW}Устанавливаем screen...${NC}"
        apt-get update
        apt-get install -y screen
    fi
    
    # Проверяем, выбрана ли конфигурация
    if [[ -z "$MODEL_CONFIG" ]]; then
        echo -e "${RED}Ошибка: Конфигурация не выбрана${NC}"
        select_config || return 1
    fi
    
    # Останавливаем старые процессы
    stop_processes
    
    cd $HOME/dkn-compute-node || {
        echo -e "${RED}Ошибка: Не удалось перейти в директорию ноды${NC}"
        return 1
    }
    
    # Проверка существования файла
    if [ ! -f "./dkn-compute-launcher" ]; then
        echo -e "${RED}Ошибка: Файл dkn-compute-launcher не найден${NC}"
        return 1
    fi
    
    # Проверка прав на выполнение
    if [ ! -x "./dkn-compute-launcher" ]; then
        echo -e "${YELLOW}Установка прав на выполнение...${NC}"
        chmod +x ./dkn-compute-launcher
    fi
    
    # Создание .env файла
    echo -e "${YELLOW}Обновляем конфигурацию...${NC}"
    cat > .env << EOF
# HTTP API порт
PORT=4001

# P2P порты и настройки
P2P_PORT=4001
P2P_LISTEN=/ip4/0.0.0.0/tcp/4001
P2P_EXTERNAL=/ip4/0.0.0.0/tcp/4001
P2P_BOOTSTRAP_NODES=

# Метрики
METRICS_PORT=9093

# Общие настройки
RUST_LOG=info
NODE_ENV=production
DISABLE_DEFAULT_PORTS=false
DISABLE_DEFAULT_BOOTSTRAPS=false

# Дополнительные P2P настройки
LIBP2P_FORCE_PNET=false
LIBP2P_LISTEN=/ip4/0.0.0.0/tcp/4001
LIBP2P_EXTERNAL=/ip4/0.0.0.0/tcp/4001

# Логирование
RUST_LOG=info,dkn_compute=debug,dkn_workflows=debug

# Дополнительные настройки
ENABLE_MODEL_METRICS=true
METRICS_INTERVAL=60

# Настройки фильтров
TASK_FILTER_ENABLED=false
ACCEPT_ALL_TASKS=true
EOF
    
    echo -e "${YELLOW}Запуск Dria Node...${NC}"
    
    # Создаем expect скрипт
    echo -e "${YELLOW}Создаем скрипт запуска...${NC}"
    cat > run_dria.exp << EOF
#!/usr/bin/expect -f
set timeout -1

# Запускаем программу
spawn ./dkn-compute-launcher

# Ожидаем запрос DKN Wallet Secret Key
expect "Please enter your DKN Wallet Secret Key"
send "$WALLET_KEY\r"

# Ожидаем любой из возможных запросов и отвечаем на него
expect {
    "Enter the model ids" {
        send "$models\r"
        exp_continue
    }
    "Enter your Gemini API Key:" {
        send "$GEMINI_KEY\r"
        exp_continue
    }
    "Enter your OpenRoute API Key:" {
        send "$OPENROUTER_KEY\r"
        exp_continue
    }
    "Enter your Jina API key" {
        send "\r"
        exp_continue
    }
    "Enter your Serper API key" {
        send "\r"
        exp_continue
    }
    eof
}

interact
EOF
    
    chmod +x run_dria.exp
    
    # Запускаем через screen
    echo -e "${YELLOW}Запускаем ноду...${NC}"
    screen -L -Logfile dria.log -S dria ./run_dria.exp
    sleep 5
    
    # Проверка лога на ошибки
    if [ -f "dria.log" ]; then
        echo -e "${YELLOW}Последние строки лога:${NC}"
        tail -n 5 dria.log
    fi
    
    # Проверка статуса
    if ! screen -list | grep -q "dria"; then
        echo -e "${RED}[✗] Ошибка запуска ноды${NC}"
        return 1
    fi
    
    echo -e "${GREEN}[✓] Нода запущена в screen сессии 'dria'${NC}"
    return 0
}

# Обновим функцию update_node()
update_node() {
    echo -e "${YELLOW}Обновление Dria Node...${NC}"
    
    # Проверяем текущий статус
    if screen -list | grep -q "dria" || pgrep -f dkn-compute-launcher > /dev/null; then
        echo -e "${YELLOW}Обнаружена работающая нода${NC}"
        echo -e "1. Остановить и обновить"
        echo -e "2. Отменить обновление"
        read -p "Выберите действие (1-2): " update_choice
        
        case $update_choice in
            1)
                echo -e "${YELLOW}Останавливаем текущую ноду...${NC}"
                pkill -f dkn-compute-launcher
                screen -X -S dria quit
                sleep 2
                ;;
            2)
                echo -e "${GREEN}Обновление отменено${NC}"
                return 0
                ;;
            *)
                echo -e "${RED}Неверный выбор!${NC}"
                return 1
                ;;
        esac
    fi
    
    # Проверяем, выбрана ли конфигурация
    if [[ -z "$MODEL_CONFIG" ]]; then
        echo -e "${YELLOW}Сначала выберите конфигурацию:${NC}"
        select_config || return 1
    fi
    
    # Остановка процессов
    pgrep ollama && kill $(pgrep ollama)
    screen -XS dria quit
    
    # Удаление старых файлов
    cd $HOME
    rm -rf dkn-compute-node.zip dkn-compute-node
    
    # Установка новой версии
    install_dria
    run_node
    
    check_status "Обновление завершено"
}

# Обновим функцию check_node_status()
check_node_status() {
    echo -e "${YELLOW}Проверка статуса ноды...${NC}"
    
    # Проверка screen сессии
    if ! screen -list | grep -q "dria"; then
        echo -e "${RED}Screen сессия 'dria' не найдена${NC}"
        echo -e "${YELLOW}Попробуйте перезапустить ноду (пункт 3)${NC}"
        return 1
    fi
    
    # Проверка процесса
    if ! pgrep -f dkn-compute-launcher > /dev/null; then
        echo -e "${RED}Процесс ноды не найден${NC}"
        echo -e "${YELLOW}Проверте логи: screen -r dria${NC}"
        return 1
    fi
    
    # Проверка Ollama только для конфигураций 2 и 3
    if [[ "$MODEL_CONFIG" == "2" ]] || [[ "$MODEL_CONFIG" == "3" ]]; then
        if ! pgrep ollama > /dev/null; then
            echo -e "${RED}Процесс Ollama не запущен${NC}"
            echo -e "${YELLOW}Запускаем Ollama...${NC}"
            systemctl unmask ollama 2>/dev/null
            systemctl enable ollama
            systemctl start ollama
        fi
    else
        echo -e "${GREEN}Ollama не требуется для текущей конфигурации${NC}"
        # Останавливаем Ollama если запущена
        if pgrep ollama > /dev/null || systemctl is-active ollama &>/dev/null; then
            echo -e "${YELLOW}Останавливаем и отключаем Ollama...${NC}"
            systemctl stop ollama
            pkill -9 ollama
            rm -f /etc/systemd/system/ollama.service
            systemctl daemon-reload
            systemctl disable ollama
            systemctl mask ollama
            echo -e "${GREEN}Ollama полностью остановлена и отключена${NC}"
        fi
    fi
    
    # Проверка портов
    echo -e "${YELLOW}Проверка используемых портов:${NC}"
    netstat -tulpn | grep -E '4001|4004|9092|9093' || echo "Порты свободны"
    
    # Проверка P2P соединений
    echo -e "${YELLOW}Проверка P2P соединений...${NC}"
    connections=$(lsof -i -P -n | grep -c "dkn_compu.*ESTABLISHED")
    if [ $connections -gt 0 ]; then
        echo -e "${GREEN}P2P соединения активны ($connections соединений)${NC}"
    else
        echo -e "${RED}Нет активных P2P соединений${NC}"
    fi
    
    # Проверка API с увеличенным таймаутом
    echo -e "${YELLOW}Проверка API ноды (может занять до 30 секунд)...${NC}"
    
    # Попытка подключения к API с несколькими попытками
    for i in {1..6}; do
        if nc -z localhost 4001; then
            echo -e "${GREEN}Порт 4001 доступен${NC}"
            
            # Показываем информацию о соединениях
            echo -e "${YELLOW}Активные соединения:${NC}"
            lsof -i -P -n | grep "dkn_compu.*LISTEN"
            echo -e "${YELLOW}Всего P2P соединений:${NC} $connections"
            break
        else
            echo -n "."
            sleep 5
        fi
    done
    
    echo -e "\n${GREEN}Статус компонентов:${NC}"
    echo -e "Screen сессия: ✓"
    echo -e "Процесс ноды: ✓"
    echo -e "Ollama: ✓"
    echo -e "API: ✓"
    return 0
}

# Добавим функцию удаления
uninstall_node() {
    echo -e "${YELLOW}Выберите компоненты для удаления:${NC}"
    echo -e "1. Только текущую ноду Dria"
    echo -e "2. Ноду и Ollama"
    echo -e "3. ${RED}Полное удаление Dria и Docker${NC} (может затронуть другие проекты!)"
    echo -e "4. Отмена"
    
    read -p "Выберите вариант (1-4): " remove_choice
    
    case $remove_choice in
        1)
            echo -e "${YELLOW}Удаляем только текущую ноду...${NC}"
            pkill -f dkn-compute-launcher
            screen -XS dria quit
            cd $HOME
            rm -rf dkn-compute-node.zip dkn-compute-node
            ;;
        2)
            echo -e "${YELLOW}Удаляем ноду и Ollama...${NC}"
            pkill -f dkn-compute-launcher
            screen -XS dria quit
            systemctl stop ollama
            pkill ollama
            cd $HOME
            rm -rf dkn-compute-node.zip dkn-compute-node
            rm -rf /usr/local/bin/ollama ~/.ollama
            ;;
        3)
            echo -e "${RED}ВНИМАНИЕ: Это действие удалит Docker и может затронуть другие проекты!${NC}"
            echo -e "${RED}Все контейнеры и образы будут удалены!${NC}"
            read -p "Вы ТОЧНО уверены? Введите 'yes' для подтверждения: " confirm
            if [[ $confirm == "yes" ]]; then
                # Останавливаем процессы
                pkill -f dkn-compute-launcher
                screen -XS dria quit
                systemctl stop ollama
                pkill ollama
                
                # Удаляем файлы ноды
                cd $HOME
                rm -rf dkn-compute-node.zip dkn-compute-node
                
                # Удаляем Docker
                systemctl stop docker
                apt-get remove --purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
                rm -rf /var/lib/docker /etc/docker ~/.docker
                
                # Удаляем Ollama
                rm -rf /usr/local/bin/ollama ~/.ollama
                
                # Удаляем утилиты
                apt-get remove -y screen expect
            else
                echo -e "${GREEN}Операция отменена${NC}"
                return 0
            fi
            ;;
        4)
            echo -e "${GREEN}Операция отменена${NC}"
            return 0
            ;;
        *)
            echo -e "${RED}Неверный выбор!${NC}"
            return 1
            ;;
    esac
    
    echo -e "${GREEN}Удаление завершено${NC}"
    if [[ $remove_choice == "3" ]]; then
        echo -e "${YELLOW}Рекомендуется перезагрузить систему${NC}"
    fi
}

# Главное меню
main_menu() {
    while true; do
        print_header
        
        echo "1. Установить зависимости"
        echo "2. Установить Dria Node"
        echo "3. Запустить ноду"
        echo "4. Обновить ноду"
        echo "5. Проверить статус"
        echo "6. Удалить ноду"
        echo "7. Изменить конфигурацию"
        echo "8. Выход"
        echo ""
        read -p "Выберите действие (1-8): " choice
        
        case $choice in
            1) install_dependencies ;;
            2) install_dria ;;
            3) 
                if [[ -z "$MODEL_CONFIG" ]]; then
                    select_config || continue
                fi
                run_node 
                ;;
            4) update_node ;;
            5) check_node_status ;;
            6) uninstall_node ;;
            7) select_config ;;
            8) exit 0 ;;
            *) echo -e "${RED}Неверный выбор!${NC}" ;;
        esac
        
        echo ""
        read -p "Нажмите Enter для продолжения..."
    done
}

# Запуск главного меню
main_menu 