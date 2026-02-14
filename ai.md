Make the following changes:

    * Update schedule tab:
        - Only list incomplete tasks when I add a new session
        - Add a predict button:
            - It uses AI to predict next thing user is supposed to do by prompting the session log for last 14 days
            - This predicted session will be removable if needed and also with less opacity in the bacground, also auto remove them when I overlap a real session with them
            - Predict only for the rest of the time for the day

        - Add a top hiro, with latest task and most time spend task and things like that (like a motivating screen)
    * Update the session log screen:
        - Hide all sessions with smaller than 20 mins
        - Remove the zoom in and out buttons
        - 

Make sure there wont be any screensize error, our ideal screen is 720x1520 with 271 dpi

After applying the changes recreate project_snapshot.txt only for new files and files with changes, each time improve modularity of the program by introducing new component files (only on modified or new files), don't modify system files like pubspec, if we need new packages, or file path changes, removal etc, give the command for bash


Thoroughly check for ui sizing errors before writing the code
Note: as output only give project_snapshot and commands if needed
