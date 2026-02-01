Make the following changes:

    * Fix Session Log:
        - While adding manual log, make the initial start time one minute after current time to avoid overlap
        - Also show a snackbar if there was an overlap and a button to edit log before actually deleting it
        - Hide the logs that is less than 15 minutes from the view unless it is zoomed in to a size where I can see their labels
        - Fix the day issue:
            - Make sure I can manually log across days, and also show it in the log, its because of this limitation I had to cut my work into two before 12 am, since if the log goes after 12 am then it was not seen in either days log and also there was big issues

    * Fix wallet advisor:
        - Make it possible to regenarte the forcast anytime
    
    * Fix time sync:
        - Make it take care of the location based time (india by default) user can cahnge it in settings. this goes for planning exact prayer times and all
        - Give input to even the submission decsription to the prompt for better generation
        - Also let it be considerate and empathetics (like the current version even schedules work during sleep time?!)
        - Also make it possible to resync without intent/focus input, also on resync only replace the schdule if user asked, unless just extrapolate the missing time block, like if I resync after 4 hours then it should only add 4 hours to the schdule and delte starting 4 hours (it should be done automatically if time is passed, even without resync)

Make sure there wont be any screensize error, our ideal screen is 720x1520 with 271 dpi

After applying the changes recreate project_snapshot.txt only for new files and files with changes, each time improve modularity of the program by introducing new component files (only on modified or new files), don't modify system files like pubspec, if we need new packages, or file path changes, removal etc, give the command for bash


Thoroughly check for ui sizing errors before writing the code
Note: as output only give project_snapshot and commands if needed