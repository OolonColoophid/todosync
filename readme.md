# TodoSync

Scan a text file that contains todos and synchronise them with [TodoTxt](http://todotxt.com).


~~~ 

This todo synchroniser looks through a text file and identifies todo items. 

Default format is:

- [ ] Get the milk @shopping

When this script encounters such a todo for the first time, this todo is then 
added to the todo.txt using the standard todo.sh command see 
[https://github.com/ginatrapani/todo.txt-cli]. Note that the marked todo
text is sent to this command raw., e.g.:

t add Get milk @shopping ID:4h7f

(Note that a random five-letter code is added.)

Just after, this script flags the todo with an ID:

- [ ] Get the milk @shopping, ID:4h7f

The next time the script is run, it will come across this todo
item with the ID 4h7f. It will check the $DONE_FILE to see
if it has indeed been done (using the ID). If this exists in
the $DONE_FILE, it will mark it as done:

- [x] Get the milk @shopping, ID:4h7f


~~~

~~~

usage: todoSync.sh ---file <name> [-vduh]

-f --file [arg]       File to be scanned. Required.
-v --verbose          Enable verbose mode, print script as it is executed
-d --debug            Enables debug mode
-u --dummy            Dummy run (do not commit changes)
-h --help             This page

~~~
