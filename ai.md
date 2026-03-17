Make the following changes:

    - Fix Data Sync:
        - Fix that my data is reset whenever I login on a new device which is totally absurd
        - Make sure to backup into firestore too when I click local Backup button, also give a small snackbar to show the progress feedback
        - As for multisystem data syncing:
            First load from firebase cloud whichever app I open
            Also if I have realtime syncing enable, sync everytime I start a new timer (in background) so I will have access to latest data everywhere, also same goes whenever I turn of the timer
    - Update Submission View:
        - Add last 7 day time graph above sessin timeline bellow asset asignment (for each tasks)

    - Fix Finance projected date: calculate it based on today + total_left/daily_avg
    - In Log Reflecrion button widget in analysis, add the last reflection log, Time indicator so I know when I last logged and continue from there
    - In schedule dashboard planner, when I click on the name of a planned task, open that task

Make sure there wont be any screensize error, our ideal screen is 720x1520 with 271 dpi
When adding a new ui, create very compact design based on the theme of jurassic world evolution

After applying the changes recreate project_snapshot.txt only for new files and files with changes, each time improve modularity of the program by introducing new component files (only on modified or new files), don't modify system files like pubspec, if we need new packages, or file path changes, removal etc, give the command for bash


Thoroughly check for ui sizing errors before writing the code
Note: as output only give project_snapshot and commands if needed
