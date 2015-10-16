# Introduction
This sections includes the purpose and scope of this SRS and an overview of Atom.
## Purpose
The purpose of this document is to serve as a guide to designers, developers and testers who are responsible for the engineering of Atom.
## Scope
This document contains a small description of the functionality of Atom. It consists of use cases, functional and non-functional requirements.
## System overview
Atom is the "hackable text-editor", it allows users to customize its GUI and add functionalities.
It's a text editor that provides the ability to create, edit and save text files. It also provides efficiency tools such as auto completion and language support.
Atom provides a users the possibility to create new functionalities and their own themes. All of this can be shared with the community.
These features make it a powerful tool to increase user productivity.
# Specific requirements
This section contains the main requirements of the system. It gives a detailed description of the system and the base features.
## System features
### Functional requirements
#### Customize the editor appearance
#### Description
The user must be able to choose and create different color themes. Variety of choice on font styles and sizes.
#### Reason
Give the user the most comfortable graphical interface.
#### Use Case
![Customize](Resources/Customize.png)
#### Create, Open, Save and Close files
##### Description
The user must be able to create, open, save and close files in a specified directory.
#### Reason
Removes the need to leave the editor to create files.
#### Use Case
![Customize](Resources/Files.png)
#### Git integration
##### Description
The editor must display the current status of the git repository and line diffs.
#### Reason
User has on screen information about changes made since last commit.
#### Use Case
![Customize](Resources/GitIntegration.png)
#### Text edition
##### Description
The editor must provide word completion for main programming languages, ability to add, edit and delete text.
#### Reason
Main functionality of the editor.
#### Use Case
![Customize](Resources/Text.png)

# Use Cases
Name   | Use case number and name
-------|-------------------------
Summary|
Rationale|
Users|
Preconditions|
Basic Course of Events|
Alternative Paths|
Postconditions|

Name   | UC1: Search and Replace
-------|-------------------------
Summary|Occurrences of a search term are replaced with replacement text.
Rationale|While editing a document, users may find the need to replace some text in the document. Since manually looking for the text is very inefficient, Search and Replace allows the user to automatically find the text, and replace it. Sometimes there are many occurrences, and the user may choose to replace all of them, or one at a time. The user may also not replace any text, and just find its location.
Users|All users.
Preconditions|A document is loaded and being edited.
Basic Course of Events|1. The user indicates that the software is to perform a search and replace in the active document.</br>2. The software responds by requesting the search term and the replacement text.</br>3. The user inputs the search term and replacement text. Then, indicates that all occurrences are to be replaced.</br>4. The software replaces all occurrences with the replacement text.
Postconditions|All occurrences of the search term have been replaced with the inputted text from the user.
Alternative Paths|1. In step 3, the user may indicate that only the first occurrence is to be replaced. The postcondition state is identical, except there is only one replace.</br>2. In step 3, the user may choose not to replace any text, but only to find it. In this case, the software highlights all occurrences in the active document.</br>3. The user can decide not to find or replace any text. In this case, the software simply returns to the precondition state.

Name   | UC2: Change GUI theme
-------|-------------------------
Summary|GUI appearance changes to a specified theme.
Rationale|The user may enjoy working with different font or background colors, atom provides different color themes for the user interface (tabs, status bar, tree view and dropdowns) and for the text inside the editor.
Users|All users.
Preconditions|Atom is running
Basic Course of Events|1. The user indicates to the software the intention of changing the theme.<br>2. The software responds by showing all the themes available to apply. <br>3. The user inputs the theme he wishes to use.<br>4. The software replaces the current theme with the theme chosen by the user.
Postconditions|Theme is changed to the one selected by the user.
Alternative Paths|1. In step 3, the user may cancel the action and the current theme continues to be active.

Name   | UC3: Add functionality
-------|-------------------------
Summary|A new functionality is added to the editor.
Rationale|The standard version of the software may not have some specific functionality desired by the user, the user can add the desired functionality if it is available to install.
Users|All users.
Preconditions|Atom is running and has Internet access.
Basic Course of Events|1. The user indicates to the software the intention of installing a new feature.<br>2. The software responds by requesting the user the search term that describes the feature. <br>3. The software displays all the features matching the search term. <br> 4. The user selects the feature desired. <br> 5. The software downloads and installs the feature selected.
Postconditions|The feature selected is installed and ready to be used.
Alternative Paths|1. In step 3, the user may input a different search term and the software will display the new corresponding features.<br> 2. In step 2, 3 or 4 the user may choose to cancel the operation.

Name   | UC4: Create functionality
-------|-------------------------
Summary|A user want to use a functionality that does not come with the standard version of the software nor is available for installment. If the user wants to he can create a new functionality.
Users|All users.
Preconditions|None
Basic Course of Events|1. User creates the functionality using services provided by the software.<br> 2. User adds the newly created functionality to the available features to install on the software.
Postconditions|The feature created is available to be added to the software.
Alternative Paths|
