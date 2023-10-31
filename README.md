### Dotfile

A file that is not visible by default to normal
directory-browsing tools (on Unix, files named with a leading dot are,
by convention, not normally presented in directory listings).
Many programs define one or more dot files in which startup or configuration
information may be optionally recorded; a user can customize the program's
behavior by creating the appropriate file in the current or home directory.

Dot files tend to proliferate - with every nontrivial application program defining
at least one, a user's home directory can be filled with scores of dot files,
without the user really being aware of it.
Common examples are .profile, .cshrc, .login, .emacs, .mailrc, .forward, .newsrc, .plan, .rhosts, .sig, .xsession.

While you are working on a PC or laptop, no problems with these files no.
You can add or correct something in them and continue to work on.

But the system can fail and then your files or settings will be lost
at work you will be given a separate computer, which is not yet configured environment.
Then you have time and time again to add or correct configuration files.
At some point you will want to have configuration files that were identical (synchronized)
on your computer and not have to do one thing each time, etc.

Here comes to help github.com where we can store our dotfiles.
And access them from any computer.

This solves the problem of storing our files, but only partially solves
the problem of synchronization.

Every time save your changes and send them to a remote server, and then do not forget to other computers to update their tedious.
In order to solve this problem for myself and I wrote the dotfile script.
That should solve the problem with the synchronization and organization of system files.
Load and run.


### Installation

```
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash \
&& export NVM_DIR="$HOME/.nvm" \
&& [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
&& nvm install stable
```

```bash
npx github:maksimr/udot use https://github.com/maksimr/dotfiles
```

```bash
npx github:maksimr/udot upgrade --module-path=~/.local/bin/udot
```
