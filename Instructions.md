## XBMUT html/web interface

This project is a web ui 'front end' for the 'XBMUT' (Xbox Memory Unit Tool) program.
GitHub url: https://github.com/BAD-AL/xbox_memory_unit_tool 

This web app is to be a single-page no-framework html web app (using the dart language).
XBMUT is already used in the NFL2k5Tool web interface too ( https://bad-al.github.io/nfl2k5tool_web/ )

A prototype for how it should look is inside the 'proto' folder.

A copy of the 'xbmut' command line program is located in the 'XBMUT' folder along with a 'mu_dump.bin' (XBOX memory unit file ) and it's README.md file. It has been placed there if you need to play with it to see features.

XBOX Memory unit files are used in the XEMU emulator and typically use the .img or .bin extensions.

XBMUT imports and exports save files to/from .zip files.

The typical use cases for this WEB UI would be as follows:
### Use Case 1
    1. User drags and drops their XEMU memory card file onto the drop area.
    2. The program uses the xbmut functionality to display the contents of the file.
    3. The user browses and deletes folders or 'saves' from the card.
    4. The user then presses the 'Export Card' button and save the file to their computer.

### Use Case 2
    1. User drags and drops their XEMU memory card file onto the drop area.
    2. The program uses the xbmut functionality to display the contents of the file.
    4. The user imports a .zip file by browsing for or dropping the .zip files onto the drop area.
    5. The user then presses the 'Export Card' button and save the file to their computer.

### Use Case 3
    1. User creates a new card with a 'new Memory Unit' button.
    2. The program uses the xbmut functionality to display the contents of the file.
    3. The user can then import .zip files by browsing for or dropping the .zip files.
    5. The user then presses the 'Export Card' button and save the file to their computer.

Please also process SuperPowers.md

Any clarifying Questions or suggestions?