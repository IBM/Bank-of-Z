# Git Commit Guidelines for Bank-of-Z

## Developer Certificate of Origin (DCO)

All commits to this repository MUST include a sign-off to comply with the Developer Certificate of Origin.

### Required: Always use -s flag

**ALWAYS use the `-s` flag when committing:**

```bash
git commit -s -m "Your commit message"
```

This adds the following line to your commit message:
```
Signed-off-by: Your Name <your.email@example.com>
```

### Why Sign-offs are Required

The sign-off certifies that you have the right to submit the code under the project's license and that you agree to the Developer Certificate of Origin (DCO).

### Automated Enforcement

This repository has DCO checks enabled. Pull requests with unsigned commits will be rejected.

### If You Forget

If you've already made commits without sign-offs:

```bash
# For the last commit
git commit --amend -s --no-edit

# For multiple commits (replace N with number of commits)
git rebase HEAD~N --signoff

# Force push (use with caution)
git push --force-with-lease origin your-branch
```

### Bob AI Assistant Note

When using Bob AI assistant for commits, always ensure the execute_command tool uses:
- `git commit -s -m "message"` (NOT `git commit -m "message"`)
- The `-s` flag is MANDATORY for all commits

## Best Practices

1. **Always use `-s`**: Make it a habit
2. **Check before pushing**: Run `git log --show-signature` to verify
3. **Configure git alias**: `git config alias.cs 'commit -s'` then use `git cs -m "message"`
4. **Pre-commit hook**: Consider adding a hook to enforce sign-offs

## References

- [Developer Certificate of Origin](https://developercertificate.org/)
- [Git commit sign-off documentation](https://git-scm.com/docs/git-commit#Documentation/git-commit.txt--s)