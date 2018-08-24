# Status: Archived
This repository has been archived and is no longer maintained.

![status: inactive](https://img.shields.io/badge/status-inactive-red.svg)
EventSource-Examples
====================

Demonstrates using the EventSource / Server-Sent Events feature of the Firebase REST API
to implement a simple commandline chat client in Ruby and Python.

Each client has the same architecture:

  * A thread listening the Server-Sent Events endpoint from Firebase
  * A thread to POST messages to Firebase
  * A thread to manage the UI
    * Curses UI. Fancy commandline chat
    * Basic UI. Prints messages to stdout

# Running the Python example

cd python

pip install -r requirements.txt

python chat.py

# Running the Ruby example

cd ruby

bundle install

ruby chat.rb


Use With Your Own Firebase
==========================

Simply change the URL constants in chat.py / chat.rb to point to a location in your own Firebase.

Suggestions / bugfixes / implementations in other languages welcome!
