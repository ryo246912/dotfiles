# Socket Firewall (sfw)

Socket Firewall is a lightweight tool that protects developer machines in real time by blocking malicious dependencies before they reach your laptop or build system.

## Key Features

- **Real-time Protection:** Blocks malicious dependencies during installation.
- **Multi-ecosystem Support:** Supports JavaScript (npm), Python (pip), and Rust (cargo).
- **Ephemeral HTTP Proxy:** Intercepts traffic and checks with the Socket API for safety.
- **No Configuration Required:** Works out of the box without an API key for the Free version.

## Installation

Socket Firewall is managed via `mise` in this repository.

```sh
mise install
```

## Usage

Prefix your package manager's installation commands with `sfw`.

### Examples

- **npm:**
  ```sh
  sfw npm install <package-name>
  ```
- **pip:**
  ```sh
  sfw pip install <package-name>
  ```
- **cargo:**
  ```sh
  sfw cargo install <package-name>
  ```

### Verification

You can test it by trying to install a known malicious package (e.g., `lodahs` instead of `lodash`):

```sh
sfw npm install lodahs
```

The installation should fail as Socket Firewall blocks the request.

## Cache Note

Socket Firewall works by blocking network requests for package artifacts. It is recommended to clear your package manager's cache before first use:

```sh
npm cache clean --force
```

## Zsh Abbreviations (zabrze)

This repository includes several `zabrze` snippets for easier use:

- `sni`: `sfw npm install`
- `snil`: `sfw npm install lodahs` (for testing)
- `spi`: `sfw pip install`
- `sci`: `sfw cargo install`
