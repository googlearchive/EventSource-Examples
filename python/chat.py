#!/usr/bin/env python

from sseclient import SSEClient
from Queue import Queue
import requests
import json
import threading
import display
import socket
import sys


#DISPLAY_CLASS = display.BasicDisplay
DISPLAY_CLASS = display.CursesDisplay

URL = 'https://eventsource.firebaseio-demo.com/.json'

class ClosableSSEClient(SSEClient):
    """
    Hack in some closing functionality on top of the SSEClient
    """

    def __init__(self, *args, **kwargs):
        self.should_connect = True
        super(ClosableSSEClient, self).__init__(*args, **kwargs)

    def _connect(self):
        if self.should_connect:
            super(ClosableSSEClient, self)._connect()
        else:
            raise StopIteration()

    def close(self):
        self.should_connect = False
        self.retry = 0
        # HACK: dig through the sseclient library to the requests library down to the underlying socket.
        # then close that to raise an exception to get out of streaming. I should probably file an issue w/ the
        # requests library to make this easier
        self.resp.raw._fp.fp._sock.shutdown(socket.SHUT_RDWR)
        self.resp.raw._fp.fp._sock.close()

class PostThread(threading.Thread):

    def __init__(self, outbound_queue):
        self.outbound_queue = outbound_queue
        super(PostThread, self).__init__()

    def run(self):
        while True:
            msg = self.outbound_queue.get()
            if not msg:
                break
            to_post = json.dumps(msg)
            requests.post(URL, data=to_post)

    def close(self):
        self.outbound_queue.put(False)


class RemoteThread(threading.Thread):

    def __init__(self, message_queue):
        self.message_queue = message_queue
        super(RemoteThread, self).__init__()

    def run(self):
        try:
            self.sse = ClosableSSEClient(URL)
            for msg in self.sse:
                msg_data = json.loads(msg.data)
                if msg_data is None:    # keep-alives
                    continue
                path = msg_data['path']
                data = msg_data['data']
                if path == '/':
                    # initial update
                    if data:
                        keys = data.keys()
                        keys.sort()
                        for k in keys:
                            self.message_queue.put(data[k])
                else:
                    # must be a push ID
                    self.message_queue.put(data)
        except socket.error:
            pass    # this can happen when we close the stream

    def close(self):
        if self.sse:
            self.sse.close()

if __name__ == '__main__':
    args = sys.argv
    client = args[1] if len(args) == 2 else 'python'
    outbound_queue = Queue()
    inbound_queue = Queue()
    post_thread = PostThread(outbound_queue)
    post_thread.start()
    remote_thread = RemoteThread(inbound_queue)
    remote_thread.start()
    disp = DISPLAY_CLASS(outbound_queue, client, inbound_queue)
    disp.run()
    post_thread.join()
    remote_thread.close()
    remote_thread.join()