class BaseException(Exception):
    '''riscvm base exception'''

class InternalException(BaseException):
    '''riscvm internal exception'''

def error(message='default error message'):
    raise InternalException(message)
