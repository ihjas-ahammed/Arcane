Make the following changes:

    - Fix Data Sync:
        I had gotten API Key error when I create a new user like my api key is exposed (help me setup gitgnore)

        Make the app work offline, like by default our app is offline, and every cloud activity is async and only indicated by that loading screen in action bar

        Fix that I had lost all data when I try to login as a new user

        Also fix firestore backup, make it by chunks becuase there was a limit of 1MB at a time

        also if there was such a limit for realtimedb, do the same make the cloud sync work in chunks

        Main task is to make initial loading so quick that app just works offline very well 

Make sure there wont be any screensize error, our ideal screen is 720x1520 with 271 dpi
When adding a new ui, create very compact design based on the theme of jurassic world evolution

After applying the changes recreate project_snapshot.txt only for new files and files with changes, each time improve modularity of the program by introducing new component files (only on modified or new files), don't modify system files like pubspec, if we need new packages, or file path changes, removal etc, give the command for bash


Thoroughly check for ui sizing errors before writing the code
Note: as output only give project_snapshot and commands if needed
