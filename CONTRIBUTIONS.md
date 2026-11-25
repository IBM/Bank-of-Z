# Bank of Z Contribution Guidelines

To contribute code, samples, bug fixes, tests, or documentation to [Bank of Z](https://github.com/IBM/Bank-of-Z), follow these guidelines.

## Contribution Workflow

1. **Get the repository.** If you have direct access, clone the Bank of Z repository:

   ```bash
   git clone https://github.com/IBM/Bank-of-Z.git
   cd Bank-of-Z
   ```

   If you are contributing through a fork, clone your fork instead.

2. **Create a branch.** Create a separate branch from the appropriate base branch. Do not make changes directly on `main`.


   ```bash
   git checkout -b <branch-name>
   ```

3. **Make your changes.** Keep each contribution focused on one sample, feature, bug fix, test update, or documentation change. Follow the existing repository structure and conventions.

4. **Commit and push your changes.** Use a clear commit message, then push your branch:


   ```bash
   git add .
   git commit -m "Describe your changes"
   git push -u origin <branch-name>
   ```

   If DCO sign-off is required, use `git commit -s` and verify that the sign-off appears in your commit.

5. **Create a pull request.** Create a PR against the appropriate Bank of Z branch. Include a clear title and description of your changes. Link a related issue, describe the tests or checks you ran, and add screenshots or other context when useful.

6. **Notify the maintainer.** Send an email to [Mike Fulton](fultonm@ca.ibm.com), the Bank of Z maintainer, with a link to your PR. Include the required DCO confirmation, if applicable.

The contribution will be reviewed by a repository maintainer. Address review feedback and update your PR as needed.

## Keep Contributions Organized

- Follow the existing Bank of Z directory structure when adding or updating files
- Place new samples, application components, and supporting resources in their appropriate directories
- Use consistent file names and follow the conventions used in the repository
- Update the relevant README files when adding or changing samples, components, or setup instructions
- Keep each pull request focused on one contribution. Submit separate PRs for unrelated changes
- Remove temporary files, generated files, and unused resources before submitting your PR

## Documentation Contributions

For documentation updates, follow the existing structure and writing style. Update navigation when adding, removing, or moving topics. Check links, images, code examples, and rendered pages before submitting your PR.

## Need Help?

For contribution questions, contact Mike Fulton or raise an issue in the [Bank of Z GitHub repository](https://github.com/IBM/Bank-of-Z).


