class RV64Exception(Exception):
    '''riscvm base exception'''

def error(message):
    raise RV64Exception(message)
