color-schemes
=============

.. dfhack-tool::
    :summary: Modify the colors in the DF UI.
    :tags: fort gameplay graphics




Color-schemes works best if color schemes are loaded at game start, to do so add those lines at the end of `<df-directory>/dfhack.init`

#dfhack.init
color-schemes -q register -f <your-color-schemes-directory>
color-schemes default load


Current features are :
    * :Registration:
    * :Loading:
    * :Listing:
    * :Default: Setting/Loading

For detailed information and usage, type ``color-schemes`` in console.

Loaded as a module, this script will export those methods :
    * register(path, force) : Register colors schemes by path (file or directory), relative to DF main directory
    * load(name)            : Load a registered color scheme by name
    * list()                : Return a list of registered color schemes
    * set_default(name)     : Set the default color scheme
    * load_default()        : Load the default color scheme

For more information about arguments and return values, see ``hack/scripts/color-schemes.lua``.

Related scripts:
    * `gui/color-schemes` is the in-game GUI for this script.
    * `season-palette` swaps color schemes when the season changes.

File format
-----------

Color scheme class, used to store colors' values, file path, modification time, loaded state
    template :
    {
        name  : <string>
        file  : <string>    Relative to DF main directory
        mtime : <number>    File modification time, used for reloading
        valid : <boolean>   Specifies if that color scheme is valid (all values are defined)
        values: <table>     Table of colors' values (see `parse_color_scheme` for template)
    }


Parse colors' values from string with format `[<color>_<channel>:<value>]...`
    <color> in `COLORS`, <channel> in `CHANNELS`, <value> in range [0,255]
    Return
        valid : <boolean> Parsing was successful
        values :
        {
            "<color>" = {
                "R" = <number>,
                "G" = <number>,
                "B" = <number>
            }
            ...
        }
        (<number> = -1 when unspecified)
