# GitLab + GitHub Multi‑Remote Setup Assistant

This tool automatically configures any project so it can push to **both GitLab and GitHub** at the same time.  
It is designed for *end‑users*, not developers.

Once configured, your workflow stays simple:

```
git add .
git commit -m "message"
git push origin
```

And your changes go to **GitLab** and **GitHub** automatically.

---

# 📌 What This Tool Does

This assistant configures Git so that:

- You have **a single remote** called `origin`
- `origin` **fetches** from your primary platform (GitLab or GitHub)
- `origin` **pushes** to **both** GitLab and GitHub
- (Optional) Configures your **Git Identity** (`user.email` and `user.name`) locally for the project

It does **not** modify:

- Your code  
- Your branches  
- Your commit history  
- Your existing work  

The tool only adjusts Git remote settings safely.

---

# 📂 Installation

### 1. Create a folder for the tool  
Choose a location where the script will always live, for example:

```
C:\Tools\Git2sync
```

### 2. Copy the script  
Place `Setup-MultiRemoteSync.ps1` inside this folder:

```
C:\Tools\Git2sync
└─ Setup-MultiRemoteSync.ps1
```

### 3. Add the folder to your system PATH  
This allows PowerShell to run the script from anywhere:

```powershell
[Environment]::SetEnvironmentVariable(
    "Path",
    $Env:Path + ";C:\Tools\Git2sync",
    "User"
)
```

Restart PowerShell afterwards.

Now you can use:

```
Setup-MultiRemoteSync.ps1
```

from any directory on your computer.

---

# 📁 Preparing Your Projects Folder

Choose a main folder where you store your coding projects, such as:

```
C:\Dev
```

Each project should live inside this folder, for example:

```
C:\Dev\project-a
C:\Dev\project-b
C:\Dev\my-new-repo
```

Depending on your scenario, the script will either:

- **Create the project folder** (if you pass the parent directory)
- or **Use an existing folder** (if you pass the full path)

---

# 🚀 Usage Scenarios

The assistant supports **three situations**:

---

# 1️⃣ New Project — Starting from GitLab

Use this mode when:

- You created a **new GitLab repository**
- You want to clone it locally
- You want to add a GitHub mirror

### Example

```powershell
Setup-MultiRemoteSync.ps1 `
  -Path "C:\Dev" `
  -GitLabUrl  "https://gitlab.iconsulting.biz/USER/my-new-project.git" `
  -GitHubUrl  "https://github.com/USER/my-new-project.git" `
  -Mode FromGitLab `
  -UserEmail "user@example.com" `
  -UserName "My Name" `
  -SyncNow
```

### Result

- The project folder is created inside `C:\Dev` (e.g., `C:\Dev\my-new-project`)
- Code is cloned from GitLab  
- GitHub becomes a **push-only mirror**  
- Git identity is configured locally
- One push updates both repositories  

---

# 2️⃣ New Project — Starting from GitHub

Use this mode when:

- You created a **new GitHub repository**
- You want a GitLab mirror
- You want automatic dual‑push behavior

### Example

```powershell
Setup-MultiRemoteSync.ps1 `
  -Path "C:\Dev\my-github-project" `
  -GitLabUrl  "https://gitlab.iconsulting.biz/USER/my-github-project.git" `
  -GitHubUrl  "https://github.com/USER/my-github-project.git" `
  -Mode FromGitHub `
  -UserEmail "user@example.com" `
  -UserName "My Name" `
  -SyncNow
```

### Result

- Folder is created (if it doesn't exist)
- Code is cloned from GitHub  
- GitLab is added as a push mirror  
- One push updates both platforms  

---

# 3️⃣ Existing Local Project — Fix or Restore Sync

Use this mode when:

- You already have a project locally  
- You already created GitLab + GitHub repositories  
- Something is misconfigured  
- You want to safely repair the multi‑remote setup  
- You do *not* want to lose any data

### Example

```powershell
Setup-MultiRemoteSync.ps1 `
  -Path "C:\Dev\genai-prompt-collection" `
  -GitLabUrl  "https://gitlab.iconsulting.biz/USER/genai-prompt-collection.git" `
  -GitHubUrl  "https://github.com/USER/GenAI-Prompt-Collection.git" `
  -Mode Existing `
  -Primary GitLab
```

### Result

- No project data is touched  
- No branches are modified  
- Remotes are corrected:
  - Fetch from GitLab  
  - Push to GitLab + GitHub  

Completely safe and reliable.

---

# 📝 Daily Workflow After Setup

Once configured, you work normally:

```
git add .
git commit -m "message"
git push origin
```

This updates **both**:

- GitLab (primary)  
- GitHub (mirror)  

You only push once.

---

# 🔧 Optional: Automatic Sync

If you want the tool to immediately push all branches and tags after configuration, use:

```
-SyncNow
```

**Note**: If the repository is empty (no commits), `-SyncNow` will be skipped to avoid errors. You must create an initial commit first.

---

# 👤 Optional: Git Identity

You can configure your local git identity for the project during setup:

```
-UserEmail "user@example.com"
-UserName "Your Name"
```

This sets `user.email` and `user.name` in the local `.git/config` file.

---

# 💡 Good Practices

- Keep the automation script in one folder (e.g. `C:\Tools\Git2sync`)
- Keep your projects in another folder (e.g. `C:\Dev`)
- Use:
  - `FromGitLab` for new GitLab projects  
  - `FromGitHub` for new GitHub projects  
  - `Existing` for fixing local projects  
- Use `-Path` flexibly:
  - Pass the **Parent Directory** (e.g. `C:\Dev`) to clone inside it.
  - Pass the **Target Directory** (e.g. `C:\Dev\MyApp`) to clone as that folder.
- Use `-Primary GitLab` if GitLab is your main workspace

---

# 🧪 Quick Reference

| Scenario | Command Mode | Fetch From | Push To |
|---------|--------------|------------|---------|
| New GitLab Project | `FromGitLab` | GitLab | GitLab + GitHub |
| New GitHub Project | `FromGitHub` | GitHub | GitHub + GitLab |
| Existing Local Project | `Existing` | Chosen via `-Primary` | Both |

---

# ❓ Not Sure Which Mode to Use?

- If the project folder **does not exist yet** → use **FromGitLab** or **FromGitHub**  
- If the project folder **already exists** → use **Existing**  
- If GitLab is your main platform → use `-Primary GitLab`

---

This assistant keeps your projects synchronized between GitLab and GitHub with a single push and minimal setup.
