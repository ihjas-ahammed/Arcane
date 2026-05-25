Make the following changes:

Improve notifications:

 * Make it work well on linux too
 * Use a persistant notification when a task is running with stop option and a timer:
    For platforms without support for persistant live notification, sent a notification with updated details every five minutes
 * Add ability to schdule notification remindre for submission in  their screen and make sure they work ie the service will be kept in bg without being killed
 * Similarly add ability to set reminder for reflection in settings
 


Make sure there wont be any screensize error, our ideal screen is 720x1520 with 271 dpi
When adding a new ui, create very compact design based on the theme of jurassic world evolution

After applying the changes recreate project_snapshot.txt only for new files and files with changes, each time improve modularity of the program by introducing new component files (only on modified or new files), don't modify system files like pubspec, if we need new packages, or file path changes, removal etc, give the command for bash


Thoroughly check for ui sizing errors before writing the code
Note: as output only give project_snapshot and commands if needed
