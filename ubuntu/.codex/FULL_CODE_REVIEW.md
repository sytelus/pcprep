# Code Review Guidelines

Throughly understand all of the code, understand goal of the project and design of the code. After you develop full understanding, perform a through code review. The goal of the code review is as follows:

1. Make sure the goals set in PROJECT.md are met.
2. Make sure the guidelines mentioned in AGENTs.md are followed.
3. Find any bugs or mistakes in the code and fix them. Add unit tests for these changes to protect again future re-introduction of these issues.
4. Fix any type hinting and linting issues.
5. Eliminate any redundencies and duplications that should not be present in a good code.
6. Simplify any unneccesory complexities. Make sure code is clean, tidy and easy to follow.
7. Make sure any missing documentation is added if it is not redundent.
8. Make sure unit tests and end-to-end test coverage is solid and all critical parts of code is covered.

After making above changes, re-run all unit tests and end-to-end test to make sure code remains fully functional and error free