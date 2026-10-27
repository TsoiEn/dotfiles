# Plan

## git clone separation helper script

### problem to solve

Currently I have a two accounts (work and personal). There are two distinct directory in my ~/Development/ directory which are (Work & Perosnal).
based on my config this is how i could clone repository from two accounts

```bash
# Work GitHub
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    AddKeysToAgent yes
    UseKeychain yes
    IdentitiesOnly yes

# Personal GitHub
Host github-personal
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_personal
    AddKeysToAgent yes
    UseKeychain yes
    IdentitiesOnly yes
```

- feature
  - I want the script to detect in what directory I'm in.
    - exmaple: im in the Personal/ directory so it will change the naming of this repo git@github.com:TsoiEn/GoTask.git -> git@github-personal:TsoiEn/GoTask.git
    - If im in work it will stay at ease
  - I need just {prompt shortcut} git@github.com:TsoiEn/GoTask.git and it automatically process the changes
  - another thing is, if the repo is for personal, in .git/config in should add the part of this
  ```bash
  [user]
  name = TsoiEn
  email = paulanrenz23@gmail.com

  ```
