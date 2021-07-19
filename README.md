# Multirun

Multirun allows starting multiple game instances at once.

The main purpose of this feature is to speed up multiplayer game development. One game instance can be configured to host the game and others to join.

## How to use

1. Add the plugin to your project and enable it.
2. Configure the plugin in Project Settings. The settings are located under *Debug → Multirun*.
3. Run the script by clicking the multirun button on the top right corner of Godot editor, or press F4 on keyboard.

Extra: next to the multirun button there is also a new folder button that opens the `"user://"` path when clicked.

![Screenshot](screenshots/MultirunPreview.png)

## Settings

Under the Project Settings there is a new category *Debug → Multirun* with the following parameters:
* **Window Distance** - distance in pixels between different windows. It offsets the windows so that they don't appear on top of each other.
* **Number of Windows** - the total number of windows it opens.
* **Add Custom Args** - when checked, it will add the user defined command line arguments to the opened game instances.
* **First Window Args** - custom command line arguments that will be applied to the first window. To add multiple arguments, separate them with a space.
* **Other Window Args** - custom command line arguments that will be applied to all other windows. To add multiple arguments, separate them with a space.

![Screenshot](screenshots/MultirunSettings.png)

## Additional Information

Finding problems in the code, open a ticket on [GitHub](https://github.com/perfoon/Multirun/issues).

