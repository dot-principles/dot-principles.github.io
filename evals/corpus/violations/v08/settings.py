"""Runtime settings shared by worker threads."""
import threading

SETTINGS = {"retries": 3, "timeout": 30, "verbose": False}


def set_verbose(value):
    SETTINGS["verbose"] = value


def worker(job):
    SETTINGS["retries"] -= 1
    if SETTINGS["verbose"]:
        print("running", job)


def run_all(jobs):
    threads = [threading.Thread(target=worker, args=(j,)) for j in jobs]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
