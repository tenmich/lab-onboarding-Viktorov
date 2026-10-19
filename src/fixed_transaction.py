"""Обработка транзакции в системе лояльности (исправленная версия)."""

AUDIT_LOG_PATH = "audit_log.txt"


def get_balance(user_id):
    """Вернуть текущий баланс пользователя (заглушка для примера)."""
    raise NotImplementedError


def update_balance(user_id, new_balance):
    """Сохранить новый баланс пользователя (заглушка для примера)."""
    raise NotImplementedError


def process_transaction(user_id, amount, db_connection):
    # Дефект 1: status инициализирован до ветвления
    status = "pending"

    if amount > 0:
        status = "approved"
        balance = get_balance(user_id)
        new_balance = balance - amount
        update_balance(user_id, new_balance)

    # Дефект 2: убрано мертвое присваивание "Start processing"
    log_entry = "Transaction finished with status: " + status

    # Дефект 3: файл закрывается автоматически через with,
    # режим "a" не затирает предыдущие записи журнала
    with open(AUDIT_LOG_PATH, "a", encoding="utf-8") as file:
        file.write(log_entry + "\n")

    return status
