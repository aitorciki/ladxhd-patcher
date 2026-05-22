# ladxhd-patcher

An experimental alternative patching mechanism for [BigheadSMZ/Zelda-LA-DX-HD-Updated](https://github.com/BigheadSMZ/Zelda-LA-DX-HD-Updated).

## What is this?

Link's Awakening DX HD Updated is a modern re-implementation of the classic GameBoy Color game for modern platforms. That repository avoids including or distributing any copyrighted content, and opts for a patching strategy instead: users need to bring their own copy of the original release of the re-implementation, and run a patcher application on it to generate the updated version.

As new features and platforms have been added to the patcher, it has hugely grown in size (~500MB) since it bundles patches for all platforms, and complexity:

- Per-platform permissions issues, e.g. macOS's quarantines.
- Missing dependencies that can confuse users, e.g. Java / 7z / apksigner to generate APKs on Linux / macOS.
- All sorts of weird interactions of the patcher and different system setups, e.g. Linux file explorers and extensions.

This repo is an experiment to drastically reduce the size of the patches and remove as much of that complexity as possible. The idea is to distribute a single xdelta3 patch file that users apply to their copy of the original archive with their xdelta3 app of preference. 0 special logic to run on the user's host, and a much smaller download size as per-platform patches are provided.

## Requirements

- A patching application that can apply xdelta3 patches. For example:
  - [DeltaPatcher](https://github.com/marco-calautti/DeltaPatcher) for Windows or Linux (make sure to toggle the backup original option to keep your v1.0.0 file intact!)
  - [MultiPatch](https://projects.sappharad.com/multipatch/) for macOS.
  - [XDeltaTool](https://play.google.com/store/apps/details?id=com.bookerdev.xdeltatool) for Android (yes, these patches allow creating an installable APK directly on Android).
  - The xdelta3 command-line tool [on](https://github.com/jmacd/xdelta-gpl/releases/tag/v3.1.0) [any](https://packages.ubuntu.com/resolute/xdelta3) [platform](https://formulae.brew.sh/formula/xdelta).
- A copy of the v1.0.0 distribution of the game. The provided patches only work with the zip file with sha256 checksum `118a4adfa782b4c0097867609cb79474abaf9a95b3f684b04715a46d424beb1c`.

You are ready, download the patch from the releases page, apply to the v1.0.0 zip, and decompress the resulting zip to play the game.

## FAQ

- **How do I update an already patched game?**  
Re-apply the patch to your v1.0.0 zip, and decompress / copy the resulting file on top of your existing game accepting override of all files.

- **Are these patches compatible with [mods](https://github.com/BigheadSMZ/Zelda-LA-DX-HD-Mods)?**  
Partially. LAHDpaks require a copy of unmodified v1.0.0 assets stored in `Data/Backup` to patch, but games patched with this repository's deltas lack these backup files. There is a manual workaround though:
  - Extract v1.0.0.
  - Copy all `Data` and `Content` files into a flattened `Data/Backup`:  

  ```bash
  mkdir /path/to/patched/Data/Backup && find /path/to/v1.0.0/{Content,Data} -type f -exec cp {} /path/to/patched/Data/Backup/ \;
  ```

  This won't work with Android and Linux AppImages though.
