# Scrap Mechanic Blueprint Tool

by ren (github.com/madalilng/)

## First, a quick statement and disclaimer

**use at your own risk**

**this will conflict with other existing mods so do check if conflicts some files**

**this build is beta and i'm trying my best to improve this mod**

### Installation

> BACKUP YOUR SAVEFILE

to backup your savefile hit ctrl+r (windows)
type `%appdata%/Axolot Games` on run command got o `scrap mechanic/user/user_xxxxxx/save/survival/`
make a copy of that save folder

> BACKUP DATA AND SURVIVAL FOLDER


In your Scrap Mechanic base folder
make a copy of your data and survival folder for easy reversible if you want to go back to your vanilla version of scrap mechanic


> APPLY MOD

Copy and Paste the Data and Survival folders from this .rar file into your base Scrap Mechanic Folder.

### Mod Content

added new tool **PrinterTool**

added new object **Custom Container** with 200 slots

added new character command /blueprint <name_of_blueprint>

added 2 new items in crafter ( the actual tool & container )

### ToDo
- [x] Optimize the code
- [x] Custom Icon for tool
- [x] Custom Icon for Container
- [ ] Fix bugs some XD

### Usage

**Create Blueprint**

first you need to set blueprint name

using `/blueprint <name_of_blueprint>`

point your mouse to creation using **PrinterTool**

LMB to create blueprint with filename you set using `/blueprint`

after creating blueprint, place the 3d printer on ground

this will create chest with items from blueprint content

**Extracting from Blueprint**

while equipping **PrinterTool** press Q to toggle through blueprints

you can find your Blueprints from `Survival/Scripts/game/ren/blueprints`

point your mouse to **Custom Container** using your **PrinterTool**

LMB to make a creation

this will check the shape used for the blueprint and the content of the **Custom Container**

if everything passed the checking it will make a creation out of blueprint and consume the **Custom Container** and its contents
