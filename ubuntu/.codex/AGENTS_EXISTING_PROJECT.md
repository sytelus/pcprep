# Repository Guidelines

## Project Structure & Module Organization

Study the exisitng project structure and adhere to its style and organization. Do not re-organize or re-format exissting code unless explicitly asked to do so. Try to make minimal changes needed to require to complete the task.

The project root may contain TODO.md that has all the remaining TODOs for the project.

The project root may contain CHANGELOG.md that is akin to release notes summarizing major improvements or bug fixes with dates. The idea of this file is not to list every single change (that can be viewed in commit log) but rather the most interesting high level changes added.

Assume vscode will be used to edit and debug the code in this project.

## Coding Style & Naming Conventions

Do not make any stylistic or formatting changes. Study this code base to ensure you fully understand author's style and adhere to that style. For any new code do use full type annotations.

In general, your goal is to keep things simple and concise. When updating code, try to make minimal number of changes that an expert developer would do. Your code should be nice and clean and frictionless to read and follow. Future maintainers should appreciate the quality of code, its clarity and ease of working with it and updating it. Avoid extra dependencies when possible but do include them when the dependency does make significant difference in code complexity, code length, robustness and featureset that will actually be useful to the end user.

## Documentation Guidelines

All new code should be well documented but avoid the documentation that is too verbose or the documentation that just states the obvious. For example, variable names, arguments, type hints and function names may often clearly convey the purpose and additional documentation may not be neccesory. However, manytimes it may not be clear what values arguments may take or what is function returning or why some critical portion of the code is written in certain way (for example, for better performance) or why certain function exists etc. In those cases, make sure documentation exist. Your job is to reduce surprises to user who may not be familier with this code but is a professional developer. Do prefer concise documentation or inline comments when possible. When adding documentation, always think from a future maintainer perspective and add documentation that will help the future maintainer understand the purpose, approach, any complex details, any hacks, performance sensetive parts, any tricks etc. You should ensure that the future maintainer would be able to maintain code without having to ask someone. Sometimes, to keep code concide and number of lines in a given file small, you may decide to add extra documentation files under `docs` directory and link to them in your comments in code. Always make sure all the code documentation, files in docs directory, README etc are upto date when you are making any changes to the code.

## Commit & Pull Request Guidelines

Follow Conventional Commits (e.g., `feat: add routing agent`, `fix: guard auth token refresh`). Keep commits focused and include motivation in the body when the diff is not obvious. It is good to have PR outline scope, link tracking issues, list executed commands, attach screenshots, logs for behavioral changes etc as applicable (however, these are strickly not neccesory).

## Security & Configuration Tips

Never commit secrets; store runtime credentials in `.env.local` and update `.gitignore` when new keys appear. Document every environment variable in `docs/configuration.md` with defaults and rotation notes. Rotate tokens shared with automation promptly and record expirations in the PR. Editor adjustments live in `.vscode/`; propose changes through review before committing.
