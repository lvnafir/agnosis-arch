# Git SSH Setup Guide for Noesis Arch

**Purpose**: Step-by-step guide to set up Git with SSH authentication after system reinstall
**System**: Arch Linux on ThinkPad T15g Gen 1

## Prerequisites

Ensure these packages are installed:
```bash
sudo pacman -S git openssh
```

## Step 1: Configure Git User Information

Set your Git identity:
```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

Verify configuration:
```bash
git config --global --list
```

## Step 2: Generate SSH Key

Create new SSH key (or restore from backup):
```bash
ssh-keygen -t ed25519 -C "your.email@example.com"
```

- Press Enter to accept default file location (`~/.ssh/id_ed25519`)
- Set passphrase (optional but recommended)

## Step 3: Start SSH Agent and Add Key

Start SSH agent:
```bash
eval "$(ssh-agent -s)"
```

Add SSH key to agent:
```bash
ssh-add ~/.ssh/id_ed25519
```

## Step 4: Add Public Key to GitHub

Display your public key:
```bash
cat ~/.ssh/id_ed25519.pub
```

Copy the entire output and add it to GitHub:
1. Go to GitHub Settings > SSH and GPG keys
2. Click "New SSH key"
3. Paste your public key
4. Give it a descriptive title
5. Click "Add SSH key"

## Step 5: Add GitHub to Known Hosts

Add GitHub's host key to avoid verification prompts:
```bash
ssh-keyscan -H github.com >> ~/.ssh/known_hosts
```

## Step 6: Test SSH Connection

Test connection to GitHub:
```bash
ssh -T git@github.com
```

Expected response:
```
Hi username! You've successfully authenticated, but GitHub does not provide shell access.
```

## Step 7: Configure Repository Remote

Navigate to your repository:
```bash
cd ~/build/noesis-arch
```

Check current remote URL:
```bash
git remote -v
```

If using HTTPS, change to SSH:
```bash
git remote set-url origin git@github.com:lvnafir/noesis-arch.git
```

## Step 8: Test Push Access

Verify you can push to the repository:
```bash
git status
git push
```

## Troubleshooting

### SSH Agent Connection Issues
If you get "Could not open a connection to your authentication agent":
```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

### Host Key Verification Failed
If you get "Host key verification failed":
```bash
ssh-keyscan -H github.com >> ~/.ssh/known_hosts
```

### Permission Denied (publickey)
1. Verify your SSH key is added to GitHub
2. Check SSH agent has your key loaded:
   ```bash
   ssh-add -l
   ```
3. Test SSH connection:
   ```bash
   ssh -T git@github.com
   ```

### Wrong Remote URL
If still getting authentication errors, ensure remote uses SSH:
```bash
git remote set-url origin git@github.com:lvnafir/noesis-arch.git
```

## Key File Backup and Restore

### Backing Up SSH Keys
Copy your SSH directory to secure storage:
```bash
cp -r ~/.ssh /path/to/backup/location/
```

### Restoring SSH Keys
Copy SSH keys back from backup:
```bash
cp -r /path/to/backup/ssh_backup ~/.ssh
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

## Quick Setup Commands Summary

For fast setup after system reinstall:
```bash
# 1. Install packages
sudo pacman -S git openssh

# 2. Configure Git
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# 3. Restore SSH keys (if from backup)
cp -r /backup/ssh_backup ~/.ssh
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub

# 4. Start SSH agent and add key
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# 5. Add GitHub to known hosts
ssh-keyscan -H github.com >> ~/.ssh/known_hosts

# 6. Test connection
ssh -T git@github.com

# 7. Configure repository
cd ~/build/noesis-arch
git remote set-url origin git@github.com:lvnafir/noesis-arch.git

# 8. Test push
git push
```

## Notes

- SSH keys should be backed up securely (encrypted storage recommended)
- Each new system/reinstall may require adding the public key to GitHub again
- Keep your private key (`id_ed25519`) secure and never share it
- The public key (`id_ed25519.pub`) can be safely shared
- SSH agent needs to be started in each new terminal session (unless configured in shell profile)