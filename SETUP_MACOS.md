# macOS arm64 setup

The ordinary installation command is sufficient when compatible R package
binaries are available:

```sh
Rscript -e 'renv::restore(prompt = FALSE)'
```

The verified environment used macOS arm64, R 4.5.1, Pandoc 3.6.3, GNU Fortran
14.2, GNU gettext 0.22.5, Helvetica, and Cairo-capable graphics. The R package
versions are recorded in `renv.lock`; compilers, system libraries, Pandoc, and
fonts are outside `renv`.

## If restoration requires source compilation

1. Install R 4.5.1 for arm64 and the matching GNU Fortran 14.2 toolchain from
   the official [R for macOS tools page](https://mac.r-project.org/tools/).
2. Install the Xcode Command Line Tools:

   ```sh
   xcode-select --install
   ```

3. Install GNU gettext development headers and libraries. The verified host
   used the official R for macOS gettext 0.22.5 bundle; an equivalent arm64
   installation may also work.
4. Start a new terminal, return to this repository root, and run the ordinary
   restoration command again.

Useful checks are:

```sh
R --version
pandoc --version
xcrun --sdk macosx --show-sdk-path
gfortran --version
```

Do not update individual R packages after restoration: the analysis should use
the versions in `renv.lock`. If a build still fails, preserve the complete
error output; the first missing compiler, header, or library named there is
usually the actionable system dependency.

## Verification boundary

The full workflow has been verified on macOS arm64. Other operating systems may
require equivalent compiler and gettext development packages, and font
substitution may cause small visual differences even when numerical outputs
match. The analyses do not depend on a user-specific path.
