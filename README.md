## Introduction

### What is BinCAT?

BinCAT is a *static* Binary Code Analysis Toolkit, designed to help reverse
engineers, directly from IDA.

It features:

* value analysis (registers and memory)
* taint analysis
* type reconstruction and propagation
* backward and forward analysis

### In action

You can check (an older version of) BinCAT in action here:

* [Basic analysis](https://syscall.eu/bincat/main.mp4)
* [Using data tainting](https://syscall.eu/bincat/taint.mp4)

Check the [tutorial](doc/tutorial.md) out to see the corresponding tasks.

### Quick FAQ

Supported host platforms:

* IDA plugin: all, version **6.9 or later** (BinCAT uses PyQt, not PySide)
* analyzer (local or remote): Linux, Windows, macOS (maybe)

Supported CPU for analysis (for now):
* x86-32
* ARMv7
* ARMv8

## Installation

### Analyzer
The analyzer can be used locally or through a Web service.

On Windows, the [binary distribution](https://github.com/airbus-seclab/bincat/releases) includes the analyzer.

On Linux:
* Using Docker: [Docker installation instructions](doc/install_docker.md)
* Manual: [Manual installation instructions](doc/install_manual.md)

### IDA Plugin

**Only IDA v6.9 or later (7 included) are supported**

#### Install for Windows

* Unzip BinCAT
* In IDA, click on "File -> Script File..." menu (or type ALT-F7)
* Select `install_plugin.py`
* BinCAT is now installed in your IDA user dir
* Restart IDA

Or [install manually](doc/plugin_manual_win.md).


#### Linux install

[Installation instructions](doc/install_plugin.md)

BinCAT should work with IDA on Wine, once pip is installed:

* download <https://bootstrap.pypa.io/get-pip.py> (verify it's good ;)
* `~/.wine/drive_c/Python27/python.exe get-pip.py`

## Using BinCAT

### Quick start
* Load the plugin by using the `Ctrl-Shift-B` shortcut, or using the
  `Edit -> Plugins -> BinCAT` menu

* Go to the instruction where you want to start the analysis
* Select the `BinCAT Configuration` pane, click `<-- Current` to define the start address
* Launch the analysis

### Configuration
Global options can be configured through the `Edit/BinCAT/Options` menu.

Default config and options are stored in `$IDAUSR/idabincat/conf`.

#### Options

* "Use remote bincat": select if you are running docker in a Docker container
* "Remote URL": http://localhost:5000 (or the URL of a remote BinCAT server)
* "Autostart": autoload BinCAT at IDA startup
* "Save to IDB": default state for the `save to idb` checkbox


## Documentation
A [manual](doc/manual.md) is provided and check [here](doc/ini_format.md) for a
description of the configuration file format.


A [tutorial](doc/tutorial.md) is provided to help you try BinCAT's features. 


## Article and presentations about BinCAT

* [SSTIC 2017](https://www.sstic.org/2017/presentation/bincat_purrfecting_binary_static_analysis/), Rennes, France: [article](https://www.sstic.org/media/SSTIC2017/SSTIC-actes/bincat_purrfecting_binary_static_analysis/SSTIC2017-Article-bincat_purrfecting_binary_static_analysis-biondi_rigo_zennou_mehrenberger.pdf) (english), [slides](https://www.sstic.org/media/SSTIC2017/SSTIC-actes/bincat_purrfecting_binary_static_analysis/SSTIC2017-Slides-bincat_purrfecting_binary_static_analysis-biondi_rigo_zennou_mehrenberger.pdf) (french), [video of the presentation](https://static.sstic.org/videos2017/SSTIC_2017-06-07_P07.mp4) (french)
* [REcon 2017](https://recon.cx/2017/montreal/talks/bincat.html), Montreal, Canada: [slides](https://syscall.eu/bincat/bincat-recon.pdf), [video](https://recon.cx/media-archive/2017/mtl/recon2017-mtl-05-philippe-biondi-xavier-mehrenberger-raphael-rigo-sarah-zennou-BinCAT-purrfecting-binary-static-analysis.mp4)

## Licenses

BinCAT is released under the [GNU Affero General Public
Licence](https://www.gnu.org/licenses/agpl.html).

The BinCAT OCaml code includes code from the original Ocaml runtime, released
under the [LGPLv2](https://www.gnu.org/licenses/lgpl-2.0.txt).

The BinCAT IDA plugin includes code from
[python-pyqt5-hexview](https://github.com/williballenthin/python-pyqt5-hexview)
by Willi Ballenthin, released under the Apache License 2.0.

