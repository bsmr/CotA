# Companion of the Avatar
CotA is a small application to nicely display the stats ("/stats") recorded to a chat log file from Shroud of the Avatar. 

![screenshot](http://a4.pbase.com/o10/09/605909/1/164136608.HlZbUjYn.Screenshotfrom20171123164324.png)

It also has this sweet Lunar Rift chronometer.

![screenshot](http://a4.pbase.com/o10/09/605909/1/166622004.JBLHOjc8.Screenshotfrom20171124194648.png)

CotA was originally written in C++ using the Qt framework but, for various reasons, I have since completely rewritten it in D using GTK+ as the framework. The main reason for this was so that I could provide a stand-alone Linux binary which requires no installation. Just grab the Linux binary above (cota, no extension) and run it. The only requirement is that you have GTK+ 3.22 or above installed. If you're running an up-to-date distribution then it's likely already installed. The app should also work on Windows and Mac (provided GTK+ 3.22 is installed) but you will have to build that binary yourself.

The application will create a json file next to itself in order to persist settings. Deleting that file (cota.json on Linux) is safe and will merely cause the app to use defaults the next time it's run.

To build on Windows or Mac, You will need to:
- Install the GTK+ libraries (https://www.gtk.org/download/index.php).
- Install DMD (https://dlang.org/download.html).
- Clone the source code from this repository or download a zip archive and extract it.
- From the command line, change to the CotA folder and enter "dub build".

This code is released as public domain. Do with it as you want but I am not liable for any of it.
