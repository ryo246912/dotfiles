# 処理時間計測
import time
from inspect import currentframe, getframeinfo


class Timer(object):
    def __init__(self, frame, store=None):
        self.lineno = getframeinfo(frame).lineno
        self.function = getframeinfo(frame).function
        self.store = store

    def __enter__(self):
        self.start = time.time()

    def __exit__(self, *args):
        self.end = time.time()
        self.secs = self.end - self.start
        self.msecs = self.secs * 1000  # millisecs
        if self.store is not None:
            self.store.save(self.lineno, self.msecs)
        print(
            "T | Lineno: %d | Prosseing Time : %f ms | function: %s"
            % (self.lineno, self.msecs, self.function)
        )


class Store(object):
    def __init__(self):
        self.timer = {}

    def save(self, lineno, msecs):
        if self.timer.get(lineno) is None:
            self.timer.update({lineno: msecs})
        else:
            self.timer[lineno] += msecs

    def display(self):
        for k, v in sorted(self.timer.items(), key=lambda x: x[0]):
            print("S | Lineno: %d | Prosseing Time : %f ms " % (k, v))


# タイマーセット
store = Store()
with Timer(currentframe(), store):
    ...
