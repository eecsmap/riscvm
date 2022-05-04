class Exception(Exception):
    '''riscvm base exception'''

def error(message):
    raise Exception(message)
