# rmvscode

Sample code and application to demonstrate some of the many wonderful features
of VS Code and the IBM i extensions.

This code [is going to used/was used] during the i-UG i-Power Conference 2025
session and presentation titled **VS Code + IBM i: Tips, Tricks and Real Talk**.



# Prerequisites

Install the following.
* VS Code
  * [Code for IBM i: Installation](https://codefori.github.io/docs/install/)
  * I suggest installing the IBM i Development Pack extension, this will give
  you everything you need including the RPGLE tools and Project Explorer
  extensions
  * If you want to use the debugger then check the [Required PTFs](https://codefori.github.io/docs/developing/debug/#required-ptfs)
* Better Object Builder (BOB)
  * [Better Object Builder for IBM i: Installation](https://ibm.github.io/ibmi-bob/#/getting-started/installation)



**TALK ABOUT GIT CLONE???**


# Building the Application

1. Open the **Project Explorer** view.
    * Connect to your IBM i server
    * Set the IFS deploy location e.g. `/home/richardm/builds/rmvscode`
    * Set the desired deployment method. Defaults to `compare`, which is my preferred setting.
    * Set the `CURLIB` variable to your target object library e.g. `RMVSCODE`
    * Check the library list this should include your target object library, as the current library

2. Run ... Build from **Project Explorer** view.

3. Open the **IFS Browser** view.
  * Create a new IFS Shortcut pointing to your deploy location e.g. `/home/richardm/builds/rmvscode`
  * Open the new IFS Shortcut
  * Locate the `uk-500.csv` file
  * Right-click and select Run Action
  * Select the Seed CUSDET From CSV action


  ```
  Running Action: Seed CUSDET Table From CSV (11:43:30)
  Current library: QGPL
  Library list: QGPL QTEMP RMVSCODE
  Working directory: /home/RICHARDM
  Commands:
                  QGPL/SEEDCUSDET TRUNCATE(*YES) CSVSTMF('/home/RICHARDM/builds/rmvscode/uk-500.csv')

  CPD0030:  Command SEEDCUSDET in library QGPL not found.
  CPF0001:  Error found on SEEDCUSDET command.


  *  The terminal process terminated with exit code: 1.
  *  Terminal will be reused by tasks, press any key to close it.
  ```


* Run the `Deploy, Copy To Source Files & Compile ⮞🏛` action

Fails - the library list does not include RMVSCODE
