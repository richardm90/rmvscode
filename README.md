# rmvscode

Sample code and application to demonstrate some of the many wonderful features
of VS Code and the IBM i extensions.
This repository was created as an accompanying example code for the i-UG
i-Power Conference 2025 session and presentation titled
**VS Code + IBM i: Tips, Tricks and Real Talk**.


# Credits

1. The code inside the `csvutil` directory is copyright of Scott Klement from his excellent [CSV Utility](https://www.scottklement.com/csv/).
1. I utilise the excellent A Modern RPG Application methodology within the example application. This methodology was developed by Paul Tuohy.



# Prerequisites

* On your IBM i server
  * Bash
  * Better Object Builder (BOB)
    * [Better Object Builder for IBM i: Installation](https://ibm.github.io/ibmi-bob/#/getting-started/installation)

* On you local machine (your PC)
  * VS Code
  * [Code for IBM i: Installation](https://codefori.github.io/docs/install/)
  * I suggest installing the IBM i Development Pack extension, this will give
  you everything you need including the RPGLE tools and Project Explorer
  extensions
  * If you want to use the debugger then check the [Required PTFs](https://codefori.github.io/docs/developing/debug/#required-ptfs)
  * Clone this repository to your local machine



# Building the Application

1. Open the respository in VS Code

1. Open the **Project Explorer** view.
    * Connect to your IBM i server
    * Set the IFS deploy location e.g. `/home/richardm/builds/rmvscode`
    * Set the desired deployment method. Defaults to `compare`, which is my preferred setting.
    * Set the `CURLIB` variable to your target object library e.g. `RMVSCODE`
    * Ensure the target object library exists
        * e.g. `CRTLIB RMVSCODE`
    * Click the Refresh icon on the the **Project Explorer** view.
    * Check the library list this should include your target object library, as the current library

2. Right click on the `rmvscode` project in the **Project Explorer** view.
    * Run > Run Build

### PUB400.COM

This method of building the application works fine on the PUB400.COM server
but rather than using `RMVSCODE` as the target object library use your own
PUB400.COM assigned library instead.



# Running the Application

Signon to your IBM i server using a 5250 emulator.

```shell
# Add the target object library to the library list
ADDLIBLE RMVSCODE

# Seed the database, you only need to do this once
# - tweak the IFS path accordingly
SEEDCUSDET CSVSTMF('/home/RICHARD/builds/rmvscode/uk-500.csv')

# If you're deploying to PUB400.COM then change the DECFMT job value,
# the default will show commas rather than a decimal point
CALL SETJOB

# Run the application
CALL WRKCUS
```



# Deploy, Copy To Source Files & Compile

There is a local action that will perform the following steps.

1. Deploy the local source files to your chosen IBM i (IFS) deploy location,
this is using the standard Code for IBM i deploy action.

1. Create source files in the target object library. If they already exist
then that is fine, they won't be deleted and any source members you already
have in these source files won't be affected unless they have the same names
as those in the local project.

1. Copy the source files that were deployed to your IFS deploy location to
the source files in the target object library and compile from the member
source.
    * As part of the copy process the `/include` statements will be updated
    accordingly to reflect member source rather than local source.
    * Message files and binding directories are also created in this step.

If you're interested then the local action is running a Bash script to perform
the copy source and compile, have a look in the `scripts/` directory at the
custom `copy_to_soruce_files.sh` script.


To run the local action:

1. Open the respository in VS Code

1. Open the **Project Explorer** view.
    * Connect to your IBM i server

1. Right click on the `rmvscode` project in the **Project Explorer** view.
    * Run > Run Action
    * Select the `Deploy, Copy To Source Files & Compile ⮞🏛` action
