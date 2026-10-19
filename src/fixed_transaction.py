AUDIT_LOG_PATH = "audit_log.txt"


def get_balance(user_id):
    raise NotImplementedError


def update_balance(user_id, new_balance):
    raise NotImplementedError


def process_transaction(user_id, amount, db_connection):
    status = "pending"

    if amount > 0:
        status = "approved"
        balance = get_balance(user_id)
        new_balance = balance - amount
        update_balance(user_id, new_balance)

    log_entry = "Transaction finished with status: " + status

    with open(AUDIT_LOG_PATH, "a", encoding="utf-8") as file:
        file.write(log_entry + "\n")

    return status
