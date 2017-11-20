# Companion of the Avatar
CotA is a small application to nicely display the stats ("/stats") recorded to a chat log file from Shroud of the Avatar. 

![screenshot](http://a4.pbase.com/o10/09/605909/1/164136608.cRdMb6Nk.Screenshotfrom20171119192449.png)

CotA was originally written in C++ using the Qt framework but, for various reasons, I have since completely rewritten it in D using GTK+ as the framework. The main benefit of this is that there is no installation process for the application. Just grab the Linux binary above (cota, no extension) and run it. The only requirement is that you have GTK+ 3.22 or above installed. If you're running an up-to-date distribution then it's likely that it's already installed. The app should also work on Windows and Mac (provided GTK+ 3.22 is installed) but you will have to build that binary yourself.

The application will create a json file next to itself to persist settings. Deleting that file (cota.json on Linux) is safe and will merely cause the app to use the defaults the next time it's run.

This code is released as public domain. Do with it as you want but I am not liable for any of it.
